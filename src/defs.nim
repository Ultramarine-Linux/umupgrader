## Module with things that other modules need
## Putting stuff here such that no cyclic imports are caused
## 
## Threading ref: https://forum.nim-lang.org/t/10719
import owlkettle
import std/[strutils, strformat, options]


type Hub* = object
  toMain*: Channel[string]
  toThrd*: Channel[string]


viewable App:
  leftButtons: seq[WindowControlButton] = @[WindowControlIcon, WindowControlMenu]
  rightButtons: seq[WindowControlButton] = @[WindowControlMinimize,
      WindowControlMaximize, WindowControlClose]
  sizeRequest: tuple[x, y: int] = (-1, -1)
  buffer: TextBuffer
  firstStart: bool = false
  newVer: int = 0
  canApplyUpdate: bool = false
  hub: ref Hub
  dlfailed: bool = false
  dlprogress: Option[float] = none(float)
  logfile: File

  hooks:
    afterBuild:
      proc redrawer(): bool =
        if state.hub[].toMain.peek > 0:
          discard redraw state
        
        const KEEP_LISTENER_ACTIVE = true
        return KEEP_LISTENER_ACTIVE
      discard addGlobalTimeout(200, redrawer)


proc say*(hub: ref Hub, msg: string) =
  echo msg
  hub[].toMain.send "\n" & msg & "\n"


proc mumble*(hub: ref Hub, msg: string) =
  stdout.write msg
  hub[].toMain.send "\n" & msg


proc recv_unknown_msg*(msg: string, isFrom: string) =
  echo "W: received unknown message:"
  echo fmt"┌──── BEGIN: unknown message from {isFrom} thread ─────"
  for line in msg.split_lines:
    echo "┊ "&line
  echo fmt"└──── END OF unknown message from {isFrom} thread ─────"

export App, AppState
