-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

M.base46 = {
  -- changed_themes = {
  --  all = {
  --    base_16 = {
  --      base00 = 'black'
  --    } 
  --  }
  -- },
	theme = "catppuccin",
  transparency=true,
	-- hl_override = {
	-- 	Comment = { italic = true },
	-- 	["@comment"] = { italic = true },
	-- },
}


return M
