version       = "0.1.0"
author        = "Francesco Cameli"
description   = "SuperCollider wrapper for omni."
license       = "MIT"

requires "nim >= 1.0.0"
requires "cligen >= 0.9.41"
requires "omni >= 0.1.0"

installDirs = @["omnicollider"]

#This are all the CLI interfaces
bin = @["omnicollider"]

#Task to build the Omni UGen for SuperCollider, allowing for JIT compilation of omni code
