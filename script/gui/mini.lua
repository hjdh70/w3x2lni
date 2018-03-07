local loaddll = require 'ffi.loaddll'
loaddll 'base'
loaddll 'nativeui'
local gui = require 'yue.gui'
local backend = require 'gui.backend'
local messagebox = require 'ffi.messagebox'
require 'filesystem'

local mini = {}

function mini:init()
    local win = gui.Window.create  { frame = false }
    
    local view = gui.Container.create()
    view:setstyle { FlexGrow = 1 }
    view:setmousedowncanmovewindow(true)
    
    local label = gui.Label.create('')
    label:setstyle { Margin = 5 }
    label:setmousedowncanmovewindow(true)
    view:addchildview(label)
    
    local pb = gui.ProgressBar.create()
    pb:setstyle { Margin = 5, Height = 40 }
    view:addchildview(pb)
    
    win:setcontentview(view)
    win:sethasshadow(true)
    win:setresizable(false)
    win:setmaximizable(false)
    win:setcontentsize { width = 400, height = 100 }
    win:center()
    win:activate()

    self._label = label
    self._progressbar = pb
    self._window = win
    self._view = view
end

function mini:settext(text)
    self._label:settext(text)
end

function mini:setvalue(value)
    self._progressbar:setvalue(value)
    self._view:schedulepaint()
end

function mini:close()
    self._window:close()
end

function mini:event_close(f)
    self._window.onclose = f
end

mini:init()
mini:event_close(gui.MessageLoop.quit)

local root = fs.current_path():remove_filename()
backend:init(root / 'bin' / 'w2l-worker.exe', root / 'script')
local worker = backend:open(root / 'script' / 'main.lua', ('-backend %s'):format(table.concat(arg, ' ')))
backend.message = '正在初始化...'
backend.progress = 0

local function update()
    worker:update()
    mini:settext(backend.message)
    mini:setvalue(backend.progress)
    if #worker.error > 0 then
        messagebox('错误', worker.error)
        worker.error = ''
        return 0
    end
    if worker.exited then
        return 1000
    end
end

local function delayedtask()
    local ok, r = xpcall(update, debug.traceback)
    if not ok then
        messagebox('错误', r)
        mini:close()
        return
    end
    if r then
        if r > 0 then
            gui.MessageLoop.postdelayedtask(r, function()
                mini:close()
            end)
        else
            mini:close()
        end
        return
    end
    gui.MessageLoop.postdelayedtask(100, delayedtask)
end
gui.MessageLoop.postdelayedtask(100, delayedtask)
gui.MessageLoop.run()