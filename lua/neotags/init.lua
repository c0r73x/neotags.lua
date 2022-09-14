local api = vim.api
local loop = vim.loop
local Utils = require('neotags/utils')
local Neotags
do
  local _class_0
  local _base_0 = {
    setup = function(self, opts)
      if opts then
        self.opts = vim.tbl_deep_extend('force', self.opts, opts)
      end
      if not (self.opts.enable) then
        return 
      end
      local group = vim.api.nvim_create_augroup('NeotagsLua', {
        clear = true
      })
      vim.api.nvim_create_autocmd('Syntax', {
        group = group,
        callback = function()
          return require('neotags').highlight()
        end
      })
      return vim.api.nvim_create_autocmd('BufWritePost', {
        group = group,
        callback = function()
          return require('neotags').update()
        end
      })
    end,
    restart = function(self, cb)
      self:setup()
      return self:run('highlight', cb)
    end,
    currentTagfile = function(self)
      local path = vim.fn.getcwd()
      path = path:gsub('[%.%/]', '__')
      return tostring(self.opts.ctags.directory) .. "/" .. tostring(path) .. ".tags"
    end,
    runCtags = function(self, files)
      if self.ctags_handle then
        return 
      end
      local tagfile = self:currentTagfile()
      local args = self.opts.ctags.args
      args = Utils.concat(args, {
        '-f',
        tagfile
      })
      args = Utils.concat(args, files)
      local stdout
      if self.opts.ctags.verbose then
        stdout = loop.new_pipe(false)
      end
      local stderr
      if self.opts.ctags.verbose then
        stderr = loop.new_pipe(false)
      end
      self.ctags_handle = loop.spawn(self.opts.ctags.binary, {
        args = args,
        cwd = vim.fn.getcwd(),
        stdio = {
          nil,
          stdout,
          stderr
        }
      }, vim.schedule_wrap(function()
        if self.opts.ctags.verbose then
          stdout:read_stop()
          stdout:close()
          stderr:read_stop()
          stderr:close()
        end
        self.ctags_handle:close()
        self.ctags_handle = nil
        vim.bo.tags = tagfile
        return self:run('highlight')
      end))
      if self.opts.ctags.verbose then
        loop.read_start(stdout, function(err, data)
          if data then
            return print(data)
          end
        end)
        return loop.read_start(stderr, function(err, data)
          if data then
            return print(data)
          end
        end)
      end
    end,
    update = function(self)
      if not (self.opts.enable) then
        return 
      end
      local ft = vim.bo.filetype
      if #ft == 0 or Utils.contains(self.opts.ignore, ft) then
        return 
      end
      return self:findFiles(function(files)
        return self:runCtags(files)
      end)
    end,
    findFiles = function(self, callback)
      local path = vim.fn.getcwd()
      if not self.opts.tools.find then
        return callback({
          '-R',
          path
        })
      end
      if self.find_handle then
        return 
      end
      local stdout = loop.new_pipe(false)
      local stderr
      if self.opts.ctags.verbose then
        stderr = loop.new_pipe(false)
      end
      local files = { }
      local args = Utils.concat(self.opts.tools.find.args, {
        path
      })
      self.find_handle = loop.spawn(self.opts.tools.find.binary, {
        args = args,
        cwd = path,
        stdio = {
          nil,
          stdout,
          stderr
        }
      }, vim.schedule_wrap(function()
        stdout:read_stop()
        stdout:close()
        if self.opts.ctags.verbose then
          stderr:read_stop()
          stderr:close()
        end
        self.find_handle:close()
        self.find_handle = nil
        return callback(files)
      end))
      loop.read_start(stdout, function(err, data)
        if not (data) then
          return 
        end
        for _, file in ipairs(Utils.explode('\n', data)) do
          table.insert(files, file)
        end
      end)
      if self.opts.ctags.verbose then
        return loop.read_start(stderr, function(err, data)
          if data then
            return print(data)
          end
        end)
      end
    end,
    run = function(self, func, cb)
      local ft = vim.bo.filetype
      if #ft == 0 or Utils.contains(self.opts.ignore, ft) then
        return 
      end
      local co = nil
      local _exp_0 = func
      if 'highlight' == _exp_0 then
        local tagfile = self:currentTagfile()
        if vim.fn.filereadable(tagfile) == 0 then
          self:update()
        elseif vim.bo.tags ~= tagfile then
          vim.bo.tags = tagfile
        end
        co = coroutine.create(function()
          return self:highlight()
        end)
      elseif 'clear' == _exp_0 then
        co = coroutine.create(function()
          return self:clearsyntax()
        end)
      else
        return 
      end
      if not co then
        return 
      end
      while true do
        local _, cmd = coroutine.resume(co)
        if cmd then
          vim.cmd(cmd)
        end
        if coroutine.status(co) == 'dead' then
          break
        end
      end
      if cb then
        return cb()
      end
    end,
    toggle = function(self)
      self.opts.enable = not self.opts.enable
      if (self.opts.enable) then
        return self:restart(function()
          return print("Neotags enabled")
        end)
      else
        return self:run('clear', function()
          return print("Neotags disabled")
        end)
      end
    end,
    language = function(self, lang, opts)
      self.languages[lang] = opts
    end,
    clearsyntax = function(self)
      vim.api.nvim_create_augroup('NeotagsLua', {
        clear = true
      })
      local bufnr = api.nvim_get_current_buf()
      self.highlighting[bufnr] = false
      for _, hl in pairs(self.syntax_groups[bufnr]) do
        coroutine.yield("silent! syntax clear " .. tostring(hl))
      end
      self.syntax_groups[bufnr] = { }
    end,
    makesyntax = function(self, lang, kind, group, opts, content, added, bufnr)
      local hl = "_Neotags_" .. tostring(lang) .. "_" .. tostring(kind) .. "_" .. tostring(opts.group)
      local matches = { }
      local keywords = { }
      local prefix = opts.prefix or self.opts.hl.prefix
      local suffix = opts.suffix or self.opts.hl.suffix
      local minlen = opts.minlen or self.opts.hl.minlen
      local forbidden = {
        '*'
      }
      for _index_0 = 1, #group do
        local _continue_0 = false
        repeat
          local tag = group[_index_0]
          if #tag.name < minlen then
            _continue_0 = true
            break
          end
          if Utils.contains(added, tag.name) then
            _continue_0 = true
            break
          end
          if Utils.contains(forbidden, tag.name) then
            _continue_0 = true
            break
          end
          if not content:find(tag.name) then
            table.insert(added, tag.name)
            _continue_0 = true
            break
          end
          if (prefix == self.opts.hl.prefix and suffix == self.opts.hl.suffix and opts.allow_keyword ~= false and not tag.name:find('.', 1, true) and tag.name ~= 'contains') then
            if not Utils.contains(keywords, tag.name) then
              table.insert(keywords, tag.name)
            end
          else
            if not Utils.contains(matches, tag.name) then
              table.insert(matches, tag.name)
            end
          end
          table.insert(added, tag.name)
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      vim.api.nvim_set_hl(0, hl, {
        link = opts.group
      })
      table.sort(matches, function(a, b)
        return a < b
      end)
      local merged = { }
      if opts.extended_notin and opts.extend_notin == false then
        merged = opts.notin or self.opts.notin or { }
      else
        local a = self.opts.notin or { }
        local b = opts.notin or { }
        local max = (#a > #b) and #a or #b
        for i = 1, max do
          if a[i] then
            merged[#merged + 1] = a[i]
          end
          if b[i] then
            merged[#merged + 1] = b[i]
          end
        end
      end
      local notin = ''
      if #merged > 0 then
        notin = "containedin=ALLBUT," .. tostring(table.concat(merged, ','))
      end
      coroutine.yield("syntax clear " .. tostring(hl))
      for i = 1, #matches, self.opts.hl.patternlength do
        local current = {
          unpack(matches, i, i + self.opts.hl.patternlength)
        }
        local str = table.concat(current, '\\|')
        coroutine.yield("syntax match " .. tostring(hl) .. " /" .. tostring(prefix) .. "\\%(" .. tostring(str) .. "\\)" .. tostring(suffix) .. "/ " .. tostring(notin) .. " display")
      end
      table.sort(keywords, function(a, b)
        return a < b
      end)
      for i = 1, #keywords, self.opts.hl.patternlength do
        local current = {
          unpack(keywords, i, i + self.opts.hl.patternlength)
        }
        local str = table.concat(current, ' ')
        coroutine.yield("syntax keyword " .. tostring(hl) .. " " .. tostring(str) .. " " .. tostring(notin))
      end
      if not self.syntax_groups[bufnr] then
        self.syntax_groups[bufnr] = { }
      end
      return table.insert(self.syntax_groups[bufnr], hl)
    end,
    highlight = function(self)
      local bufnr = api.nvim_get_current_buf()
      if self.highlighting[bufnr] then
        return 
      end
      local ft = vim.bo.filetype
      if #ft == 0 or Utils.contains(self.opts.ignore, ft) then
        return 
      end
      self.highlighting[bufnr] = true
      local content = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
      local tags = vim.fn.taglist('^[a-zA-Z$_].*$')
      local groups = { }
      for _index_0 = 1, #tags do
        local _continue_0 = false
        repeat
          local tag = tags[_index_0]
          if not tag.language then
            _continue_0 = true
            break
          end
          if tag.name:match('^[a-zA-Z]{,2}$') then
            _continue_0 = true
            break
          end
          if tag.name:match('^__anon.*$') then
            _continue_0 = true
            break
          end
          tag.language = tag.language:lower()
          if self.opts.ft_conv[tag.language] then
            tag.language = self.opts.ft_conv[tag.language]
          end
          if self.opts.ft_map[ft] ~= nil and Utils.contains(self.opts.ft_map[ft], tag.language) == false then
            _continue_0 = true
            break
          end
          if self.opts.ft_map[ft] == nil and ft ~= tag.language then
            _continue_0 = true
            break
          end
          if not groups[tag.language] then
            groups[tag.language] = { }
          end
          if not groups[tag.language][tag.kind] then
            groups[tag.language][tag.kind] = { }
          end
          table.insert(groups[tag.language][tag.kind], tag)
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      local langmap = self.opts.ft_map[ft] or {
        ft
      }
      for _, lang in pairs(langmap) do
        local _continue_0 = false
        repeat
          if not self.languages[lang] or not self.languages[lang].order then
            _continue_0 = true
            break
          end
          local cl = self.languages[lang]
          local order = cl.order
          local added = { }
          local kinds = groups[lang]
          if not kinds then
            _continue_0 = true
            break
          end
          for i = 1, #order do
            local _continue_1 = false
            repeat
              local kind = order:sub(i, i)
              if not kinds[kind] then
                _continue_1 = true
                break
              end
              if not cl.kinds or not cl.kinds[kind] then
                _continue_1 = true
                break
              end
              self:makesyntax(lang, kind, kinds[kind], cl.kinds[kind], content, added, bufnr)
              _continue_1 = true
            until true
            if not _continue_1 then
              break
            end
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      self.highlighting[bufnr] = false
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, opts)
      self.opts = {
        enable = true,
        ft_conv = {
          ['c++'] = 'cpp',
          ['moonscript'] = 'moon',
          ['c#'] = 'cs'
        },
        ft_map = {
          cpp = {
            'cpp',
            'c'
          },
          c = {
            'c',
            'cpp'
          }
        },
        hl = {
          minlen = 3,
          patternlength = 2048,
          prefix = [[\C\<]],
          suffix = [[\>]]
        },
        tools = {
          find = nil
        },
        ctags = {
          run = true,
          directory = vim.fn.expand('~/.vim_tags'),
          verbose = false,
          binary = 'ctags',
          args = {
            '--fields=+l',
            '--c-kinds=+p',
            '--c++-kinds=+p',
            '--sort=no'
          }
        },
        ignore = {
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
        notin = {
          '.*String.*',
          '.*Comment.*',
          'cIncluded',
          'cCppOut2',
          'cCppInElse2',
          'cCppOutIf2',
          'pythonDocTest',
          'pythonDocTest2'
        }
      }
      self.languages = { }
      self.syntax_groups = { }
      self.highlighting = { }
      self.ctags_handle = nil
      self.find_handle = nil
    end,
    __base = _base_0,
    __name = "Neotags"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Neotags = _class_0
end
if not neotags then
  neotags = Neotags()
end
return {
  setup = function(opts)
    local path = debug.getinfo(1).source:match('@?(.*/)')
    for filename in io.popen("ls " .. tostring(path) .. "/languages"):lines() do
      local lang = filename:gsub('%.lua$', '')
      neotags.language(neotags, lang, require("neotags/languages/" .. tostring(lang)))
    end
    return neotags.setup(neotags, opts)
  end,
  highlight = function()
    return neotags.run(neotags, 'highlight')
  end,
  update = function()
    return neotags.update(neotags)
  end,
  toggle = function()
    return neotags.toggle(neotags)
  end,
  language = function(lang, opts)
    return neotags.language(neotags, lang, opts)
  end
}
