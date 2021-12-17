local api = vim.api
local Neotags
do
  local _class_0
  local _base_0 = {
    setup = function(self, opts)
      if opts then
        self.opts:extend(opts)
      end
      return self:run()
    end,
    run = function(self)
      local co = coroutine.create(function()
        return self:highlight()
      end)
      while true do
        local _, cmd = coroutine.resume(co)
        if cmd then
          vim.cmd(cmd)
        end
        if coroutine.status(co) == 'dead' then
          break
        end
      end
    end,
    language = function(self, lang, opts)
      self.languages[lang] = opts
    end,
    contains = function(self, tags, el)
      for _, value in pairs(tags) do
        if value == el then
          return true
        end
      end
      return false
    end,
    makesyntax = function(self, lang, kind, group, opts, content)
      local hl = "_Neotags_" .. tostring(lang) .. "_" .. tostring(kind) .. "_" .. tostring(opts.group)
      coroutine.yield("silent! syntax clear " .. tostring(hl))
      local notin = { }
      local matches = { }
      local keywords = { }
      local prefix = opts.prefix or self.opts.hl.prefix
      local suffix = opts.suffix or self.opts.hl.suffix
      for _index_0 = 1, #group do
        local _continue_0 = false
        repeat
          local tag = group[_index_0]
          if tag.name:match('^__anon.*$') then
            _continue_0 = true
            break
          end
          if not content:find(tag.name) then
            _continue_0 = true
            break
          end
          if (prefix == self.opts.hl.prefix and suffix == self.opts.hl.suffix and opts.allow_keyword ~= false and not tag.name:match('%.')) then
            if not self:contains(keywords, tag.name) then
              table.insert(keywords, tag.name)
            end
          else
            if not self:contains(matches, tag.name) then
              table.insert(matches, tag.name)
            end
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      table.sort(matches, function(a, b)
        return a < b
      end)
      for i = 1, #matches, self.opts.hl.patternlength do
        local current = {
          unpack(matches, i, i + self.opts.hl.patternlength)
        }
        notin = table.concat(self.opts.notin, ',')
        local str = table.concat(current, '\\|')
        coroutine.yield("syntax match " .. tostring(hl) .. " /" .. tostring(prefix) .. "\\%(" .. tostring(str) .. "\\)" .. tostring(suffix) .. "/ containedin=ALLBUT," .. tostring(notin) .. " display")
      end
      for i = 1, #keywords, self.opts.hl.patternlength do
        local current = {
          unpack(keywords, i, i + self.opts.hl.patternlength)
        }
        local str = table.concat(current, ' ')
        coroutine.yield("syntax keyword " .. tostring(hl) .. " " .. tostring(str))
      end
      return coroutine.yield("hi def link " .. tostring(hl) .. " " .. tostring(opts.group))
    end,
    highlight = function(self)
      local bufnr = api.nvim_get_current_buf()
      local content = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
      local tags = vim.fn.taglist('.*')
      local groups = { }
      for _index_0 = 1, #tags do
        local tag = tags[_index_0]
        tag.language = tag.language:lower()
        if self.opts.ft_conv[tag.language] then
          tag.language = self.opts.ft_conv[tag.language]
        end
        if not groups[tag.language] then
          groups[tag.language] = { }
        end
        if not groups[tag.language][tag.kind] then
          groups[tag.language][tag.kind] = { }
        end
        table.insert(groups[tag.language][tag.kind], tag)
      end
      for lang, kinds in pairs(groups) do
        local _continue_0 = false
        repeat
          if not self.languages[lang] or not self.languages[lang].order then
            _continue_0 = true
            break
          end
          local cl = self.languages[lang]
          local order = string.reverse(cl.order)
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
              self:makesyntax(lang, kind, kinds[kind], cl.kinds[kind], content)
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
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, opts)
      self.opts = {
        ft_conv = {
          ['c++'] = 'cpp',
          ['c#'] = 'cs'
        },
        hl = {
          patternlength = 2048,
          prefix = [[\C\<]],
          suffix = [[\>]]
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
local neotags = Neotags()
return {
  setup = function(opts)
    local path = debug.getinfo(1).source:match('@?(.*/)')
    for filename in io.popen("ls " .. tostring(path) .. "/neotags/"):lines() do
      local lang = filename:gsub('%.lua$', '')
      neotags:language(lang, require("neotags/" .. tostring(lang)))
    end
    neotags:setup(opts)
    return vim.cmd([[            augroup NeotagsLua
            autocmd!
            autocmd BufReadPre * lua require'neotags'.highlight()
            autocmd BufEnter * lua require'neotags'.highlight()
            augroup END
        ]])
  end,
  highlight = function()
    return neotags:run()
  end,
  language = function(lang, opts)
    return neotags:language(lang, opts)
  end
}
