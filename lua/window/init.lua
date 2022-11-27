-- Floating Window Utility

local api   = vim.api
local Cache = require('window.cache')

-- Functions

local function window_opts(options)
  local w = api.nvim_get_option("columns")
  local h = api.nvim_get_option("lines")
  options          = options or {}
  options.perw     = options.perw   or 0.5
  options.perh     = options.perh   or 0.4
  options.width    = options.width  or math.ceil(w * options.perw)
  options.height   = options.height or math.ceil(h * options.perh - 4)
  options.col      = options.col    or math.ceil((w - options.width) / 2)
  options.row      = options.row    or math.ceil((h - options.height) / 2 - 1)
  return {
    style    = options.style    or 'minimal',
    relative = options.relative or 'editor',
    row      = options.row,
    col      = options.col,
    width    = options.width,
    height   = options.height,
  }
end

local function border_opts(options)
  return {
    style    = 'minimal',
    relative = 'editor',
    row      = options.row    - 1,
    col      = options.col    - 1,
    width    = options.width  + 2,
    height   = options.height + 2,
  }
end

local function apply_border(options)
  -- define border items
  local top = '╭' .. string.rep('─', options.width) .. '╮'
  local mid = '│' .. string.rep(' ', options.width) .. '│'
  local bot = '╰' .. string.rep('─', options.width) .. '╯'
  -- generate border from defined lines
  local lines = { top, bot }
  for _=1, options.height do
    table.insert(lines, 2, mid)
  end
  -- update options for border window
  local opts = border_opts(options)
  -- write to buffer and spawn window
  local buf = api.nvim_create_buf(false, true)
  local win = api.nvim_open_win(buf, true, opts)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return { window = win, buffer = buf }
end

local function cache_func(cache, mode, bind, func)
  -- update bind to escape brackets before generating cache entry
  bind = bind:gsub("<", "\\<"):gsub(">", "\\>")
  cache[mode..bind] = func
  cache:save()
  -- generate lua command to call upon cached function
  bind = bind:gsub("<", "\\<"):gsub(">", "\\>")
  return string.format("<cmd>lua vim.api.nvim_get_var('%s')['%s']()<cr>", cache.name, mode..bind)
end

local function add_highlight(bufn, hl_group, hi_ns, row, col_start, col_end)
  col_end   = col_end   or -1
  col_start = col_start or 0 
  if hl_group == nil then
    api.nvim_buf_clear_namespace(bufn, hi_ns, col_start, col_end)
  else
    api.nvim_buf_add_highlight(bufn, hi_ns, hl_group, row, col_start, col_end)
  end
end

-- Classes

local Window = {}

