## Module with things that other modules need
## Putting stuff here such that no cyclic imports are caused
## 
## Threading ref: https://forum.nim-lang.org/t/10719
import owlkettle, owlkettle/adw


type User* = object
  name*: string
  password*: string

type Hub* = object
  toMain*: Channel[string]
  toThrd*: Channel[string]


viewable App:
  counter: int
  centeringPolicy: CenteringPolicy = CenteringPolicyLoose
  leftButtons: seq[WindowControlButton] = @[WindowControlIcon, WindowControlMenu]
  rightButtons: seq[WindowControlButton] = @[WindowControlMinimize,
      WindowControlMaximize, WindowControlClose]
  showRightButtons: bool = true
  showLeftButtons: bool = true
  showBackButton: bool = true
  tooltip: string = ""
  sizeRequest: tuple[x, y: int] = (-1, -1)
  buffer: TextBuffer
  firstStart: bool = false
  newVer: int = 0
  canApplyUpdate: bool = false
  user: User
  hub: ref Hub

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


export App, AppState, User
