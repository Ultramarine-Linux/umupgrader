## Module with things that other modules need
## Putting stuff here such that no cyclic imports are caused
import owlkettle, owlkettle/adw


type User* = object
  name*: string
  password*: string


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

proc say*(buf: var TextBuffer, msg: string) =
  echo msg
  buf.insert(buf.selection.a, msg & "\n")

proc mumble*(buf: var TextBuffer, msg: string) =
  stdout.write msg
  buf.insert(buf.selection.a, msg)


export App, AppState, User
