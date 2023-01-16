local api = vim.api
api.nvim_create_augroup('extmark-toy.nvim', { clear = true })
local UPDATE_INTERVAL = 1000/60
local HIDE_CURSOR = true

local EFFECT_MODULES = {
  require "extmark-toy.chessboard",
  require "extmark-toy.spotlight",
}


local M = {}

M.TIMER_INSTANCE = nil
-- M.logo_data = nil

M.start = function(opts)
  opts = opts or {}

  -- check if already running
  if M.TIMER_INSTANCE then
    return
  end

  vim.o.eventignore = "all" -- TODO: undo this on_close
  api.nvim_create_autocmd({ 'WinLeave' }, {
    group = 'extmark-toy.nvim',
    pattern = '*',
    callback = function ()
      require('extmark-toy').stop()
    end
  })


  -- TODO: calculate delta-time here and pass single value to all coroutines

  -- initialise effects and create coroutines
  M.coroutines = {}
  for i, effect_module in ipairs(EFFECT_MODULES) do
    effect_module.init(opts)
    M.coroutines[i] = coroutine.create(effect_module.effect_coroutine)
  end

  M.TIMER_INSTANCE = vim.loop.new_timer()
  M.TIMER_INSTANCE:start(UPDATE_INTERVAL, UPDATE_INTERVAL, function()
    for _, active_coroutine in ipairs(M.coroutines) do
      if coroutine.status(active_coroutine) == "suspended" and M.intro_active then
        local success, frame_lines = coroutine.resume(active_coroutine, os.clock())
        if not success then
          error(frame_lines)
        end
      end
    end
  end)

  M.intro_active = true
end

-- TODO: use `self` instead of all the M.attr
M.stop = function()
  if M.TIMER_INSTANCE then
    M.intro_active = false
    M.TIMER_INSTANCE:stop()
    M.TIMER_INSTANCE = nil

    -- Sleep for 1 x timer iteration (fixes schedule_wrap writing to non-existant buffer)
    vim.cmd("sleep 20m")

    -- TODO: call per-module cleanup routines here
    for _, effect in ipairs(EFFECT_MODULES) do
      effect.on_close()
    end


    M.effect_coroutines = nil

    if HIDE_CURSOR then
      vim.cmd [[ hi! Cursor blend=0 ]]
    end
    vim.opt.laststatus = 2

    vim.o.eventignore = ""

    --
    -- print "Intro aborted."
  end
end

return M
