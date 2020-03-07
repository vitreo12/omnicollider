version       = "0.1.0"
author        = "Francesco Cameli"
description   = "SuperCollider wrapper for omni."
license       = "MIT"

requires "nim >= 1.0.0"
requires "cligen >= 0.9.41"
requires "omni >= 0.1.0"

#Ignore omnicollider_lang
skipDirs = @["omnicollider_lang"]

#Install build/deps
installDirs = @["omnicolliderpkg"] 

#Compiler executable
bin = @["omnicollider"]

#If using "nimble install" instead of "nimble installOmniCollider", make sure omnicollider-lang is still getting installed
before install:
    withDir(getPkgDir() & "/omnicollider_lang"):
        exec "nimble install"

#before/after are BOTH needed for any of the two to work
after install:
    discard

#As nimble install, but with -d:release, -d:danger and --opt:speed. Also installs omni_lang.
task installOmniCollider, "Install the omnicollider-lang package and the omnicollider compiler":
    #Build and install the omnicollider compiler executable. This will also trigger the "before install" to install omnicollider_lang
    exec "nimble install --passNim:-d:release --passNim:-d:danger --passNim:--opt:speed"