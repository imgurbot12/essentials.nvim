--
-- Button Input Implementation
--
local api = vim.api
local lib = require('form.field')

-- Function

local function render(field, lines)
  table.insert(lines, string.format('<%s>', field.name))
end

local function press(options)
  return function(_, _)
    if options.on_press ~= nil then
      options.on_press()
    end
  end
end

local function validate(options)
  return function(_)
    return options.value or true
  end
end

-- Classes

-- Button
--   generate a generic button input field with the given specificiations
--
-- @param name    string  name of the button input
-- @param options Table   additional field configuration settings
local function Button(name, options)
  -- build important button defaults
  options = options or {}
  options.render = options.render or render
  options.keymap = options.keymap or {}
  options.validate = options.validate or validate(options)
  -- update keymap with defaults
  lib.setdefault(options.keymap, 'n', {})
  lib.setdefault(options.keymap, 'i', {})
  options.keymap['n']['<Enter>'] = press(options)
  options.keymap['i']['<Enter>'] = press(options)
  -- generate field object and apply attrs
  return lib.Field:new(name, options)
end

-- Export

return Button
