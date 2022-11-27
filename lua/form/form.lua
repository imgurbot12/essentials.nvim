-- FORM Implementation

--TODO: should the form object be directly linked with
-- a static window assignment? probably yeah

--TODO: allow keepfocus/dismiss option
-- for what happens when user unfocuses off the form window

local api    = vim.api
local window = require('window')
local button = require('form.button')

-- Functions

-- submit_button
--   generate a submit-button for the given form object
local function submit_button(form)
  return button('submit', {
    on_press = function()
      form:submit()
    end
  })
end

-- on_update
--   generate on-update function for a given form/window
--
-- @param form   Form    form object function is generated for
-- @param window Window  nvim window object wrapper function is generated for
local function on_update(form, win)
  return function(_, buf, _, row, col)
    local line = win:readlines()[row + 1]
    for _, field in pairs(form.fields) do
      if field.on_update and field:is_active({row + 1, col}) then
        field.on_update(win, field, buf, line, { row = row, col = col })
      end
    end
  end
end

-- keybind
--   generate form keybind function to active only relevant fields
--
-- @param win    Window  window object
-- @param fields Table   list of field objects
-- @param mode   string  keybind mode
-- @param key    string  keybind string
local function keybind(win, fields, mode, key)
  return function()
    local cursor = win:get_cursor()
    for _, f in pairs(fields) do
      local keys = f.keymap[mode]
      if keys ~= nil then
        local func = keys[key]
        if func and f:is_active(cursor) then
          func(win, f)
        end
      end
    end
  end
end

-- form_apply_keymap
--   apply relevant field keymap entries to the given window object
--
-- @param form Form    form object
-- @param win  Window  nvim window object wrapper
local function form_apply_keymap(form, win)
  assert(form, 'form object must be supplied')
  assert(win,  'win object must be supplied')
  -- build functions to call the relevant field functions for keymap
  local keymap = {i = {}, n = {}}
  for _, field in pairs(form.fields) do
    for mode, keys in pairs(field.keymap) do
      if not keymap[mode] then 
        keymap[mode] = {} 
      end
      for key in pairs(keys) do
        keymap[mode][key] = keybind(win, form.fields, mode, key)
      end
    end
  end
  -- assign global updates tracker
  win:on_update({on_bytes = on_update(form, win)})
  -- assign generated keymap
  for mode, binds in pairs(keymap) do
    win:keymap(mode, binds)
  end
end

-- form_render
--   render form content as lines inside a given window
--
-- @param win Window  nvim window object wrapper
local function form_render(form, win)
  local lines = {}
  for _, field in ipairs(form.fields) do
    field:render(lines)
  end
  win:writelines(lines)
end

-- field_parse
--  pass valid and parsed field-value into values table
--
-- @param field  Field   field object
-- @param line   string  line string being parsed
-- @param values Table   table to insert valid parsed value
local function field_parse(field, line, values)
  values[field.name] = field:parse(line)
end

-- Classes

local Form = {}

-- Form:new
--   generate a new form object with a collection of fields
--
-- @param  name    string       name of form object and associated window
-- @param  fields  List[Field]  list of fields to include in the form
-- @param  options Table        form configuration options
-- @param  winops  Table        window specification options
-- @return Form                 newly generated form object
function Form:new(name, fields, options, winops)
  assert(name,   'form name must be declared')
  assert(fields, 'form fields must be declared')
  -- build base object
  local o = {}
  setmetatable(o, self)
  self.__index = self
  -- modify fields
  options = options or {}
  if not options.no_submit then
    options.submit_button = options.submit_button or submit_button(o)
    table.insert(fields, options.submit_button)
  end
  for i, field in pairs(fields) do
    field.pos = { i, 0 }
  end
  -- update winopts
  winops = winops or {}
  winops.name   = name
  winops.width  = winops.width or 20
  winops.height = winops.height or #fields
  winops.border = winops.border or true
  -- apply fields
  options = options or {}
  o.name      = name
  o.fields    = fields
  o.winops    = winops
  o.window    = nil
  o.values    = nil
  o.on_submit = options.on_submit
  -- return generated form object
  return o
end

-- Form:open
--   open the form in a new window object
function Form:open()
  -- skip if already open
  if self.window ~= nil then
    return
  end
  -- reset form values on new form launch
  self.values = nil
  -- launch new window w/ confgiured winops
  self.window = window:new(self.winops)
  -- configure and render to launched window
  self.window:keymap('n', { 
    ["<Esc>"] = function() self:close() end,
  })
  form_render(self, self.window)
  form_apply_keymap(self, self.window)
end

-- Form:close
--   close the form and it's associated window
function Form:close()
  if self.window == nil then
    return
  end
  self.window:close()
  self.window = nil
end

-- Form:invalid
--   animate window when submission fails
function Form:invalid()
  if self.window == nil then
    return
  end
  self.window:set_border_color('FormInvalid')
  self.window:shake(1, function()
    self.window:set_border_color(nil)
  end)
end

-- Form:submit
--  parse and validate field inputs and return values if validated
function Form:submit()
  -- cannot submit if window is closed
  if self.window == nil then
    return
  end
  -- attempt to parse and validate inputs
  local lines  = self.window:readlines()
  local values = {}
  for i=0,#lines do
    local pos  = { i, 0}
    local line = lines[i]
    for _, field in pairs(self.fields) do
      if field:is_active(pos) then
        if not pcall(field_parse, field, line, values) then
          self:invalid()
          return nil
        end
      end
    end
  end
  -- call field on-submit functions
  for _, field in pairs(self.fields) do
    if field.on_submit ~= nil then
      field.on_submit(values[field.name])
    end
  end
  -- call form on-submit function
  if self.on_submit ~= nil then
    self.on_submit(values)
  end
  -- close window on a success
  self:close()
  -- return collection of final values if form succeeded
  self.values = values
  return values
end

-- Init

api.nvim_command([[highlight FormInvalid ctermbg=0 guifg=red]])
api.nvim_command([[highlight FormValid   ctermbg=0 guifg=green]])

-- Export

return Form
