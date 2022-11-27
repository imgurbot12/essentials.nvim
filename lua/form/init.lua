--
-- Overly Complicated Neovim Popup Form Library
--

local form   = require('form.form')
local field  = require('form.field')
local text   = require('form.text')
local button = require('form.button')

return {
  input = {
    text   = text.TextInput,
    match  = text.MatchInput,
    number = text.NumberInput,
    bool   = text.BoolInput,
    button = button,
  },
  Matchers   = text.Matches,
  Field      = field.Field,
  Form       = form,
}
