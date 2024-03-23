import defs
import std/[os, osproc, streams, strutils, strformat, times]

const supportedDnfs = ["microdnf", "dnf5", "dnf"]

proc runWithLogging(hub: ref Hub, cmd: string, args: openArray[string] = [], inputs: string = ""): int =
  hub.say fmt"┌──── BEGIN: Command Execution `{cmd}` ─────"
  hub.say fmt"├═ Executing `{cmd}` with args `{args}`:"
  hub.mumble "┊ "
  let time = now()

  let process = startProcess(cmd, args = args, options = {poStdErrToStdOut})
  if inputs != "":
    process.inputStream().write inputs
  defer: process.close()
  let outs = process.outputStream
  # NOTE: outs also contains stderr
  
  while process.running:
    if outs.at_end:
      sleep(20)
    while not outs.at_end:
      hub.mumble ($outs.read_char).replace("\n", "\n┊ ")

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


proc dnfDownloadUpdate*(hub: ref Hub, ver: int, user: User): bool =
  let dnf = findDnf hub
  if dnf == "": return

  hub.say "Running normal system upgrade…"
  let sudo = findExe "sudo"
  if sudo == "":
    hub.say "`sudo` is not found. Exiting"
    return
  hub.say ""
  
  let rc = runWithLogging(hub, sudo, ["-S", dnf, "upgrade", "--refresh", "-y"], user.password & "\n")
  if rc != 0:
    hub.say "An error occurred. The update cannot continue."
    return
  # TODO: …
