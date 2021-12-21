api = vim.api
loop = vim.loop

Utils = require'neotags/utils'

class Neotags
    new: (opts) =>
        @opts = {
            enable: true,
            ft_conv: {
                ['c++']: 'cpp',
                ['moonscript']: 'moon',
                ['c#']: 'cs',
            },
            ft_map: {
                cpp: { 'cpp', 'c' },
            },
            hl: {
                patternlength: 2048,
                prefix: [[\C\<]],
                suffix: [[\>]],
            },
            tools: {
                find: nil,
                regex: nil,
            },
            ctags: {
                run: true,
                directory: vim.fn.expand('~/.vim_tags'),
                silent: true,
                binary: 'ctags'
                args: {
                    '--fields=+l',
                    '--c-kinds=+p',
                    '--c++-kinds=+p',
                    '--sort=no',
                    '-a',
                },
            },
            ignore: {
                'cfg',
                'conf',
                'help',
                'mail',
                'markdown',
                'nerdtree',
                'nofile',
                'readdir',
                'qf',
                'text'
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
        @syntax_groups = {}
        @ctags_handle = nil
        @find_handle = nil

    setup: (opts) =>
        @opts = vim.tbl_deep_extend('force', @opts, opts) if opts
        return if not @opts.enable

        vim.cmd[[
            augroup NeotagsLua
            autocmd!
            autocmd Syntax * lua require'neotags'.highlight()
            autocmd BufWritePost * lua require'neotags'.update()
            autocmd User NeotagsCtagsComplete lua require'neotags'.highlight()
            augroup END
        ]]

        @run('highlight')

    currentTagfile: () =>
        path = vim.fn.getcwd()
        path = path\gsub('[%.%/]', '__')
        return "#{@opts.ctags.directory}/#{path}.tags"

    runCtags: (files) =>
        tagfile = @currentTagfile()
        args = @opts.ctags.args
        args = Utils.concat(args, { '-f', tagfile })
        args = Utils.concat(args, files)

        return if @ctags_handle

        stderr = loop.new_pipe(false) if not @opts.ctags.silent
        stdout = loop.new_pipe(false)

        @ctags_handle = loop.spawn(
            @opts.ctags.binary, {
                args: args,
                cwd: vim.fn.getcwd(),
                stdio: {nil, stdout, stderr},
            },
            vim.schedule_wrap(() ->
                stdout\read_stop()
                stdout\close()

                if not @opts.ctags.silent
                    stderr\read_stop() 
                    stderr\close()

                @ctags_handle\close()
                vim.bo.tags = tagfile
                vim.cmd("doautocmd User NeotagsCtagsComplete")
                @ctags_handle = nil
            )
        )

        loop.read_start(stdout, (err, data) -> print(data) if data)
        if not @opts.ctags.silent
            loop.read_start(stderr, (err, data) -> print(data) if data)

    update: () =>
        return if not @opts.enable
        @findFiles((files) -> @runCtags(files))

    findFiles: (callback) =>
        path = vim.fn.getcwd()

        return callback({ '-R', path }) if not @opts.tools.find
        return if @find_handle

        stdout = loop.new_pipe(false)
        stderr = loop.new_pipe(false)
        files = {}
        args = Utils.concat(@opts.tools.find.args, { path })

        @find_handle = loop.spawn(
            @opts.tools.find.binary, {
                args: args,
                cwd: path,
                stdio: {nil, stdout, stderr},
            },
            vim.schedule_wrap(() ->
                stdout\read_stop()
                stdout\close()
                stderr\read_stop()
                stderr\close()
                @find_handle\close()
                @find_handle = nil

                callback(files)
            )
        )

        loop.read_start(stdout, (err, data) ->
            return unless data
            
            for _, file in ipairs(Utils.explode('\n', data))
                table.insert(files, file)
        )
        loop.read_start(stderr, (err, data) -> print data if data)

    run: (func) =>
        co = nil

        switch func
            when 'highlight'
                tagfile = @currentTagfile()

                if vim.fn.filereadable(tagfile) == 0
                    @update() 
                elseif vim.bo.tags != tagfile
                    vim.bo.tags = tagfile

                co = coroutine.create(() -> @highlight())
            when 'clear'
                co = coroutine.create(() -> @clearsyntax())

        return if not co

        while true do
            _, cmd = coroutine.resume(co)
            vim.cmd(cmd) if cmd
            break if coroutine.status(co) == 'dead'

    toggle: () =>
        @opts.enable = not @opts.enable

        @setup() if @opts.enable
        @run('clear') if not @opts.enable

    language: (lang, opts) =>
        @languages[lang] = opts

    clearsyntax: () =>
        vim.cmd[[
            augroup NeotagsLua
            autocmd!
            augroup END
        ]]

        for _, hl in pairs(@syntax_groups)
            coroutine.yield("silent! syntax clear #{hl}")

        @syntax_groups = {}

    makesyntax: (lang, kind, group, opts, content) =>
        hl = "_Neotags_#{lang}_#{kind}_#{opts.group}"

        notin = {}
        matches = {}
        keywords = {}

        prefix = opts.prefix or @opts.hl.prefix
        suffix = opts.suffix or @opts.hl.suffix

        added = {}

        for tag in *group
            continue if tag.name\match('^__anon.*$')
            continue if Utils.contains(added, tag.name)

            if not content\find(tag.name)
                table.insert(added, tag.name)
                continue

            if (prefix == @opts.hl.prefix and suffix == @opts.hl.suffix and
                    opts.allow_keyword != false and not tag.name\match('%.') and
                    not tag.name == contains and not opt.notin)
                table.insert(keywords, tag.name) if not Utils.contains(keywords, tag.name)
            else
                table.insert(matches, tag.name) if not Utils.contains(matches, tag.name)

            table.insert(added, tag.name)

        coroutine.yield("silent! syntax clear #{hl}")
        coroutine.yield("hi def link #{hl} #{opts.group}")

        table.sort(matches, (a, b) -> a < b)
        for i = 1, #matches, @opts.hl.patternlength
            current = {unpack(matches, i, i + @opts.hl.patternlength)}
            notin = table.concat(opts.notin or @opts.notin, ',')
            str = table.concat(current, '\\|')
            coroutine.yield("syntax match #{hl} /#{prefix}\\%(#{str}\\)#{suffix}/ containedin=ALLBUT,#{notin} display")

        table.sort(keywords, (a, b) -> a < b)
        for i = 1, #keywords, @opts.hl.patternlength
            current = {unpack(keywords, i, i + @opts.hl.patternlength)}
            str = table.concat(current, ' ')
            coroutine.yield("syntax keyword #{hl} #{str}")

        table.insert(@syntax_groups, hl)

    highlight: () =>
        ft = vim.bo.filetype

        return if Utils.contains(@opts.ignore, ft)

        bufnr = api.nvim_get_current_buf()
        content = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')

        tags = vim.fn.taglist('.*')
        groups = {}

        for tag in *tags
            tag.language = tag.language\lower()
            tag.language = @opts.ft_conv[tag.language] if @opts.ft_conv[tag.language]

            if @opts.ft_map[ft] and not Utils.contains(@opts.ft_map[ft], tag.language)
                continue

            groups[tag.language] = {} if not groups[tag.language]
            groups[tag.language][tag.kind] = {} if not groups[tag.language][tag.kind]

            table.insert(groups[tag.language][tag.kind], tag)

        for lang, kinds in pairs(groups)
            continue if not @languages[lang] or not @languages[lang].order
            cl = @languages[lang]
            order = cl.order

            for i = 1, #order
                kind = order\sub(i, i)

                continue if not kinds[kind]
                continue if not cl.kinds or not cl.kinds[kind]

                -- print "adding #{kinds[kind]} for #{lang} in #{kind}"
                @makesyntax(lang, kind, kinds[kind], cl.kinds[kind], content)

export neotags = Neotags! if not neotags

return {
    setup: (opts) ->
        path = debug.getinfo(1).source\match('@?(.*/)')
        for filename in io.popen("ls #{path}/languages")\lines()
            lang = filename\gsub('%.lua$', '')
            neotags.language(neotags, lang, require"neotags/languages/#{lang}")

        neotags.setup(neotags, opts)

    highlight: () -> neotags.run(neotags, 'highlight')
    update: () -> neotags.update(neotags)
    toggle: () -> neotags.toggle(neotags)
    language: (lang, opts) -> neotags.language(neotags, lang, opts)
}
