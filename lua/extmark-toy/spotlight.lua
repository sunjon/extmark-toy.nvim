local api = vim.api

local colors = require "extmark-toy.colors"
local utils = require "extmark-toy.utils"
local io = require "extmark-toy.file_io"

local MAX_BRIGHTNESS = 32

local KEY_LEFT = vim.api.nvim_replace_termcodes("<Left>", true, false, true)
local KEY_RIGHT = vim.api.nvim_replace_termcodes("<Right>", true, false, true)

local PALETTE_DATA = {
  ["red"] = { [1] = "#1A1A1A", [2] = "#440402", [3] = "#AA3011", [4] = "#88260D", [5] = "#E44016" },
  ["blue"] = { [1] = "#1A1A1A", [2] = "#0E1C4B", [3] = "#002290", [4] = "#001B73", [5] = "#0033D9" },
  ["white"] = { [1] = "#1A1A1A", [2] = "#2F2F2F", [3] = "#BDBEB0", [4] = "#9B9C87", [5] = "#CACBBF" },
}

local COLOR_REVERSE_LUT = { ["blue"] = 1, ["white"] = 2, ["red"] = 3 }
local COLOR_LUT = { [1] = "blue", [2] = "white", [3] = "red" }

--

local function distance(x1, y1, x2, y2)
  local sqrt = math.sqrt
  return sqrt(((x1 - x2) ^ 2) + ((y1 - y2) ^ 2))
end

local M = {}

M.context = {}

local function keystroke_callback(key)
  -- rotate through available palettes
  local switch = {
    [KEY_LEFT] = -1,
    [KEY_RIGHT] = 1,
  }
  local palette_offset = switch[key]
  if not palette_offset then
    return
  end

  local new_color_idx = M.context.active_color_idx + palette_offset

  if new_color_idx < 1 then
    new_color_idx = #COLOR_LUT
  end

  if new_color_idx > #COLOR_LUT then
    new_color_idx = 1
  end
  -- print(key ..":" .. new_color_idx)

  M.context.color_changed = true
  M.context.active_color_idx = new_color_idx
  M.context.active_color = COLOR_LUT[new_color_idx]
end

M.init = function(opts)
  local context = M.context
  opts = opts or {}

  context.nsid = vim.api.nvim_create_namespace "LogoSpotlightEffect"

  -- create hl_groups
  -- -----------------
  context.active_color = opts.logo_color or "red"
  context.active_color_idx = COLOR_REVERSE_LUT[context.active_color]
  -- print("---" .. context.active_color_idx)

  context.hl_groups = {}
  for color_name, palette in pairs(PALETTE_DATA) do
    context.hl_groups[color_name] = colors.create_highlight_group_map(color_name, palette, MAX_BRIGHTNESS)
  end

  -- import logo data
  -- -----------------
  local file = "logo_encoded.bin"
  local plugin_dir = vim.g.extmark_toy_plugin_dir
  local filepath = plugin_dir .. file
  local deserialized_data = io.import_datafile(filepath)
  if not deserialized_data then
    error("Error: unable to load logo data: " .. filepath)
    return
  end

  local ascii_lines = io.decode_datafile(deserialized_data)

  -- setup floating window
  -- -----------------
  vim.cmd [[ hi! LogoMask guibg=background blend=15 ]]
  context.mask_hlid = vim.api.nvim_get_hl_id_by_name "LogoMask"

  -- indent so logo is centered in window
  local rows, columns = vim.o.lines, vim.o.columns
  context.indent = {
    column = math.floor((columns - 104) / 2),
    row = math.floor((rows - 40) / 2),
  }

  context.floatwin = utils.create_window(columns, rows, 0, 0)

  utils.fill_buffer(context.floatwin.bufid, columns, rows, " ")
  api.nvim_win_set_option(context.floatwin.winid, "winblend", 3)

  -- register color change key
  M.nsid = vim.on_key(keystroke_callback, context.nsid)

  -- create exmarks and create map of objects, each extmark_obj containing a reference to the extmarkID, ascii character, it's position and brightness
  -- -----------------

  local default_fg = 2
  local default_bg = 1

  local fg_hlid, bg_hlid
  local extmark_opts, extmark_id, is_filled_cell

  local screen_row, screen_col
  context.extmarks = {}
  for row_idx, row_data in ipairs(ascii_lines) do
    for col_idx, cell in ipairs(row_data) do
      is_filled_cell = not (cell.char == " " and cell.fg == default_fg and cell.bg == default_bg)
      if is_filled_cell then
        fg_hlid = context.hl_groups[context.active_color].fg[cell.fg][cell.brightness]
        bg_hlid = context.hl_groups[context.active_color].bg[cell.bg][cell.brightness]
      else
        fg_hlid = context.mask_hlid
        bg_hlid = context.mask_hlid
      end
      extmark_opts = {
        virt_text = { { cell.char, { fg_hlid, bg_hlid } } },
        virt_text_pos = "overlay",
      }

      screen_row = context.indent.row + row_idx - 1
      screen_col = context.indent.column + col_idx - 1

      --
      extmark_id = api.nvim_buf_set_extmark(context.floatwin.bufid, context.nsid, screen_row, screen_col, extmark_opts)

      if is_filled_cell then -- don't store mask extmarks
        context.extmarks[#context.extmarks + 1] = {
          id = extmark_id,
          char = cell.char,
          row = screen_row,
          column = screen_col,
          fg_color_idx = cell.fg,
          bg_color_idx = cell.bg,
          brightness = cell.brightness,
        }
      end
    end
  end
