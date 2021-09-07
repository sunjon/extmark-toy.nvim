local api = vim.api

local utils = require "extmark-toy.utils"

local function rgb_split(hex_color)
  return {
    r = tonumber("0x" .. hex_color:sub(1, 2)),
    g = tonumber("0x" .. hex_color:sub(3, 4)),
    b = tonumber("0x" .. hex_color:sub(5, 6)),
  }
end

local function lerp_color_gradient(color_1, color_2, interp)
  local floor = math.floor
  local lerp = utils.lerp

  local color_1_rgb = rgb_split(color_1:sub(2, -1))
  local color_2_rgb = rgb_split(color_2:sub(2, -1))

  local r = floor(lerp(color_1_rgb.r, color_2_rgb.r, interp))
  local g = floor(lerp(color_1_rgb.g, color_2_rgb.g, interp))
  local b = floor(lerp(color_1_rgb.b, color_2_rgb.b, interp))

  return ("#%02x%02x%02x"):format(r, g, b)
end

local M = {}

M.create_highlight_group_map = function(color_name, palette, max_brightness)
  -- get the user set background color
  local bg_val = api.nvim_get_hl_by_name("Normal", true).background
  local user_background = ("#%06x"):format(bg_val)

  --
  local hl_groups = {}
  hl_groups.fg = {}
  hl_groups.bg = {}
  local group_name, color_hexstr
  for color_idx, base_color_hexstr in ipairs(palette) do
    base_color_hexstr = (base_color_hexstr == "background") and user_background or base_color_hexstr

    for _, attr in pairs { "fg", "bg" } do
      hl_groups[attr][color_idx] = {}
      for brightness_level = 1, max_brightness do
        color_hexstr = lerp_color_gradient(user_background, base_color_hexstr, (1/ max_brightness) * brightness_level)

        group_name = ("Logo_%s_%s%d_%d"):format(attr, color_name, color_idx, brightness_level)
        vim.cmd(("hi! %s gui%s=%s"):format(group_name, attr, color_hexstr))

        -- store the hl id
        hl_groups[attr][color_idx][brightness_level] = vim.api.nvim_get_hl_id_by_name(group_name)
      end
    end
  end

  return hl_groups
end

return M
