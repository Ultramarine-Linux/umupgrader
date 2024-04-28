import std/options
import strutils, strformat
import owlkettle, owlkettle/adw
import defs, askpass, server

const
  title: string = "Ultramarine System Upgrader"
  icon: string = "system-upgrade"
  startmsg: string = dedent """
    ——— Below are logs from umupgrader ———
    GitHub Repository: https://github.com/Ultramarine-Linux/umupgrader/

    Checking for updates… (Make sure your system is connected to the Internet)
  """
  downloadFailMsg1: string = dedent """
    Failed to download system upgrade. This is usually caused by missing packages.
    You should check in the logs if vital/system/core packages would be removed.
    You may seek help via our socials, which are listed on the link below:
  """
  supportLink: string = "https://wiki.ultramarine-linux.org/en/community/community/"
  downloadFailMsg2: string = dedent """
    If you are certain the system upgrade would not break your computer,
    you may continue by clicking the download button again.
    This will force the package manager to remove packages that could not be upgraded.
  """
  css: string = dedent """
    textview:disabled text {
      color: @theme_fg_color;
    }
    .bright-fg {
      color: @theme_fg_color;
    }
    .normal-text {
      font-size: medium;
    }
  """

let logfile = open("/tmp/umupgrader.log", fmWrite)
let iconpixbuf = loadPixbuf("/usr/share/pixmaps/fedora-logo-sprite.svg")

viewable MyDialog:
  discard

method view(dialog: MyDialogState): Widget =
  let buf1 = newTextBuffer()
  buf1.insert(buf1.selection.a, downloadFailMsg1)
  let buf2 = newTextBuffer()
  buf2.insert(buf2.selection.a, downloadFailMsg2)
  result = gui:
    Dialog:
      title = "Download Failed"
      defaultSize = (700, 350)
      Box(orient = OrientY):
        TextView:
          buffer = buf1
          margin = 12
          editable = false
          sensitive = false
          style = [StyleClass("bright-fg"), StyleClass("normal-text")]
        LinkButton:
          uri = supportLink
          text = "Seek support"
          style = [StyleClass("normal-text")]
        TextView:
          buffer = buf2
          margin = 12
          editable = false
          sensitive = false
          style = [StyleClass("bright-fg"), StyleClass("normal-text")]
        Button {.vAlign: AlignEnd.}:
          text = "Close"
          proc clicked() =
            dialog.scheduleCloseWindow()

proc handle_main_recv(app: AppState) =
  while app.hub[].toMain.peek > 0:
    let msg = app.hub[].toMain.recv
    if msg.starts_with "\n":
      # handle the funny logs
      logfile.writeLine(msg[1..^1])
    elif msg.starts_with "newver\n":
      app.newVer = parseInt msg["newver\n".len..^1]
    elif msg.starts_with "dlstat\n":
      if app.newVer > 0 and app.dlfailed: return  # handled by dlerr
      case msg["dlstat\n".len..^1]
      of "0": app.newVer *= -1
      of "1": app.canApplyUpdate = true
      else: msg.recv_unknown_msg "main"
    elif msg == "dlerr":
      app.dlfailed = true
      discard app.open(gui(MyDialog()))
      if app.newVer < 0: app.newVer *= -1
    elif msg.starts_with "rebootstat\n":
      case msg["rebootstat\n".len..^1]
      of "0": discard # WTF.
      of "1": quit(0)
      else: msg.recv_unknown_msg "main"
    elif msg.starts_with "dlprogress\n":
      app.dlprogress = some msg["dlprogress\n".len..^1].parseFloat
    else: msg.recv_unknown_msg "main"

method view(app: AppState): Widget =
  handle_main_recv app

  let layout = (app.leftButtons, app.rightButtons)
  result = gui:
    AdwWindow:
      defaultSize = (800, 600)

      Box(orient = OrientY):
        AdwHeaderBar {.expand: false.}:
          style = HeaderBarFlat

        StatusPage():
          iconName = "ultramarine"
          title = "Ultramarine System Upgrade"
          description = "You may use this app to upgrade Ultramarine Linux\nto the latest version: [Ultramarine 40]"

          Box(orient = OrientY):
            if app.dlprogress.is_some:
              ProgressBar {.vAlign: AlignCenter.}:
                ellipsize = EllipsizeEnd
                fraction = app.dlprogress.get
                pulseStep = 0.1
                showText = true
                text = "Downloading Updates"
            Box(orient = OrientX) {.expand: true, hAlign: AlignCenter.}:
              Button {.expand: false, hAlign: AlignCenter.}:
                if app.newVer > 0:
                  style = [ButtonSuggested, ButtonPill]
                sensitive = app.newVer > 0
                if app.canApplyUpdate:
                  style = [ButtonDestructive, ButtonPill]
                  text = "Reboot now to apply upgrade"
                else:
                  text = "Download system upgrade"

                proc clicked() =
                  if app.canApplyUpdate:
                    app.hub[].toThrd.send fmt "reboot\n{app.user.name}\n{app.user.password}"
                  if app.dlfailed:
                    var ver = app.newVer
                    if app.newVer > 0: app.newVer *= -1
                    if ver < 0: ver *= -1
                    app.hub[].toThrd.send fmt "forcedl\n{app.user.name}\n{app.user.password}\n{ver}"
                    return
                  var ver = app.newVer
                  if app.newVer > 0: app.newVer *= -1 # disables the button
                  if ver < 0: ver *= -1
                  app.user = askpass app
                  if app.user.name == "":
                    app.newVer = ver
                    return
                  app.hub[].toThrd.send fmt "download\n{app.user.name}\n{app.user.password}\n{ver}"


proc setupClient(hub: ref Hub) =
  hub[].toThrd.send "updck"
  let buf = newTextBuffer()
  discard buf.registerTag("marker", TagStyle(
    background: some("#ffff77"),
    weight: some(700)
  ))
  buf.insert(buf.selection.a, startmsg)
  adw.brew(gui(App(buffer = buf, hub = hub)), stylesheets=[newStyleSheet(css)])

proc main() =
  defer: logfile.close()
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
