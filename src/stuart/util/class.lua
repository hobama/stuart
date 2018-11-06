local classes = {}
local isofclass = {}
local ctypes = {}

local M = {}

-- create a constructor table
local function constructortbl(metatable)
  local ct = {}
  setmetatable(ct, {
    __index=metatable,
    __newindex=metatable,
    __metatable=metatable,
    __call=function(self, ...) return self.new(...) end
  })
  return ct
end

function M.new(name, parentname, ctype)
  local class = {__typename = name}
  assert(not classes[name], string.format('class <%s> already exists', name))
  if ctype then
    local ctype_id = tonumber(ctype)
    assert(ctype_id, 'invalid ffi ctype')
    assert(not ctypes[ctype_id], string.format('ctype <%s> already considered as <%s>', tostring(ctype), ctypes[ctype_id]))
    ctypes[ctype_id] = name
  end

  class.__index = class
  
  class.__factory = function()
    local self = {}
    setmetatable(self, class)
    return self
  end

  class.__init = function() end

  class.new = function(...)
    local self = class.__factory()
    self:__init(...)
    return self
  end

  classes[name] = class
  isofclass[name] = {[name]=true}

  if parentname then
    local parent = classes[parentname]
    assert(parent, string.format('parent class <%s> does not exist', parentname))
    setmetatable(class, parent)

    -- consider as type of parent
    while parent do
      isofclass[parent.__typename][name] = true
      parent = getmetatable(parent)
    end

    return constructortbl(class), classes[parentname]
  else
    return constructortbl(class)
  end
end

function M.factory(name)
  local class = classes[name]
  assert(class, string.format('unknown class <%s>', name))
  return class.__factory()
end

function M.metatable(name)
  return classes[name]
end

function M.type(obj)
   local tname = type(obj)

   local objname
   --if tname == 'cdata' then
   --  objname = ctypes[tonumber(ffi.typeof(obj))]
   -- elseif
   if tname == 'userdata' or tname == 'table' then
      local mt = getmetatable(obj)
      if mt then
         objname = rawget(mt, '__typename')
      end
   end

   if objname then
      return objname
   else
      return tname
   end
end

function M.istype(obj, typename)
  local tname = type(obj)
  local objname
  --if tname == 'cdata' then
  --  objname = ctypes[tonumber(ffi.typeof(obj))]
  --elseif
  if tname == 'userdata' or tname == 'table' then
    local mt = getmetatable(obj)
    if mt then
      objname = rawget(mt, '__typename')
    end
  end

  if objname then -- we are now sure it is one of our object
    local valid = rawget(isofclass, typename)
    if valid then
      return rawget(valid, objname) or false
    else
      return objname == typename -- it might be some other type system
    end
  else
    return tname == typename
  end
end

-- allow class() instead of class.new()
setmetatable(M, {__call=function(self, ...) return self.new(...) end})

return M