import owlkettle
import askpass
import std/[os, osproc, streams, strutils, strformat, times]

proc say(buf: TextBuffer, msg: string) =
  buf.insert(buf.selection.a, msg & "\n")

const supportedDnfs = ["microdnf", "dnf5", "dnf"]

proc runWithLogging(buf: TextBuffer, cmd: string, args: openArray[string] = [], inputs: string = ""): int =
  buf.say fmt"┌──── BEGIN: Command Execution `{cmd}` ─────"
  buf.say fmt"├═ Executing `{cmd}` with args `{args}`:"
  buf.insert(buf.selection.a, "┊")
  let time = cpuTime()

  let process = startProcess(cmd, args = args, options = {poStdErrToStdOut})
  if inputs != "":
    process.inputStream().write inputs
  defer: process.close()
  let outs = process.outputStream
  # NOTE: outs also contains stderr
  
  while process.running:
    if outs.at_end:
      sleep(20)
    buf.insert(buf.selection.a, outs.read_all.replace("\n", "\n┊"))

  buf.insert(buf.selection.a, "\n│\n")
  buf.say fmt"├═ Return code: {process.peekExitCode}"
  buf.say fmt"├═ Time taken: {cpuTime() - time}"
  buf.say fmt"└──── END OF Command Execution `{cmd}` ─────"
  return process.peekExitCode

proc findDnf(buf: TextBuffer): string =
  buf.say "Finding dnf…"

  for trydnf in supportedDnfs:
    result = findExe trydnf
    if result != "": break

  if result == "":
    buf.say "Cannot find any dnf installs in $PATH and current working directory."
    buf.say "Cannot proceed without one of the followings: " & $supportedDnfs
    return
  buf.say "Detected dnf: " & result


proc dnfDownloadUpdate*(ver: int, user: User, buf: TextBuffer): bool =
  let dnf = findDnf buf
  if dnf == "": return

  buf.say "Running normal system upgrade…"
  let rc = runWithLogging(buf, "sudo", ["-u", user.name, dnf, "upgrade", "--refresh", "-y"], user.password)
  if rc != 0:
    buf.say "An error occurred. The update cannot continue."
    return
  # TODO: …
