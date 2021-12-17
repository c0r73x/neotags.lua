api = vim.api

class Neotags
    new: (opts) =>
        @opts = {
            ft_conv: {
                ['c++']: 'cpp',
                ['c#']: 'cs',
            },
            hl: {
                patternlength: 2048,
                prefix: [[\C\<]],
                suffix: [[\>]],
            },
            notin: {
                '.*String.*',
                '.*Comment.*',
                'cIncluded',
                'cCppOut2',
                'cCppInElse2',
                'cCppOutIf2',
                'pythonDocTest',
                'pythonDocTest2',
            }
        }
        @languages = {}

    setup: (opts) =>
        @opts\extend(opts) if opts
        @run()

    run: () =>
        co = coroutine.create(() -> @highlight())

        while true do
            _, cmd = coroutine.resume(co)
            print cmd
            vim.cmd(cmd) if cmd
            break if coroutine.status(co) == 'dead'

    language: (lang, opts) =>
        @languages[lang] = opts

    contains: (tags, el) =>
        for _, value in pairs(tags)
            return true if value == el
        return false

    makesyntax: (lang, kind, group, opts, content) =>
        hl = "_Neotags_#{lang}_#{kind}_#{opts.group}"
        coroutine.yield("silent! syntax clear #{hl}")

        notin = {}
        matches = {}
        keywords = {}

        prefix = opts.prefix or @opts.hl.prefix
        suffix = opts.suffix or @opts.hl.suffix

        for tag in *group
            continue if tag.name\match('^__anon.*$')
            continue if not content\find(tag.name)

            if (prefix == @opts.hl.prefix and suffix == @opts.hl.suffix and
                    opts.allow_keyword != false and not tag.name\match('%.'))
                table.insert(keywords, tag.name) if not @contains(keywords, tag.name)
            else
                table.insert(matches, tag.name) if not @contains(matches, tag.name)

        table.sort(matches, (a, b) -> a < b)
        for i = 1, #matches, @opts.hl.patternlength
            current = {unpack(matches, i, i + @opts.hl.patternlength)}
            notin = table.concat(@opts.notin, ',')
            str = table.concat(current, '\\|')
            coroutine.yield("syntax match #{hl} /#{prefix}\\%(#{str}\\)#{suffix}/ containedin=ALLBUT,#{notin} display")

        for i = 1, #keywords, @opts.hl.patternlength
            current = {unpack(keywords, i, i + @opts.hl.patternlength)}
            str = table.concat(current, ' ')
            coroutine.yield("syntax keyword #{hl} #{str}")

        coroutine.yield("hi def link #{hl} #{opts.group}")

        -- coroutine.yeild(cmds)
        -- vim.cmd(cmd) for cmd in *cmds

    highlight: () =>
        bufnr = api.nvim_get_current_buf()
        content = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')

        tags = vim.fn.taglist('.*')
        groups = {}

        for tag in *tags
            print tags
            tag.language = tag.language\lower()
            tag.language = @opts.ft_conv[tag.language] if @opts.ft_conv[tag.language]

            groups[tag.language] = {} if not groups[tag.language]
            groups[tag.language][tag.kind] = {} if not groups[tag.language][tag.kind]
            table.insert(groups[tag.language][tag.kind], tag)

        for lang, kinds in pairs(groups)
            continue if not @languages[lang] or not @languages[lang].order
            cl = @languages[lang]
            order = string.reverse(cl.order)

            for i = 1, #order
                kind = order\sub(i, i)

                continue if not kinds[kind]
                continue if not cl.kinds or not cl.kinds[kind]

                @makesyntax(lang, kind, kinds[kind], cl.kinds[kind], content)

neotags = Neotags!

return {
    setup: (opts) ->
        path = debug.getinfo(1).source\match('@?(.*/)')
        for filename in io.popen("ls #{path}/neotags/")\lines()
            lang = filename\gsub('%.lua$', '')
            neotags\language(lang, require"neotags/#{lang}")

        neotags\setup(opts)

        vim.cmd[[
            augroup NeotagsLua
            autocmd!
            autocmd BufReadPre * lua require'neotags'.highlight()
            autocmd BufEnter * lua require'neotags'.highlight()
            augroup END
        ]]

    highlight: () -> neotags\run()
    highlight_x: () -> neotags\highlight()
    language: (lang, opts) -> neotags\language(lang, opts)
}
