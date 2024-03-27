import std/[options, os]
import strutils, strformat
import updateck, dnf, defs


proc updateck(hub: ref Hub) =
  let upd = determine_update()
  if upd.is_none:
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
  hub.say "\nClick the 'Download Update' button to start!\n"

proc handle_thrd_recv(hub: ref Hub, msg: string): bool =
  if msg == "bai":
    return true  # exit
  if msg == "updck":
    updateck(hub)
    return

  if msg.starts_with "forcedl\n":
    echo "thrd: received forcedl event"
    let lines = msg.split_lines
    let ver = lines[3].parseInt
    let user = User(name: lines[1], password: lines[2])
    let ret = if dnfDownloadUpdate(hub, ver, user): 1 else: 0
    hub[].toMain.send "dlstat\n" & $ret
    return

  if msg.starts_with "download\n":
    echo "thrd: received download event"
    let lines = msg.split_lines
    let ver = lines[3].parseInt
    let user = User(name: lines[1], password: lines[2])
    let ret = if dnfDownloadUpdate(hub, ver, user): 1 else: 0
    hub[].toMain.send "dlstat\n" & $ret
    return

  if msg.starts_with "reboot\n":
    echo "thrd: received reboot event"
    let lines = msg.split_lines
    let user = User(name: lines[1], password: lines[2])
    let ret = if reboot(hub, user): 0 else: 1
    hub[].toMain.send "rebootstat\n" & $ret
    return

  msg.recv_unknown_msg "child"

proc setupServer*(hub: ref Hub): Thread[ref Hub] =
  proc serverLoop(hub: ref Hub) =
    while true:
      let tried = hub[].toThrd.try_recv
      if tried.dataAvailable and hub.handle_thrd_recv tried.msg:
        return  # stop thread
      sleep(200) # Reduces stress on CPU when idle, increase when higher latency is acceptable for even better idle efficiency
  
  createThread(result, serverLoop, hub)
