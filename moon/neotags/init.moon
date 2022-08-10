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
                c: { 'c', 'cpp' },
            },
            hl: {
                minlen: 3,
                patternlength: 2048,
                prefix: [[\C\<]],
                suffix: [[\>]],
            },
            tools: {
                find: nil,
            },
            ctags: {
                run: true,
                directory: vim.fn.expand('~/.vim_tags'),
                verbose: false,
                binary: 'ctags'
                args: {
                    '--fields=+l',
                    '--c-kinds=+p',
                    '--c++-kinds=+p',
                    '--sort=no',
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
                'text',
                'plaintext'
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
        @highlighting = false
        @ctags_handle = nil
        @find_handle = nil

    setup: (opts) =>
        @opts = vim.tbl_deep_extend('force', @opts, opts) if opts
        return unless @opts.enable

        vim.api.nvim_create_augroup('NeotagsLua', { clear: true })
        vim.api.nvim_create_autocmd(
            'Syntax',
            {
                group: 'NeotagsLua',
                callback: () -> require'neotags'.highlight()
            }
        )
        vim.api.nvim_create_autocmd(
            'BufWritePost',
            {
                group: 'NeotagsLua',
                callback: () -> require'neotags'.update()
            }
        )

    restart: (cb) =>
        @setup()
        @run('highlight', cb)

    currentTagfile: () =>
        path = vim.fn.getcwd()
        path = path\gsub('[%.%/]', '__')
        return "#{@opts.ctags.directory}/#{path}.tags"

    runCtags: (files) =>
        return if @ctags_handle

        tagfile = @currentTagfile()
        args = @opts.ctags.args
        args = Utils.concat(args, { '-f', tagfile })
        args = Utils.concat(args, files)

        stdout = loop.new_pipe(false) if @opts.ctags.verbose
        stderr = loop.new_pipe(false) if @opts.ctags.verbose

        @ctags_handle = loop.spawn(
             @opts.ctags.binary, {
                args: args,
                cwd: vim.fn.getcwd(),
                stdio: {nil, stdout, stderr},
            },
            vim.schedule_wrap(() ->
                if @opts.ctags.verbose
                    stdout\read_stop()
                    stdout\close()

                    stderr\read_stop()
                    stderr\close()

                @ctags_handle\close()
                @ctags_handle = nil

                vim.bo.tags = tagfile

                @run('highlight')
            )
        )

        if @opts.ctags.verbose
            loop.read_start(stdout, (err, data) -> print data if data)
            loop.read_start(stderr, (err, data) -> print data if data)

    update: () =>
        return unless @opts.enable

        ft = vim.bo.filetype
        return if #ft == 0 or Utils.contains(@opts.ignore, ft)

        @findFiles((files) -> @runCtags(files))

    findFiles: (callback) =>
        path = vim.fn.getcwd()

        return callback({ '-R', path }) if not @opts.tools.find
        return if @find_handle

        stdout = loop.new_pipe(false)
        stderr = loop.new_pipe(false) if @opts.ctags.verbose

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

                if @opts.ctags.verbose
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

        if @opts.ctags.verbose
            loop.read_start(stderr, (err, data) -> print data if data)

    run: (func, cb) =>
        ft = vim.bo.filetype
        return if #ft == 0 or Utils.contains(@opts.ignore, ft)

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
            else return

        return if not co

        while true do
            _, cmd = coroutine.resume(co)
            vim.cmd(cmd) if cmd and not cmd\match('Vim:E%d+')
            break if coroutine.status(co) == 'dead'

        cb() if cb

    toggle: () =>
        @opts.enable = not @opts.enable
        if (@opts.enable)
            @restart(() -> print("Neotags enabled"))
        else
            @run('clear', () -> print("Neotags disabled"))

    language: (lang, opts) =>
        @languages[lang] = opts

    clearsyntax: () =>
        vim.api.nvim_create_augroup('NeotagsLua', { clear: true })

        for _, hl in pairs(@syntax_groups)
            coroutine.yield("silent! syntax clear #{hl}")

        @syntax_groups = {}

    makesyntax: (lang, kind, group, opts, content, added) =>
        hl = "_Neotags_#{lang}_#{kind}_#{opts.group}"

        matches = {}
        keywords = {}

        prefix = opts.prefix or @opts.hl.prefix
        suffix = opts.suffix or @opts.hl.suffix
        minlen = opts.minlen or @opts.hl.minlen

        forbidden = {
            '*',
        }

        for tag in *group
            continue if #tag.name < minlen
            continue if Utils.contains(added, tag.name)
            continue if Utils.contains(forbidden, tag.name)

            if not content\find(tag.name)
                table.insert(added, tag.name)
                continue

            if (prefix == @opts.hl.prefix and suffix == @opts.hl.suffix and
                    opts.allow_keyword != false and not tag.name\find('.', 1, true) and
                    tag.name != 'contains')
                table.insert(keywords, tag.name) if not Utils.contains(keywords, tag.name)
            else
                table.insert(matches, tag.name) if not Utils.contains(matches, tag.name)

            table.insert(added, tag.name)

        vim.api.nvim_set_hl(0, hl, { link: opts.group })

        table.sort(matches, (a, b) -> a < b)
        merged = {}

        if opts.extended_notin and opts.extend_notin == false
            merged = opts.notin or @opts.notin or {}
        else
            a = @opts.notin or {}
            b = opts.notin or {}
            max = (#a > #b) and #a or #b
            for i=1,max
                merged[#merged+1] = a[i] if a[i]
                merged[#merged+1] = b[i] if b[i]

        notin = ''
        notin = "containedin=ALLBUT,#{table.concat(merged, ',')}" if #merged > 0

        for i = 1, #matches, @opts.hl.patternlength
            current = {unpack(matches, i, i + @opts.hl.patternlength)}
            str = table.concat(current, '\\|')
            coroutine.yield("syntax match #{hl} /#{prefix}\\%(#{str}\\)#{suffix}/ #{notin} display")

        table.sort(keywords, (a, b) -> a < b)
        for i = 1, #keywords, @opts.hl.patternlength
            current = {unpack(keywords, i, i + @opts.hl.patternlength)}
            str = table.concat(current, ' ')
            coroutine.yield("syntax keyword #{hl} #{str} #{notin}")

        table.insert(@syntax_groups, hl)

    highlight: () =>
        return if @highlighting

        ft = vim.bo.filetype
        return if #ft == 0 or Utils.contains(@opts.ignore, ft)

        @highlighting = true

        bufnr = api.nvim_get_current_buf()
        content = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')

        tags = vim.fn.taglist('^[a-zA-Z$_].*$')
        groups = {}

        for tag in *tags
            continue if not tag.language
            continue if tag.name\match('^[a-zA-Z]{,2}$')
            continue if tag.name\match('^__anon.*$')

            tag.language = tag.language\lower()
            tag.language = @opts.ft_conv[tag.language] if @opts.ft_conv[tag.language]

            if @opts.ft_map[ft] != nil and Utils.contains(@opts.ft_map[ft], tag.language) == false
                continue

            if @opts.ft_map[ft] == nil and ft != tag.language
                continue

            -- if tag.language == 'vim'
                -- print require'lsp'.format_as_json(tag)

            groups[tag.language] = {} if not groups[tag.language]
            groups[tag.language][tag.kind] = {} if not groups[tag.language][tag.kind]

            table.insert(groups[tag.language][tag.kind], tag)

        langmap = @opts.ft_map[ft] or {ft}

        for _, lang in pairs(langmap)
            continue if not @languages[lang] or not @languages[lang].order
            cl = @languages[lang]
            order = cl.order
            added = {}
            kinds = groups[lang]
            continue if not kinds

            for i = 1, #order
                kind = order\sub(i, i)

                continue if not kinds[kind]
                continue if not cl.kinds or not cl.kinds[kind]

                -- print "adding #{kinds[kind]} for #{lang} in #{kind}"
                @makesyntax(lang, kind, kinds[kind], cl.kinds[kind], content, added)

        @highlighting = false

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
