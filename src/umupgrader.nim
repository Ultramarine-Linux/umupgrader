import std/[options, os]
import strutils, strformat
import owlkettle, owlkettle/adw
import updateck, download, defs, askpass

const
  title: string = "Ultramarine System Upgrader"
  icon: string = "system-upgrade"
  startmsg: string = dedent """
    ——— Below are logs from umupgrader ———
    GitHub Repository: https://github.com/Ultramarine-Linux/umupgrader/

    Checking for updates… (Make sure your system is connected to the Internet)
  """

proc updateck(hub: ref Hub) =
  let upd = determine_update()
  if upd.is_none():
    hub.say "Cannot determine update status. Make sure you have an Internet connection."
    return
  let ver = upd.get
  if ver < 0:
    hub.say fmt"Hooray! Your system is up to date. (Version: {-ver})"
    return
  if ver == 0:
    hub.say "This operating system is not supported."
    return
  hub[].toMain.send "newver\n" & $ver
  hub.say fmt"New version available: {ver}"
  hub.say "\nClick the top right refresh button and the 'Download Update' button to start!\n"

method view(app: AppState): Widget =
  while app.hub[].toMain.peek > 0:
    let msg = app.hub[].toMain.recv
    if msg.starts_with "\n":
      app.buffer.insert(app.buffer.selection.a, msg[1..^1])
    elif msg.starts_with "newver\n":
      app.newVer = parseInt msg["newver\n".len..^1]
    elif msg.starts_with "dlstat\n":
      app.newVer = parseInt msg["dlstat\n".len..^1]
    else:
      echo "W: received unknown message:"
      echo "┌──── BEGIN: unknown message from child thread ─────"
      for line in msg.split_lines:
        echo fmt"┊ {line}"
      echo "└──── END OF unknown message from child thread ─────"


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
              app.hub[].toThrd.send fmt "download\n{app.user.name}\n{app.user.password}\n{ver}"

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
            sensitive = false
            tooltip = ""
            sizeRequest = app.sizeRequest

proc setupClient(hub: ref Hub) =
  hub[].toThrd.send "updck"
  let buf = newTextBuffer()
  discard buf.registerTag("marker", TagStyle(
    background: some("#ffff77"),
    weight: some(700)
  ))
  buf.insert(buf.selection.a, startmsg)
  adw.brew(gui(App(buffer = buf, hub = hub)))

proc setupServer(hub: ref Hub): Thread[ref Hub] =
  proc serverLoop(hub: ref Hub) =
    while true:
      let tried = hub.toThrd.try_recv
      if tried.dataAvailable:
        let msg = tried.msg
        if msg == "bai":
          return
        if msg == "updck":
          updateck(hub)
          continue
        if msg.starts_with "download\n":
          echo "thrd: received download event"
          let lines = msg.split_lines
          let ver = lines[3].parseInt
          let user = User(name: lines[1], password: lines[2])
          let ret = if dnfDownloadUpdate(hub, ver, user): 0 else: ver
          hub[].toMain.send "dlstat\n" & $ret
          continue

        echo "W: received unknown message:"
        echo "┌──── BEGIN: unknown message from main thread ─────"
        for line in msg.split_lines:
          echo fmt"┊ {line}"
        echo "└──── END OF unknown message from main thread ─────"
      sleep(200) # Reduces stress on CPU when idle, increase when higher latency is acceptable for even better idle efficiency
  
  createThread(result, serverLoop, hub)

proc main() =
  var hub = new Hub
  open hub[].toMain
  open hub[].toThrd
  let server = setupServer hub
  setupClient hub
  hub[].toThrd.send "bai"
  echo "Joining thread…"
  joinThread server
  close hub[].toMain
  close hub[].toThrd

when isMainModule:
  main()
