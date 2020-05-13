socket = require("socket")
json = require("dkjson")
require("util")
require("consts")
require("class")
require("queue")
require("globals")
require("character") -- after globals!
require("stage") -- after globals!
require("save")
require("engine")
require("localization")
require("graphics")
require("input")
require("network")
require("puzzles")
require("mainloop")
require("sound")
require("timezones")
require("gen_panels")
local utf8 = require("utf8")

global_canvas = love.graphics.newCanvas(canvas_width, canvas_height)

local last_x = 0
local last_y = 0
local input_delta = 0.0
local pointer_hidden = false

function love.load()
  math.randomseed(os.time())
  for i=1,4 do math.random() end
  read_key_file()
  mainloop = coroutine.create(fmainloop)
end

function love.update(dt)
  if love.mouse.getX() == last_x and love.mouse.getY() == last_y then
    if not pointer_hidden then
      if input_delta > mouse_pointer_timeout then
        pointer_hidden = true
        love.mouse.setVisible(false)
      else
       input_delta = input_delta + dt
      end
    end
  else
    last_x = love.mouse.getX()
    last_y = love.mouse.getY()
    input_delta = 0.0
    if pointer_hidden then
      pointer_hidden = false
      love.mouse.setVisible(true)
    end
  end

  leftover_time = leftover_time + dt

  local status, err = coroutine.resume(mainloop)
  if not status then
    error(err..'\n'..debug.traceback(mainloop))
  end
  this_frame_messages = {}

  update_music()
end

function love.draw()
  -- if not main_font then
    -- main_font = love.graphics.newFont("Oswald-Light.ttf", 15)
  -- end
  -- main_font:setLineHeight(0.66)
  -- love.graphics.setFont(main_font)
  if foreground_overlay then
    local scale = canvas_width/math.max(foreground_overlay:getWidth(),foreground_overlay:getHeight()) -- keep image ratio
    menu_drawf(foreground_overlay, canvas_width/2, canvas_height/2, "center", "center", 0, scale, scale )
  end

  love.graphics.setBlendMode("alpha", "alphamultiply")
  love.graphics.setCanvas(global_canvas)
  love.graphics.setBackgroundColor(unpack(global_background_color))
  love.graphics.clear()

  for i=gfx_q.first,gfx_q.last do
    gfx_q[i][1](unpack(gfx_q[i][2]))
  end
  gfx_q:clear()
  if config ~= nil and config.show_fps then
    love.graphics.print("FPS: "..love.timer.getFPS(),1,1)
  end

  love.graphics.setCanvas()
  love.graphics.clear(love.graphics.getBackgroundColor())
  x, y, w, h = scale_letterbox(love.graphics.getWidth(), love.graphics.getHeight(), 16, 9)
  love.graphics.setBlendMode("alpha","premultiplied")
  love.graphics.draw(global_canvas, x, y, 0, w / canvas_width, h / canvas_height)

  -- draw background and its overlay
  local scale = canvas_width/math.max(background:getWidth(),background:getHeight()) -- keep image ratio
  menu_drawf(background, canvas_width/2, canvas_height/2, "center", "center", 0, scale, scale )
  if background_overlay then
    local scale = canvas_width/math.max(background_overlay:getWidth(),background_overlay:getHeight()) -- keep image ratio
    menu_drawf(background_overlay, canvas_width/2, canvas_height/2, "center", "center", 0, scale, scale )
  end
end

function love.errorhandler(msg)
  msg = tostring(msg)
 
  print((debug.traceback("Error: " .. tostring(msg), 3)):gsub("\n[^\n]+$", ""))
 
  if not love.window or not love.graphics or not love.event then
    return
  end
 
  if not love.graphics.isCreated() or not love.window.isOpen() then
    local success, status = pcall(love.window.setMode, 800, 600)
    if not success or not status then
      return
    end
  end
 
  -- Reset state.
  if love.mouse then
    love.mouse.setVisible(true)
    love.mouse.setGrabbed(false)
    love.mouse.setRelativeMode(false)
    if love.mouse.isCursorSupported() then
      love.mouse.setCursor()
    end
  end
  if love.joystick then
    -- Stop all joystick vibrations.
    for i,v in ipairs(love.joystick.getJoysticks()) do
      v:setVibration()
    end
  end
  if love.audio then love.audio.stop() end
 
  love.graphics.reset()
  local font = love.graphics.setNewFont(14)
  
  love.graphics.setBackgroundColor(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)
 
  local trace = debug.traceback()
 
  love.graphics.origin()

  errimg = love.graphics.newImage("error-icon.png") or nil

  local sanitizedmsg = {}
  for char in msg:gmatch(utf8.charpattern) do
    table.insert(sanitizedmsg, char)
  end
  sanitizedmsg = table.concat(sanitizedmsg)
 
  local err = {}
 
  table.insert(err, "Error\n")
  table.insert(err, sanitizedmsg)
 
  if #sanitizedmsg ~= #msg then
    table.insert(err, "Invalid UTF-8 string in error message.")
  end
 
  table.insert(err, "\n")
 
  for l in trace:gmatch("(.-)\n") do
    if not l:match("boot.lua") then
      l = l:gsub("stack traceback:", "Traceback\n")
      table.insert(err, l)
    end
  end

  local p = table.concat(err, "\n")
  
  p = "Sorry, an unrecoverable error occurred.\n\n" .. p
  
  p = p:gsub("\t", "")
  p = p:gsub("%[string \"(.-)\"%]", "%1")

  local function draw()
    local pos = 70
    love.graphics.clear(0/255, 0/255, 0/255)
    love.graphics.printf(p, pos, pos, love.graphics.getWidth() - pos)
    if errimg then
      love.graphics.draw(errimg, love.graphics.getWidth() - 256, love.graphics.getHeight() - 256)
    end
    love.graphics.present()
  end
 
  local fullErrorText = p
  local function copyToClipboard()
    if not love.system then return end
    love.system.setClipboardText(fullErrorText)
    p = p .. "\nCopied to clipboard!"
    draw()
  end
 
  if love.system then
    p = p .. "\n\nPress Ctrl+C or tap to copy this error"
  end
 
  return function()
    love.event.pump()
 
    for e, a, b, c in love.event.poll() do
      if e == "quit" then
        return 1
      elseif e == "keypressed" and a == "escape" then
        return 1
      elseif e == "keypressed" and a == "c" and love.keyboard.isDown("lctrl", "rctrl") then
        copyToClipboard()
      elseif e == "touchpressed" then
        local name = love.window.getTitle()
        if #name == 0 or name == "Untitled" then name = "Game" end
        local buttons = {"OK", "Cancel"}
        if love.system then
          buttons[3] = "Copy to clipboard"
        end
        local pressed = love.window.showMessageBox("Quit "..name.."?", "", buttons)
        if pressed == 1 then
          return 1
        elseif pressed == 3 then
          copyToClipboard()
        end
      end
    end
 
    draw()
 
    if love.timer then
      love.timer.sleep(0.1)
    end
  end
 
end
