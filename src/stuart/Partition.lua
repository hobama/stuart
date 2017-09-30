local class = require 'middleclass'
local moses = require 'moses'

local Partition = class('Partition')

function Partition:initialize(data, index)
  self.data = data or {}
  self.index = index or 0
end

function Partition:_count()
  return #self.data
end

function Partition:_flatten()
  self.data = moses.flatten(self.data)
  return self
end

function Partition:_flattenValues()
  self.data = moses.reduce(self.data, function(r, e)
    local x = e[2]
    if moses.isString(x) then
      t = {}
      x:gsub('.', function(c) t[#t+1] = c end)
      x = t
    end
    moses.map(x, function(i, v)
      table.insert(r, {e[1], v})
    end)
    return r
  end, {})
  return self
end

function Partition:_toLocalIterator()
  local i = 0
  return function()
    i = i + 1
    if i <= #self.data then
      return self.data[i]
    end
  end
end

return Partition