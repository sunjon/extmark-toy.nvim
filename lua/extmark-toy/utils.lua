local api = vim.api

local M = {}

function M.get_time()
  local uv = vim.loop
  return uv.now() / 1000
end

-- function M.lerp(a, b, interp)
--   return a + (b - a) * interp
-- end

function M.lerp(v0, v1, t)
  return v0 * (1 - t) + v1 * t
end

function M.fill_buffer(bufid, width, height, fill_char)
  local filled_lines = {}
  local fill_str = (fill_char):rep(width)
  for i = 1, height do
    filled_lines[i] = fill_str
  end

  api.nvim_buf_set_lines(bufid, 0, height, false, filled_lines)
end

function M.create_window(width, height, row, col)
  -- print ("!! " .. col)

  local opts = {
    relative = "editor", -- TODO: make this relative to window
    style = "minimal",
    focusable = false,
    row = row,
    col = col,
    width = width,
    height = height,
  }

  local bufid = api.nvim_create_buf(false, true)
  api.nvim_buf_set_keymap(
    bufid,
    "n",
    "q",
    "<Cmd>lua require'extmark-toy'.stop()<CR>",
    { noremap = true, silent = true }
  )

  local winid = api.nvim_open_win(bufid, true, opts) -- enter window = true to set bufferlocal autocommands

  local HIDE_CURSOR = true -- TODO: handles opts
  if HIDE_CURSOR == true then
    vim.cmd [[ hi! Cursor blend=100 ]]
    vim.cmd "au! WinClosed <buffer> highlight! Cursor blend=0"
  end

  local saved_user_options = {
    cursorline = api.nvim_get_option "laststatus",
  }

  api.nvim_win_set_option(winid, "cursorline", false)
  api.nvim_set_option("laststatus", 0)

  return {
    winid = winid,
    bufid = bufid,
    saved_user_options = saved_user_options,
  }
end

return M
