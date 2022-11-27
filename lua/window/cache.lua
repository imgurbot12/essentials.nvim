-- Simple Cache utility

local api = vim.api

-- Functions

local function get_var(name)
  local value
  pcall(function() 
    value = api.nvim_get_var(name)
  end)
  return value
end

-- Classes

local Cache = { name = nil }

function Cache:new(name, cache)
  assert(name, 'name of cache must be specified')
  -- build self
  local o = cache or get_var(name) or {}
  setmetatable(o, self)
  self.__index = self
  self.name = name
  return o
end

function Cache:load()
  local cache = get_var(self.name)
  if cache then
    return Cache:new(self.name, cache)
  end
  return self
end

function Cache:save()
  api.nvim_set_var(self.name, self)
end

function Cache:delete()
  pcall(api.nvim_del_var, self.name)
  return self
end

-- Export

return Cache