-- Window:new
--   generate a new neovim window with the given settings
--
-- @param options Table  dynamic set of window configuration options
-- @return Window 
function Window:new(options)
  assert(options.name, 'window name must be specified in options')
  -- build self
  local o = {}
  setmetatable(o, self)
  self.__index = self
  -- generate base window buffer
  o.name = options.name
  o.bufn = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(o.bufn, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(o.bufn, 'filetype', options.name)
  -- build options for window and generate border (if enabled)
  local winopts = window_opts(options)
  o.border = options.border == true and apply_border(winopts) or nil
  -- generate window and apply border auto-close if not nil
  o.win = api.nvim_open_win(o.bufn, true, winopts) 
  if o.border then
    local cmd = 'au BufWipeout <buffer> exe "silent bwipeout! "'..o.border.buffer
    api.nvim_command(cmd)
  end
  api.nvim_win_set_option(o.win, 'cursorline', true)
  api.nvim_buf_add_highlight(o.bufn, -1, 'DapCppHeader', 0, 0, -1)
  -- add additional attributes
  o.wopts = winopts
  o.cache = Cache:new(string.format('window_%s_keymap', o.name))
  -- return generated window object
  return o
end

-- Window:lock
--   prevent window buffer from being modified
function Window:lock()
  api.nvim_buf_set_option(self.bufn, 'modifiable', false)
end

-- Window:unlock
--   enable window buffer the ability to be modified
function Window:unlock()
  api.nvim_buf_set_option(self.bufn, 'modifiable', true)
end

-- Window:keymap
--   apply keybinds to the window object with the given settings
--
-- @param mode    string  nvim modal mode (n/i/v/etc...)
-- @param binds   Table   map of keybind -> function
-- @param options Table   misc options when configuring binds
function Window:keymap(mode, binds, options)
  assert(mode,  'keybind mode must be specified')
  assert(binds, 'keybind bindmap must not be empty')
  -- configure options
  options = options or {}
  options.nowait  = options.nowait  or true
  options.noremap = options.noremap or true
  options.silent  = options.silent  or true
  -- configure keybind cache for lua functions
  local cmd
  for bind, op in pairs(binds) do
    cmd = type(op) ~= "string" and cache_func(self.cache, mode, bind, op) or op
    api.nvim_buf_set_keymap(self.bufn, mode, bind, cmd, options)
  end
end

-- Window:on_update
--   bind misc update objects according to nvim_buf_attach specs
--
-- @param options Table  options to configure buffer attachment callbacks
function Window:on_update(options)
  assert(options, 'on_update function options must be specified')
  api.nvim_buf_attach(self.bufn, false, options)
end

-- Window:writelines
--   write list of lines to buffer
--
-- @param lines Table  list of lines to write to buffer
function Window:writelines(lines)
  assert(lines, 'lines must be specified during write')
  api.nvim_buf_set_lines(self.bufn, 0, -1, false, lines)
end

-- Window:readlines
--   read current content of buffer as series of lines
--
-- @return Table
function Window:readlines()
  return api.nvim_buf_get_lines(self.bufn, 0, -1, false)
end

-- Window:get_cursor
--   retrieve current cursor position when window is active
--
-- @return Table  {row, col}
function Window:get_cursor()
  return api.nvim_win_get_cursor(self.win)
end

-- Window:set_cursor
--   set absolute position of cursor in window
--
-- @param row  absolute row position number [0-x]
-- @param col  aboslute column position number [0-x]
function Window:set_cursor(row, col)
  assert(row, 'row number must be specified')
  assert(col, 'col number must be specified')
  api.nvim_win_set_cursor(self.win, { row, col })
end

-- Window:move_cursor
--   set new relative position for cursor in window
--
-- @param row  number of rows to move from current position
-- @param col  number of columns to move from current position
function Window:move_cursor(row, col)
  assert(row, 'row number must be specified')
  assert(col, 'col number must be specified')
  local height = self.wopts.height
  local width  = self.wopts.width
  local cursor = self:get_cursor()
  cursor       = { cursor[1] + (row or 0), cursor[2] + (col or 0) }
  cursor       = { math.min(cursor[1], height), math.min(cursor[2], width) }
  self:set_cursor(cursor[1], cursor[2])
end

-- Window:highlight
--   add a new color highlight group to the given row/column-start/column-end
--
-- @param hl_group   name of existing color-group to add at specification
-- @param row        given row number to add highlight to
-- @param col_start  optional start column for highlight
-- @param col_end    optional end column for highlight
function Window:highlight(hl_group, row, col_start, col_end)
  assert(row, 'highlight row must be specified')
  -- generate highlight namespace if it doesn't already exist
  self.hi_name = string.format('%s_hi', self.name)
  self.hi_ns   = self.hi_ns or api.nvim_create_namespace(self.hi_name)
  -- apply highlight group to specification
  -- local function add_highlight(bufn, hl_group, hi_ns, row, col_start, col_end)
  add_highlight(self.bufn, hl_group, self.hi_ns, row, col_start, col_end)
end

-- Window:set_border_color
--   update border color to use a given highlight group
--
-- @param hl_group  name of existing color-group to set border color
function Window:set_border_color(hl_group)
  -- skip if border isn't configured
  local border = self.border
  if border == nil then
    return
  end
  -- configure highlight over all of border
  border.hi_name = string.format("%s_hi_border", self.name)
  border.hi_ns   = border.hi_ns or api.nvim_create_namespace(border.hi_name)
  -- apply highlight group to specification
  local width = api.nvim_win_get_height(border.window)
  for row=0,width do
    add_highlight(border.buffer, hl_group, border.hi_ns, row)
  end
end

-- Window:update_opts
--   override and update window option settings
--
-- @param options Table  window options configuration
function Window:update_opts(options)
  assert(options, 'window options must be supplied')
  -- update base window
  self.wopts = window_opts(options)
  api.nvim_win_set_config(self.win, self.wopts)
  -- update border if needed
  if self.border ~= nil then
    local opts = border_opts(self.wopts)
    api.nvim_win_set_config(self.border.window, opts)
  end
end

-- Window:move
--  move the current floating window by a given row/column modifier
--
-- @param row int  row modifier to move window
-- @param col int  colum modifier to move window
function Window:move(row, col)
  assert(row, 'row move modifer must be specified')
  assert(col, 'col move modifier must be specified')
  self.wopts.row = self.wopts.row + row
  self.wopts.col = self.wopts.col + col
  self:update_opts(self.wopts)
end

-- Window:shake
--   force the window to shake a given number of times
--
-- @param shakes int   optional number of times window will shake (default=1)
-- @param after  func  optional function to run after last runtime
function Window:shake(shakes, after)
  shakes = (shakes or 1) * 3
  for i=0,shakes do
    vim.defer_fn(function()
      -- do shaking action
      local mod = i % 2 == 0 and 1 or -1
      self:move(0, mod)
      -- run function on completion if set
      if after ~= nil and i == shakes then
        after()
      end
    end, i*100)
  end
end

-- Window:close
--   close the window object and all related subobjects
--
-- @param force boolean  force window to close if true or nil
function Window:close(force)
  force = force or true
  pcall(api.nvim_win_close, self.win, force)
  if self.border then
    pcall(api.nvim_win_close, self.border.win, force)
  end
end

-- Export

return Window
