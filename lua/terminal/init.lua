-- 
-- ToggleTerm utilites and motion enhancements
--

local api  = vim.api
local term = require('toggleterm.terminal')

-- Variables

local last_direction = 'horizontal'

-- Functions

local function valid_dir(direction)
  if string.match(direction, "^v") then
    return "vertical"
  elseif string.match(direction, "^h") then
    return "horizontal"
  end
  error(string.format('invalid direction: "%s"', direction))
end

local function default_size(direction)
  if direction == "vertical" then
    return api.nvim_get_option("columns") / 2 - 5
  elseif direction == "horizontal" then
    return api.nvim_get_option("lines") / 3
  end
end

-- Module

local M = {}

-- new_term
--   spawn a new terminal w/ a specified launch direction
--
-- @param  options Table  options to pass into terminal creation
-- @return Terminal       terminal object created
function M.new_term(options)
  -- configure options / launch terminal
  options = options or {}
  options.direction = valid_dir(options.direction or last_direction)
  -- update configured defaults based on last entry
  last_direction = options.direction
  -- spawn terminal w/ given settings
  local size     = options.size or default_size(options.direction)
  local terminal = term.Terminal:new(options)
  terminal:open(size)
  return terminal
end

-- bind_toggle
--   create simple wrapper to allow easy bind to spawning horiz/vert terms
--
-- @param  direction string  direction to spawn terminal in when called
-- @return func              function to spawn new terminal in direction
function M.bind_toggle(direction)
  assert(direction, 'direction must be specified during bind')
  return function()
    M.new_term({direction = direction})
  end
end

-- toggle_term
--   get or create a terminal w/ the given id and toggle it
--
-- @param  id int   terminal id number
-- @return Terminal terminal object
function M.toggle_term(id)
  assert(id, 'terminal id must be specified')
  local terminal = term.get_or_create_term(id)
  terminal:toggle()
  return terminal
end

-- active_terminal
--   retrieve currently active terminal (if any)
--
-- @return Terminal?  terminal cursor is currently within (if any)
function M.active_terminal()
  for _, terminal in pairs(term.get_all()) do
    if terminal:is_focused() then
      return terminal
    end
  end
end

-- toggle_active
--   toggle terminal window cursor is currently within
function M.toggle_active()
  local terminal = M.active_terminal()
  if terminal ~= nil then
    terminal:toggle()
  end
end

-- shutdown_active
--   shutdown active terminal
function M.shutdown_active()
  local terminal = M.active_terminal()
  if terminal ~= nil then
    terminal:shutdown()
  end
end

-- toggle_all
--   intelligently toggle all existing terminal instances
function M.toggle_all()
  api.nvim_command('ToggleTermToggleAll')
end

-- shutdown_all
--   close and shutdown all existing terminal sessions
function M.shutdown_all()
  for _, terminal in pairs(term.get_all()) do
    terminal:shutdown()
  end
end

-- Export

return M 
