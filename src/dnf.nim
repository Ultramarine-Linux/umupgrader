import defs
import std/[os, osproc, streams, strutils, strformat, times]

const supportedDnfs = ["dnf"]

proc runWithLogging(hub: ref Hub, stage: int, cmd: string, args: openArray[string] = [], inputs: string = ""): int =
  hub.say fmt"┌──── BEGIN: Command Execution `{cmd}` ─────"
  hub.say fmt"├═ Executing `{cmd}` with args `{args}`:"
  hub.mumble "┊ "
  let time = now()

  let process = startProcess(cmd, args = args, options = {poStdErrToStdOut})
  if inputs != "":
    process.inputStream.write inputs
    process.inputStream.flush
  defer: process.close()
  let outs = process.outputStream
  var line = ""
  # NOTE: outs also contains stderr
  
  while process.running:
    if outs.at_end:
      sleep(20)
    while not outs.at_end:
      let c = $outs.read_char
      if c == "\n":
        hub.mumble "\n┊ "
        line = ""
      else:
        hub.mumble c
        line = line & c
        if line.endsWith ')':
          try:
            let middle = line.find('/')
            if middle <= 0:
              continue
            let denominator = line[1..middle-1].parseInt
            let divisor = line[middle+1..^2].parseInt
            if denominator > 0 and divisor > 0:
              hub.toMain.send "dlprogress\n" & $(denominator/divisor/3 + stage/3)
          except: discard

  hub.say "\n│"
  hub.say fmt"├═ Return code: {process.peekExitCode}"
  hub.say fmt"├═ Time taken: {now() - time}"
  hub.say fmt"└──── END OF Command Execution `{cmd}` ─────"
  return process.peekExitCode

proc findDnf(hub: ref Hub): string =
  hub.say "Finding dnf…"

  for trydnf in supportedDnfs:
    result = findExe trydnf
    if result != "": break

  if result == "":
    hub.say "Cannot find any dnf installs in $PATH and current working directory."
    hub.say "Cannot proceed without one of the followings: " & $supportedDnfs
    return
  hub.say "Detected dnf: " & result


proc dnfDownloadUpdate*(hub: ref Hub, ver: int): bool =
  let dnf = findDnf hub
  if dnf == "": return

  hub.say "Running normal system upgrade…"
  hub.say ""
  
  hub[].toMain.send "dlprogress\n0"
  if runWithLogging(hub, 0, dnf, ["upgrade", "--refresh", "-y"]) != 0:
    hub.say "An error occurred. The update cannot continue."
    return

  hub[].toMain.send "dlprogress\n" & $(1/3)
  if runWithLogging(hub, 1, dnf, ["install", "dnf-plugin-system-upgrade"]) != 0:
    hub.say "An error occurred. The update cannot continue."
    return

  hub[].toMain.send "dlprogress\n" & $(2/3)
  if runWithLogging(hub, 2, dnf, ["system-upgrade", "download", fmt"--releasever={ver}", "--best", "-y"]) != 0:
    hub[].toMain.send "dlerr"
    return
  
  hub[].toMain.send "dlprogress\n1"
  return true

proc dnfForceDownloadUpdate*(hub: ref Hub, ver: int): bool =
  let dnf = findDnf hub
  assert dnf != ""
  if runWithLogging(hub, 2, dnf, ["system-upgrade", "download", fmt"--releasever={ver}", "--best", "-y", "--allowerasing"]) != 0:
    hub.say "An error occurred. The update cannot continue."
    return
  return true

proc reboot*(hub: ref Hub): bool =
  let dnf = findDnf hub
  assert dnf != ""
  if runWithLogging(hub, 0, dnf, ["system-upgrade", "reboot"]) != 0:
    hub.say "An error occurred. Cannot reboot."
    return
  return true

