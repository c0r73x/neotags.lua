local Utils
do
  local _class_0
  local _base_0 = {
    contains = function(list, el)
      for _, value in pairs(list) do
        if value == el then
          return true
        end
      end
      return false
    end,
    concat = function(a, b)
      if not b then
        return a
      end
      if not a then
        return b
      end
      local result = {
        unpack(a)
      }
      table.move(b, 1, #b, #result + 1, result)
      return result
    end,
    explode = function(div, str)
      if div == '' then
        return false
      end
      local pos, arr = 0, { }
      for st, sp in function()
        return string.find(str, div, pos, true)
      end do
        table.insert(arr, string.sub(str, pos, st - 1))
        pos = sp + 1
      end
      return arr
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "Utils"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Utils = _class_0
end
return Utils
