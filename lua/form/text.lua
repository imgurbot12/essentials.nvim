-- 
-- Text Input Implementation
--
local api = vim.api
local lib = require('form.field')

-- Variables

-- common match types enum
local Matches = {
  PHONE = '^%d%d%d%-%d%d%d%-%d%d%d%d$',
  EMAIL = '^[%w+%.%-_]+@[%w+%.%-_]+%.%a%a+$',
}

-- Functions

-- protect_down
--   replace traditional <Enter> behavor in insert mode and simply
--   shift down like in normal mode
--
-- @param window Window  neovim window object wrapper
-- @param field  Field   field implementation tied to keybind
local function protect_down(window, _)
  window:move_cursor(1, 0)
end

-- protect_field
--   prevent the user from ever moving the cursor over the field name
--   only allowing them access to modify the value
--
-- @param  direction int  direction modifer for protection (-1=left, 1=right)
-- @return Function       dynamically generated keybind protection function
local function protect_field(direction)
  return function(window, field)
    local pos  = window:get_cursor()
    local protected = field.name:len() + 2
    if pos[2] < protected or (direction < 0 and pos[2] == protected) then
      window:set_cursor(pos[1], protected)
    else
      window:move_cursor(0, direction)
    end
  end
end

-- dyn_highlight
--  dynamically highlight field values whenever they're updated to
--  visually mark them as valid inputs or invalid inputs
--
-- @param window   Window  nvim window object wrapper
-- @param field    Field   field object being validated and highlighted
-- @param line     string  line contents being parsed and validated
-- @param details  Tree    additonal update details like row/column
local function dyn_highlight(window, field, _, line, details)
  local col_start = field.name:len() + 2
  if not pcall(field.parse, field, line) then
    window:highlight(lib.Highlights.INVALID, details.row, col_start)
  else
    window:highlight(nil, details.row, 0)
  end
end

-- Classes

-- TextInput
--   generate a text input field with the given specifications
--
-- @param name    string  name of the text input field
-- @param options Table   additional field configuration settings
local function TextInput(name, options, validate)
  -- build important text defaults
  options = options or {}
  options.keymap = options.keymap or {}
  options.validate = validate or options.validate
  -- set on-update manager
  options.on_update = options.validate ~= nil and dyn_highlight or nil
  -- update keymap with defaults
  lib.setdefault(options.keymap, 'n', {})
  lib.setdefault(options.keymap, 'i', {})
  options.keymap['n']['<Enter>'] = protect_down
  options.keymap['n']['<Left>']  = protect_field(-1)
  options.keymap['n']['<Right>'] = protect_field(1)
  options.keymap['i']['<Enter>'] = protect_down 
  options.keymap['i']['<Left>']  = protect_field(-1)
  options.keymap['i']['<Right>'] = protect_field(1)
  -- generate field object
  return lib.Field:new(name, options)
end

-- MatchInput
--   generate a text input that has to match the given expression
--
-- @param name    string  name of text input field
-- @param match   string  expression field value must match
-- @param options Table   additional field configuration settings
local function MatchInput(name, match, options)
  return TextInput(name, options, function(v)
    return string.match(v, match) or error(string.format('invalid: %s', v))
  end)
end

-- NumberInput
--  generate a number input field with the given specifications
--
-- @param name    string  name of the text input field
-- @param options Tree    additional field configuration settings
local function NumberInput(name, options)
  return TextInput(name, options, function(v)
    return tonumber(v) or error(string.format('invalid number: %s', v))
  end)
end

-- BoolInput
--   generate a boolean input field with the given specifications
--
-- @param name    string  name of the text input field
-- @param options Tree    additional field configuration settings
local function BoolInput(name, options)
  return TextInput(name, options, function(v)
    local m = {["0"]=true, ["true"]=true, ["1"]=false, ["false"]=false}
    local b = m[v]
    if b == nil then 
      error(string.format('invalid boolean: %s', v))
    end 
    return b 
  end)
end

-- Exports

return {
  Matches     = Matches,
  TextInput   = TextInput,
  MatchInput  = MatchInput,
  NumberInput = NumberInput,
  BoolInput   = BoolInput,
}
