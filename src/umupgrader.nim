import std/[sequtils, options, os]
import strutils, strformat
import owlkettle, owlkettle/[playground, adw]
import updateck, download, askpass

const
  title: string = "Ultramarine System Upgrader"
  icon: string = "system-upgrade"
  startmsg: string = dedent """
    ——— Below are logs from umupgrader ———
    GitHub Repository: https://github.com/Ultramarine-Linux/umupgrader/

    Checking for updates… (Make sure your system is connected to the Internet)
  """

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

var thread: Thread[AppState]

proc updateckTh(app: AppState) {.thread.} =
  let upd = determine_update()
  var buf = app.buffer
  while buf == nil:
    sleep(100)
  if upd.is_none():
    buf.insert(buf.selection.a, "Cannot determine update status. Make sure you have an Internet connection.")
    return # maybe?
  let ver = upd.get
  if ver < 0:
    buf.insert(buf.selection.a, fmt"Hooray! Your system is up to date. (Version: {-ver})")
    return
  if ver == 0:
    buf.insert(buf.selection.a, "This operating system is not supported.")
    return
  app.newVer = ver
  buf.insert(buf.selection.a, fmt"New version available: {ver}")
  buf.insert(buf.selection.a, "\nClick the top right refresh button and the 'Download Update' button to start!\n")

method view(app: AppState): Widget =
  if not app.firstStart:
    app.firstStart = true
    createThread(thread, updateckTh, app)

  let layout = (app.leftButtons, app.rightButtons)
  result = gui:
    Window:
      title = title
      defaultSize = (800, 600)
      iconName = icon

      AdwHeaderBar {.addTitlebar.}:
        windowControls = layout
        centeringPolicy = app.centeringPolicy
        showLeftButtons = app.showLeftButtons
        showRightButtons = app.showRightButtons
        showBackButton = app.showBackButton
        tooltip = app.tooltip
        sizeRequest = app.sizeRequest

        # insert(app.toAutoFormMenu(sizeRequest = (400, 400))) {.addRight.}

        Button {.addLeft.}:
          text = "1"
          style = [ButtonFlat]

          proc clicked() =
            echo "Clicked 1"

        Button {.addRight.}:
          text = "2"
          style = [ButtonFlat]

          proc clicked() =
            echo "Clicked 2"

        if AdwVersion >= (1, 4):
          Box {.addTitle.}:
            Label(text = title)
            Icon(name = icon) {.expand: false.}

      Box(orient = OrientY):
        Box(orient = OrientX, margin = 12, spacing = 6) {.expand: false.}:

          Button:
            text = "Download Update"
            sensitive = app.newVer != 0

            proc clicked() =
              let ver = app.newVer
              app.newVer = 0 # disables the button
              if app.user == nil || app.user.name == "":
                let (res, state) = app.open(gui(UserDialog()))
                if res.kind == DialogAccept:
                  app.user = UserDialogState(state).user
              app.canApplyUpdate = dnfDownloadUpdate(ver, app.user, app.buffer)

          Button:
            text = "Apply Update (Reboot)"
            sensitive = app.canApplyUpdate

            proc clicked() =
              # TODO: reboot?
              discard

          Button {.expand: false.}:
            icon = "reload"
            style = [ButtonSuggested]

            proc clicked() =
              discard redraw app

        # Box(orient = OrientX, margin = 12, spacing = 6):
        #   Label(text = $app.counter)
        #   Button {.expand: false.}:
        #     text = "+"
        #     style = [ButtonSuggested]
        #     proc clicked() =
        #       app.counter += 1
        ScrolledWindow:
          TextView:
            margin = 12
            buffer = app.buffer
            monospace = true
            cursorVisible = true
            editable = false
            acceptsTab = false
            indent = 0
            sensitive = true
            tooltip = ""
            sizeRequest = app.sizeRequest

proc main() =
  let buf = newTextBuffer()
  discard buf.registerTag("marker", TagStyle(
    background: some("#ffff77"),
    weight: some(700)
  ))
  buf.insert(buf.selection.a, startmsg)
  adw.brew(gui(App(buffer = buf)))

when isMainModule:
  main()