end

local function apply_lights(context, light_pos)
  local buf_set_extmark = vim.schedule_wrap(api.nvim_buf_set_extmark)
  local floor = math.floor

  local distance_from_light, new_brightness, extmark_opts
  local fg_hlid, bg_hlid
  local color_name = context.active_color

  local LIGHT_WIDTH = 64

  for _, em in ipairs(context.extmarks) do
    distance_from_light = floor(distance(em.column, em.row * 2, light_pos.x, light_pos.y))

    new_brightness = MAX_BRIGHTNESS - distance_from_light + LIGHT_WIDTH
    new_brightness = (new_brightness > MAX_BRIGHTNESS) and MAX_BRIGHTNESS or new_brightness
    new_brightness = (new_brightness < 1) and 1 or new_brightness

    -- update extmark if changed
    if (new_brightness ~= em.brightness) or M.context.color_changed or M.context.fade_timer then
      -- update brighness
      em.brightness = new_brightness
      fg_hlid = context.hl_groups[color_name].fg[em.fg_color_idx][em.brightness]
      bg_hlid = context.hl_groups[color_name].bg[em.bg_color_idx][em.brightness]

      extmark_opts = {
        id = em.id,
        virt_text = { { em.char, { fg_hlid, bg_hlid } } },
        virt_text_pos = "overlay",
      }

      buf_set_extmark(context.floatwin.bufid, context.nsid, em.row, em.column, extmark_opts)
    end
  end
  M.context.color_changed = false
end

M.effect_coroutine = function()
  local context = M.context
  local floor, cos, sin = math.floor, math.cos, math.sin
  local get_time = utils.get_time

  local delta_time
  local elapsed = 0
  local time_now = get_time()
  local time_last_frame = time_now

  local light_pos = {
    x = 50,
    y = 50,
  }

  while true do
    -- update delta time
    time_now = get_time()
    delta_time = time_now - time_last_frame
    time_last_frame = time_now

    -- clamp delta time
    if delta_time > 0.05 then
      delta_time = 0.05
    end

    elapsed = elapsed + delta_time

    -- update light positions
    light_pos.x = 45 + floor(sin(elapsed) + sin(elapsed * 0.5) * 50)
    light_pos.y = 25 + floor(cos(elapsed * 0.8) * 75)
    apply_lights(context, light_pos)

    coroutine.yield()
  end
end

-- cleanup effect specific stuff
M.on_close = function()
  -- unregister key callback
  vim.on_key(function () end, M.context.nsid)
  -- clear extmarks
  api.nvim_buf_clear_namespace(M.context.floatwin.bufid, M.context.nsid, 0, -1)
  -- remove logo buffer and its floating window
  api.nvim_buf_delete(M.context.floatwin.bufid, { force = true })
  -- delete chessboard buffer here to avoid "cannot close because only floating window would remain" error
  vim.cmd[[bd!]]
end

return M
