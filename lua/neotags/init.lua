local _module_0 = nil;local api = vim.api;local loop = 
vim.uv;local Utils = 

require('neotags/utils')

local Neotags;do local _class_0;local _base_0 = { setup = function(self, opts)if 








































































opts then self.opts = vim.tbl_deep_extend('force', self.opts, opts)end;if not 
self.opts.enable then return end;local hl_events = 

self.opts.autocmd.highlight;if 
self.opts.hl.treesitter and #hl_events == 1 and hl_events[1] == 'Syntax' then
hl_events = { 'BufEnter', 'BufReadPost' }end;local group = 

vim.api.nvim_create_augroup('NeotagsLua', { clear = true })



vim.api.nvim_create_autocmd(hl_events, { group = group, callback = function()return 
require('neotags').highlight()end })return 





vim.api.nvim_create_autocmd(self.opts.autocmd.update, { group = group, callback = function()return 
require('neotags').update()end })end, restart = function(self, cb)




self:setup()return 
self:run('highlight', cb)end, currentTagfile = function(self)if 


vim.b.neotags_current_tagfile and #vim.b.neotags_current_tagfile > 0 then return 
vim.b.neotags_current_tagfile end;local path = 

vim.fn.getcwd()
path = path:gsub('[%.%/]', '__')local dir = 
self.opts.ctags.directory;if 
type(dir) == 'function' then dir = dir()end

os.execute("[ ! -d '" .. tostring(dir) .. "' ] && mkdir -p '" .. tostring(dir) .. "' &> /dev/null")
vim.b.neotags_current_tagfile = tostring(dir) .. "/" .. tostring(path) .. ".tags"return 

vim.b.neotags_current_tagfile end, runCtags = function(self, files)if 


self.ctags_handle then return end;local tagfile = 

self:currentTagfile()local args = 
{  }local concat = 
Utils.concat;if 

self.opts.ctags.ptags then for _, arg in 
ipairs(self.opts.ctags.args) do if 
string.match(arg, '^%-%-') then
args[#args + 1] = "-c"end
args[#args + 1] = arg end

args = concat(args, { '-f', tagfile })
args[#args + 1] = vim.fn.getcwd()else

args = self.opts.ctags.args
args = concat(args, { '-f', tagfile })
args = concat(args, files)end

local stdout;if self.opts.ctags.verbose then stdout = loop.new_pipe(false)end
local stderr;if self.opts.ctags.verbose then stderr = loop.new_pipe(false)end



self.ctags_handle = loop.spawn(self.opts.ctags.binary, { args = args, cwd = 
vim.fn.getcwd(), stdio = { 
nil, stdout, stderr } }, 

vim.schedule_wrap(function()if 
self.opts.ctags.verbose then
stdout:read_stop()
stdout:close()

stderr:read_stop()
stderr:close()end

self.ctags_handle:close()
self.ctags_handle = nil

vim.bo.tags = tagfile;return 

self:run('highlight')end))if 



self.opts.ctags.verbose then
loop.read_start(stdout, function(err, data)if data then return print(data)end end)return 
loop.read_start(stderr, function(err, data)if data then return print(data)end end)end end, update = function(self)if not 


self.opts.enable then return end;local ft = 

vim.bo.filetype;if #
ft == 0 or Utils.contains(self.opts.ignore, ft) then return end;if 

self.opts.ctags.ptags then return 
self:runCtags(nil)else return 

self:findFiles(function(files)return self:runCtags(files)end)end end, findFiles = function(self, callback)local path = 


vim.fn.getcwd()if not 

self.opts.tools.find then return callback({ '-R', path })end;if 
self.find_handle then return end;local stdout = 

loop.new_pipe(false)
local stderr;if self.opts.ctags.verbose then stderr = loop.new_pipe(false)end;local files = 

{  }local args = 
Utils.concat(self.opts.tools.find.args, { path })local chunks = 
{  }


self.find_handle = loop.spawn(self.opts.tools.find.binary, { args = args, cwd = 
path, stdio = { 
nil, stdout, stderr } }, 

vim.schedule_wrap(function()
stdout:read_stop()
stdout:close()if 

self.opts.ctags.verbose then
stderr:read_stop()
stderr:close()end

self.find_handle:close()
self.find_handle = nil

files = Utils.explode('\n', table.concat(chunks))return 
callback(files)end))



loop.read_start(stdout, function(err, data)if not 
data then return end
chunks[#chunks + 1] = data end)if 


self.opts.ctags.verbose then return 
loop.read_start(stderr, function(err, data)if data then return print(data)end end)end end, run = function(self, func, cb)local ft = 


vim.bo.filetype;if #
ft == 0 or Utils.contains(self.opts.ignore, ft) then return end;local co = 

nil;if 


'highlight' == func then local tagfile = 
self:currentTagfile()if 

vim.fn.filereadable(tagfile) == 0 then
self:update()elseif 
vim.bo.tags ~= tagfile then
vim.bo.tags = tagfile end;if 

self.opts.hl.treesitter then
co = coroutine.create(function()return self:highlighttreesitter()end)else

co = coroutine.create(function()return self:highlightsyntax()end)end elseif 
'clear' == func then if 
self.opts.hl.treesitter then
co = coroutine.create(function()return self:cleartreesitter()end)else

co = coroutine.create(function()return self:clearsyntax()end)end else
return end;if not 

co then return end;while 

true do local ok,cmd = 
coroutine.resume(co)if not 
ok then
vim.notify("neotags: " .. tostring(cmd), vim.log.levels.WARN)
break end;if 


cmd then vim.defer_fn(function()return vim.cmd(cmd)end, 10)end;if 
coroutine.status(co) == 'dead' then break end end;if 

cb then return cb()end end, toggle = function(self)


self.opts.enable = not self.opts.enable;if (
self.opts.enable) then return 
self:restart(function()return print("Neotags enabled")end)else return 

self:run('clear', function()return print("Neotags disabled")end)end end, language = function(self, lang, opts)


self.languages[lang] = opts end, clearsyntax = function(self)


vim.api.nvim_create_augroup('NeotagsLua', { clear = true })local bufnr = 
api.nvim_get_current_buf()
self.highlighting[bufnr] = false;local yield = 

coroutine.yield;for _, hl in 

pairs(self.syntax_groups[bufnr]) do
yield("silent! syntax clear " .. tostring(hl))end

self.syntax_groups[bufnr] = {  }end, cleartreesitter = function(self)


vim.api.nvim_create_augroup('NeotagsLua', { clear = true })local bufnr = 
api.nvim_get_current_buf()
self.highlighting[bufnr] = false;return 
api.nvim_buf_clear_namespace(bufnr, self.ns_id, 0, -1)end, maketreesitter = function(self, bufnr, tag_map)


api.nvim_buf_clear_namespace(bufnr, self.ns_id, 0, -1)local ok,lang = 

pcall(vim.treesitter.language.get_lang, vim.bo[bufnr].filetype)if not 
ok or not lang then lang = vim.bo[bufnr].filetype end;if not 
lang or #lang == 0 then return false end

local parser;ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)if not 
ok or not parser then return false end;local trees = 

parser:parse()if not (
trees and trees[1]) then return false end;local root = 

trees[1]:root()local query = 

self.query_cache[lang]if not 
query then
ok = false
ok, query = pcall(vim.treesitter.query.parse, lang, '[(identifier) (type_identifier)] @id')if not 
ok then
ok, query = pcall(vim.treesitter.query.parse, lang, '(identifier) @id')end;if not 
ok then
ok, query = pcall(vim.treesitter.query.parse, lang, '[(name) (simple_identifier)] @id')end;if not 
ok then
ok, query = pcall(vim.treesitter.query.parse, lang, '(name) @id')end;if not 
ok then
ok, query = pcall(vim.treesitter.query.parse, lang, '(simple_identifier) @id')end;if not 
ok then return false end
self.query_cache[lang] = query end;for _, node in 

query:iter_captures(root, bufnr, 0, -1) do local name = 
vim.treesitter.get_node_text(node, bufnr)if 
tag_map[name] then local sr,sc,er,ec = 
node:range()

api.nvim_buf_set_extmark(bufnr, self.ns_id, sr, sc, { end_row = er, end_col = 
ec, hl_group = 
tag_map[name], priority = 
120 })end end;return 


true end, makesyntax = function(self, lang, kind, group, opts, bufnr, langcontains, added)local hl = 


"_Neotags_" .. tostring(lang) .. "_" .. tostring(kind) .. "_" .. tostring(opts.group)local matches = 

{  }local keywords = 
{  }local matches_seen = 
{  }local keywords_seen = 
{  }local allow_keyword = 

opts.allow_keyword;local prefix = 
opts.prefix or self.opts.hl.prefix;local suffix = 
opts.suffix or self.opts.hl.suffix;local minlen = 
opts.minlen or self.opts.hl.minlen;local yield = 
coroutine.yield;local any_added = 

false;for _index_0 = 
1, #group do local tag = group[_index_0]if #
tag.name < minlen then goto _continue_0 end;local low = 
tag.name:lower()if 
added[low] then goto _continue_0 end;if 
tag.name == '*' then goto _continue_0 end;if (

prefix == self.opts.hl.prefix and suffix == self.opts.hl.suffix and allow_keyword ~= false and not tag.name:find('.', 1, true) and tag.name ~= 'contains') then if not 


keywords_seen[tag.name] then
keywords[#keywords + 1] = tag.name
keywords_seen[tag.name] = true end elseif not 
tag.name:find('.', 1, true) then if not 
matches_seen[tag.name] then
matches[#matches + 1] = tag.name
matches_seen[tag.name] = true end end

added[low] = true
any_added = true::_continue_0::end;if not 

any_added then return end
vim.api.nvim_set_hl(0, hl, { link = opts.group })

table.sort(matches, function(a, b)return a < b end)local merged = 
{  }local notin = 
''if not 

langcontains then if 
opts.extend_notin ~= nil and opts.extend_notin == false then
merged = opts.notin or self.opts.notin or {  }else local a = 

self.opts.notin or {  }local b = 
opts.notin or {  }local max = (#
a > #b) and #a or #b;for i = 
1, max do if 
a[i] then merged[#merged + 1] = a[i]end;if 
b[i] then merged[#merged + 1] = b[i]end end end;if #

merged > 0 then notin = "contained containedin=ALLBUT," .. tostring(table.concat(merged, ','))end else

notin = "contained containedin=" .. tostring(table.concat(langcontains, ','))end

yield("syntax clear " .. tostring(hl))local patternlength = 

self.opts.hl.patternlength;for i = 
1, #matches, patternlength do local current = { 
unpack(matches, i, i + patternlength) }local str = 
table.concat(current, '\\|')
yield("syntax match " .. tostring(hl) .. " /" .. tostring(prefix) .. "\\%(" .. tostring(str) .. "\\)" .. tostring(suffix) .. "/ " .. tostring(notin) .. " display")end;if #

merged > 0 and not langcontains then notin = "contained=ALLBUT," .. tostring(table.concat(merged, ','))end

table.sort(keywords, function(a, b)return a < b end)for i = 
1, #keywords, patternlength do local current = { 
unpack(keywords, i, i + patternlength) }local str = 
table.concat(current, ' ')
yield("syntax keyword " .. tostring(hl) .. " " .. tostring(str) .. " " .. tostring(notin) .. " display")end;if not 

self.syntax_groups[bufnr] then self.syntax_groups[bufnr] = {  }end
self.syntax_groups[bufnr][#self.syntax_groups[bufnr] + 1] = hl end, collectgroups = function(self, ft, content)local old_tagfunc = 


vim.bo.tagfunc;if 
old_tagfunc and #old_tagfunc > 0 then vim.bo.tagfunc = ''end;local ok,tags = 
pcall(vim.fn.taglist, '^[a-zA-Z$_].*$')if 
old_tagfunc and #old_tagfunc > 0 then vim.bo.tagfunc = old_tagfunc end;if not 
ok then return {  }end;local word_set = 

{  }for word in 
content:gmatch('[a-zA-Z$_][a-zA-Z0-9$_]*') do
word_set[word] = true end;local groups = 

{  }for _index_0 = 

1, #tags do local tag = tags[_index_0]if not 
tag.language then goto _continue_0 end

tag.language = tag.language:lower()if 
self.opts.ft_conv[tag.language] then tag.language = self.opts.ft_conv[tag.language]end;if not 

self.languages[tag.language] then goto _continue_0 end;if not 
self.languages[tag.language].order then goto _continue_0 end;if not 
self.languages[tag.language].order:find(tag.kind) then goto _continue_0 end;if #

tag.name < self.opts.hl.minlen then goto _continue_0 end;if 

self.languages[tag.language].reserved then if 
Utils.contains(self.languages[tag.language].reserved, tag.name) then goto _continue_0 end end;if 

tag.name:match('^[a-zA-Z]{,2}$') then goto _continue_0 end;if 
tag.name:match('^_?_?anon') then goto _continue_0 end;if 

self.opts.ft_map[ft] ~= nil and Utils.contains(self.opts.ft_map[ft], tag.language) == false then
goto _continue_0 end;if 

self.opts.ft_map[ft] == nil and ft ~= tag.language then
goto _continue_0 end;if not 

word_set[tag.name] then goto _continue_0 end;if not 

groups[tag.language] then groups[tag.language] = {  }end;if not 
groups[tag.language][tag.kind] then groups[tag.language][tag.kind] = {  }end
groups[tag.language][tag.kind][#groups[tag.language][tag.kind] + 1] = tag::_continue_0::end;return 

groups end, highlighttreesitter = function(self)local bufnr = 


api.nvim_get_current_buf()if 
self.highlighting[bufnr] then return end;local ft = 

vim.bo.filetype;if #
ft == 0 or Utils.contains(self.opts.ignore, ft) then return end

self.highlighting[bufnr] = true;local content = 

table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')local groups = 
self:collectgroups(ft, content)local langmap = 
self.opts.ft_map[ft] or { ft }local tag_map = 
{  }for klang, vlang in 

pairs(langmap) do
local lang;if type(klang) ~= "string" then lang = vlang end;if 

type(klang) == "string" then
lang = klang end;if not 

self.languages[lang] or not self.languages[lang].order then goto _continue_0 end;local cl = 
self.languages[lang]local order = 
cl.order;local kinds = 
groups[lang]if not 
kinds then goto _continue_0 end;local added = 
{  }if 

self.languages[lang].reserved then local _list_0 = 
self.languages[lang].reserved;for _index_0 = 1, #_list_0 do local reserved_name = _list_0[_index_0]local low = 
reserved_name:lower()if not 
added[low] then if not 
tag_map[reserved_name] then tag_map[reserved_name] = 'neotags_Reserved'end
added[low] = true end end end;for i = 

1, #order do local kind = 
order:sub(i, i)if not 

kinds[kind] then goto _continue_1 end;if not 
cl.kinds or not cl.kinds[kind] then goto _continue_1 end;local kopts = 
cl.kinds[kind]local hl = 
"_Neotags_" .. tostring(lang) .. "_" .. tostring(kind) .. "_" .. tostring(kopts.group)
vim.api.nvim_set_hl(0, hl, { link = kopts.group })local minlen = 
kopts.minlen or self.opts.hl.minlen;local _list_0 = 

kinds[kind]for _index_0 = 1, #_list_0 do local tag = _list_0[_index_0]if #
tag.name < minlen then goto _continue_2 end;local low = 
tag.name:lower()if 
added[low] then goto _continue_2 end;if 
tag.name == '*' then goto _continue_2 end;if 
tag.name:find('.', 1, true) then goto _continue_2 end;if not 

tag_map[tag.name] then tag_map[tag.name] = hl end
added[low] = true::_continue_2::end::_continue_1::end::_continue_0::end;if 

next(tag_map) == nil then return end;if not 

self:maketreesitter(bufnr, tag_map) then
self.highlighting[bufnr] = false
self:highlightsyntax()
return end

self.highlighting[bufnr] = false end, highlightsyntax = function(self)local bufnr = 


api.nvim_get_current_buf()if 
self.highlighting[bufnr] then return end;local ft = 

vim.bo.filetype;if #
ft == 0 or Utils.contains(self.opts.ignore, ft) then return end

self.highlighting[bufnr] = true;local content = 

table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')local groups = 
self:collectgroups(ft, content)local langmap = 
self.opts.ft_map[ft] or { ft }for klang, vlang in 

pairs(langmap) do
local lang;if type(klang) ~= "string" then lang = vlang end;local langcontains = 
nil;if 

type(klang) == "string" then
lang = klang
langcontains = vlang end;if not 

self.languages[lang] or not self.languages[lang].order then goto _continue_0 end;local cl = 
self.languages[lang]local order = 
cl.order;local kinds = 
groups[lang]if not 
kinds then goto _continue_0 end;local added = 
{  }if 

self.languages[lang].reserved then
local reserved;do local _accum_0 = {  }local _len_0 = 1;local _list_0 = self.languages[lang].reserved;for _index_0 = 1, #_list_0 do local reserved = _list_0[_index_0]_accum_0[_len_0] = { name = reserved }_len_0 = _len_0 + 1 end;reserved = _accum_0 end

self:makesyntax(lang, 'reserved', reserved, { group = 'neotags_Reserved' }, bufnr, langcontains, added)end;for i = 


1, #order do local kind = 
order:sub(i, i)if not 

kinds[kind] then goto _continue_1 end;if not 
cl.kinds or not cl.kinds[kind] then goto _continue_1 end

self:makesyntax(lang, kind, kinds[kind], cl.kinds[kind], bufnr, langcontains, added)::_continue_1::end::_continue_0::end

self.highlighting[bufnr] = false end }if _base_0.__index == nil then _base_0.__index = _base_0 end;_class_0 = setmetatable({ __init = function(self, opts)self.opts = { enable = true, autocmd = { highlight = { 'Syntax', 'BufReadPost' }, update = { 'BufWritePost' } }, ft_conv = { ['c++'] = 'cpp', ['moonscript'] = 'moon', ['c#'] = 'cs' }, ft_map = { cpp = { 'cpp', 'c' }, c = { 'c', 'cpp' } }, hl = { minlen = 3, patternlength = 2048, prefix = [[\C\<]], suffix = [[\>]], treesitter = false }, tools = { find = nil }, ctags = { run = true, directory = vim.fn.expand('~/.vim_tags'), verbose = false, ptags = false, binary = 'ctags', args = { '--fields=+l', '--c-kinds=+p', '--c++-kinds=+p', '--sort=no' } }, ignore = { 'cfg', 'conf', 'help', 'mail', 'markdown', 'nerdtree', 'nofile', 'readdir', 'qf', 'text', 'plaintext' }, notin = { '.*String.*', '.*Comment.*', 'cIncluded', 'cCppOut2', 'cCppInElse2', 'cCppOutIf2', 'pythonDocTest', 'pythonDocTest2' } }self.languages = {  }self.syntax_groups = {  }self.highlighting = {  }self.query_cache = {  }self.ctags_handle = nil;self.find_handle = nil;self.ns_id = vim.api.nvim_create_namespace('neotags')end, __base = _base_0, __name = "Neotags" }, { __index = _base_0, __call = function(cls, ...)local _self_0 = setmetatable({  }, _base_0)cls.__init(_self_0, ...)return _self_0 end })_base_0.__class = _class_0;Neotags = _class_0 end;if not 

neotags then
neotags = Neotags()end


_module_0 = { setup = function(opts)local path = 
debug.getinfo(1).source:match('@?(.*/)')for filename in 
io.popen("ls " .. tostring(path) .. "/languages"):lines() do local lang = 
filename:gsub('%.lua$', '')
neotags.language(neotags, lang, require("neotags/languages/" .. tostring(lang)))end;return 

neotags.setup(neotags, opts)end, highlight = function()return 

neotags.run(neotags, 'highlight')end, update = function()return 
neotags.update(neotags)end, toggle = function()return 
neotags.toggle(neotags)end, language = function(lang, opts)return 
neotags.language(neotags, lang, opts)end }return _module_0;