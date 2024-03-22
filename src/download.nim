import owlkettle
import defs
import std/[os, osproc, streams, strutils, strformat, times]

const supportedDnfs = ["microdnf", "dnf5", "dnf"]

proc runWithLogging(buf: var TextBuffer, cmd: string, args: openArray[string] = [], inputs: string = ""): int =
  buf.say fmt"┌──── BEGIN: Command Execution `{cmd}` ─────"
  buf.say fmt"├═ Executing `{cmd}` with args `{args}`:"
  buf.mumble "┊ "
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
      buf.mumble ($outs.read_char).replace("\n", "\n┊ ")

  buf.say "\n│"
  buf.say fmt"├═ Return code: {process.peekExitCode}"
  buf.say fmt"├═ Time taken: {now() - time}"
  buf.say fmt"└──── END OF Command Execution `{cmd}` ─────"
  return process.peekExitCode

proc findDnf(buf: var TextBuffer): string =
  buf.say "Finding dnf…"

  for trydnf in supportedDnfs:
    result = findExe trydnf
    if result != "": break

  if result == "":
    buf.say "Cannot find any dnf installs in $PATH and current working directory."
    buf.say "Cannot proceed without one of the followings: " & $supportedDnfs
    return
  buf.say "Detected dnf: " & result


proc dnfDownloadUpdateInner(ver: int, app: var AppState): bool =
  var (user, buf) = (app.user, app.buffer)
  let dnf = findDnf buf
  if dnf == "": return

  buf.say "Running normal system upgrade…"
  let sudo = findExe "sudo"
  if sudo == "":
    buf.say "`sudo` is not found. Exiting"
    return
  buf.say ""
  
  let rc = runWithLogging(buf, sudo, ["-u", user.name, dnf, "upgrade", "--refresh", "-y"], user.password & "\n")
  if rc != 0:
    buf.say "An error occurred. The update cannot continue."
    return
  # TODO: …

proc dnfDownloadUpdate*(verapp: (int, AppState)) {.thread.} =
  var (ver, app) = verapp
  redrawFromThread app
  redrawFromThread app
  app.canApplyUpdate = dnfDownloadUpdateInner(ver, app)
