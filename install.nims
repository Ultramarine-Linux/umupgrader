#!/usr/bin/env nim
import std/[envvars, os, strutils, strformat, cmdline]

let basedir = getEnv("BASEDIR", "/usr")
let sudo = if existsEnv "INSTALL_WITH_SUDO": "sudo " else: ""
let pkgconfigCheck = getEnv("PKGCONFIG_CHECK", "1")
let nimbleFlags = commandLineParams()[1..^1].join(" ")

proc run(cmd: string) =
    echo "$ " & cmd
    try:
        let result = gorgeEx cmd
        if result.exitCode != 0:
            echo fmt"┌─ Fail to execute command: {cmd}"
            for line in result.output.splitLines:
              echo "┊ "&line
            echo fmt"└─ Command returned exit code {$result.exitCode}"
            quit 1
    except:
        echo fmt"Fail to execute command: {cmd}"
        quit 1

proc `/`(left, right: string): string =
    assert not right.startsWith '/'
    if left.endsWith '/':
        return left & right
    return left & '/' & right

proc pkgconfig(id: string) =
    if ["no", "0", "", "false", "off"].contains pkgconfigCheck.toLower:
        return
    let f = "pkgconfig/"&id&".pc"
    let x = fileExists("/usr/lib64/"&f) or fileExists("/usr/lib/"&f) or fileExists(basedir/"lib64/"&f) or fileExists(basedir/"lib64/"&f)
    if not x:
      echo "E: Cannot find pkgconfig for: " & id
      echo fmt"E: On RPM-based systems, install `pkgconfig({id})`"
      echo "E: On Fedora/Ultramarine:"
      echo fmt"E:  $ sudo dnf in 'pkgconfig({id})'"
      echo "E: This package is a build dependency of umupgrade and is thus required."
      quit 1

echo "umupgrader will be installed in (set $BASEDIR to change this): " & $basedir
echo "This script should be run with the proper priviledges such that the above path can be accessed freely"
echo "If you want install.nims to call sudo, define $INSTALL_WITH_SUDO"
echo ""
echo "Checking build dependencies"
pkgconfig "gtk4"
pkgconfig "libadwaita-1"
echo ""
echo "Building umupgrader"
run "nimble build " & nimbleFlags
run sudo & "cp umupgrader " & $(basedir/"bin")
run sudo & "cp com.fyralabs.umupgrader.policy " & $(basedir/"share/polkit-1/actions/")
run sudo & "cp umupgrader.desktop "& $(basedir/"share/applications/")
