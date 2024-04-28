#!/usr/bin/env nim
import std/[envvars, os, strutils]

let basedir = getEnv("BASEDIR", "/usr")
let sudo = if existsEnv "INSTALL_WITH_SUDO": "sudo " else: ""

proc run(cmd: string) =
    echo "$ " & cmd
    try:
        let result = gorgeEx cmd
        if result.exitCode != 0:
            echo "Fail to execute command: " & cmd
            echo "Command returned exit code " & $result.exitCode
            quit 1
    except:
        echo "Fail to execute command: " & cmd
        quit 1

proc `/`(left, right: string): string =
    assert not right.startsWith '/'
    if left.endsWith '/':
        return left & right
    return left & '/' & right

echo "umupgrader will be installed in (set $BASEDIR to change this): " & $basedir
echo "This script should be run with the proper priviledges such that the above path can be accessed freely"
echo "If you want install.nims to call sudo, define $INSTALL_WITH_SUDO"

run "nimble build"
run sudo & "cp umupgrader " & $(basedir/"bin")
run sudo & "cp com.fyralabs.umupgrader.policy " & $(basedir/"share/polkit-1/actions/")
