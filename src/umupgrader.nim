import std/[options, os]
import strutils, strformat
import owlkettle, owlkettle/adw
import updateck, download, defs
import askpass # cannot export some views

const
  title: string = "Ultramarine System Upgrader"
  icon: string = "system-upgrade"
  startmsg: string = dedent """
    ——— Below are logs from umupgrader ———
    GitHub Repository: https://github.com/Ultramarine-Linux/umupgrader/

    Checking for updates… (Make sure your system is connected to the Internet)
  """

var
  checkTh: Thread[AppState]
  downloadTh: Thread[(int, AppState)]

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
  redrawFromThread app

method view(app: AppState): Widget =
  if not app.firstStart:
    app.firstStart = true
    createThread(checkTh, updateckTh, app)

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
              var ver = app.newVer
              app.newVer = 0 # disables the button
              app.user = askpass app
              if app.user.name == "":
                app.newVer = ver
                return
              sleep 50
              var args = (ver, app)
              discard redraw app
              downloadTh.createThread(dnfDownloadUpdate, args)

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
