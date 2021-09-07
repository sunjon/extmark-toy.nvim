local util = require "extmark-toy.utils"
local colors = require "extmark-toy.colors"
local api = vim.api

local gradient = {
  "  ",
  "▁▁",
  "▂▂",
  "▃▃",
  "▄▄",
  "▅▅",
  "▆▆",
  "▇▇",
  "██",
  "🮆🮆",
  "🮅🮅",
  "🮄🮄",
  "▀▀",
  "🮃🮃",
  "🮂🮂",
  "▔▔",
}

local DISPLAY_HEIGHT = 22
local DISPLAY_FADE_HEIGHT = 10

local function generate_virt_text(y, rep_count)
  local offset_top = (y % 16) + 1
  local offset_bot = ((offset_top + 8) % 16)
  offset_bot = offset_bot == 0 and 1 or offset_bot

  local char_top = gradient[offset_top]
  local char_bot = gradient[offset_bot]

  return {
    (char_top .. char_bot):rep(rep_count),
    (char_bot .. char_top):rep(rep_count),
  }
end

local M = {}

M.context = {}

M.init = function(opts)
  opts = opts or {}
  local context = M.context

  -- setup logo background buffer
  context.nsid = vim.api.nvim_create_namespace "ChessboardEffect"

  context.bufid = api.nvim_create_buf(false, true)
  util.fill_buffer(context.bufid, 102, DISPLAY_HEIGHT + 8, " ")
  api.nvim_set_current_buf(M.context.bufid)
  vim.cmd [[ hi! LogoDefault blend=4 ]]
  local winid = api.nvim_get_current_win()
  api.nvim_win_set_option(winid, "winhighlight", "Normal:LogoDefault")

  -- generate animation frame LUT
  local win_width = vim.fn.winwidth(0)

  context.animation_frames = {}
  local repeat_block = math.floor(win_width / 4)
  for i = 0, 15 do
    local rows = generate_virt_text(i, repeat_block)
    context.animation_frames[i + 1] = { rows[1], rows[2] }
  end

  -- create palette
  local board_color = { "#888888" }
  context.hl_group = colors.create_highlight_group_map("Chessboard", board_color, DISPLAY_FADE_HEIGHT).fg[1]
  -- print(vim.inspect(context.hl_group))

  --  setup exmarks for chessboard
  context.extmarks = {}
  for line = 1, DISPLAY_HEIGHT do
    context.extmarks[line] = api.nvim_buf_set_extmark(context.bufid, context.nsid, 0 + 8, 0, {})
  end
end

local function set_extmark(row, virt_text)
  local context = M.context
  local row_color_id
  if row <= 8 then
    row_color_id = context.hl_group[row]
  elseif row >= DISPLAY_HEIGHT - DISPLAY_FADE_HEIGHT + 1 then
    row_color_id = context.hl_group[(DISPLAY_HEIGHT - row + 1)]
  else
    row_color_id = context.hl_group[DISPLAY_FADE_HEIGHT]
  end

  local opts = {
    id = context.extmarks[row],
    virt_text = { { virt_text, row_color_id } },
    virt_text_pos = "overlay",
  }

  local buf_set_extmark = vim.schedule_wrap(api.nvim_buf_set_extmark)
  buf_set_extmark(context.bufid, context.nsid, row - 1 + 6, 0, opts)
end

M.effect_coroutine = function()
  local floor, sin = math.floor, math.sin
  local anim_frames = M.context.animation_frames

  local get_time = util.get_time
  local delta_time
  local elapsed = 0
  local time_now = get_time()
  local time_last_frame = time_now

  local frame_num, row_strings
  local height = 0
  local last_frame_num

  while true do
    time_now = get_time()
    delta_time = time_now - time_last_frame
    time_last_frame = time_now

    -- clamp delta time
    if delta_time > 0.05 then
      delta_time = 0.05
    end
    elapsed = elapsed + delta_time

    height = floor(sin(elapsed * 0.6) * 128)
    frame_num = (height % 16) + 1
    if frame_num ~= last_frame_num then
      row_strings = anim_frames[frame_num]

      -- draw to screen
      for row = 1, DISPLAY_HEIGHT, #row_strings do
        for i = 1, #row_strings do
          set_extmark(row + i - 1, row_strings[i])
        end
      end

      last_frame_num = frame_num
    end

    coroutine.yield()
  end
end

M.on_close = function()
  api.nvim_buf_clear_namespace(M.context.bufid, M.context.nsid, 0, -1)
  -- api.nvim_buf_delete(M.context.bufid, { force = true })
end

return M
