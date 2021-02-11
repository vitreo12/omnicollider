# MIT License
# 
# Copyright (c) 2020-2021 Francesco Cameli
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

version       = "0.3.0"
author        = "Francesco Cameli"
description   = "SuperCollider wrapper for omni."
license       = "MIT"

requires "nim >= 1.4.0"
requires "cligen >= 1.0.0"
requires "omni >= 0.3.0"

#Ignore omnicollider_lang
skipDirs = @["omnicollider_lang"]

#Install build/deps
installDirs = @["omnicolliderpkg"] 

#Compiler executable
bin = @["omnicollider"]

#If using "nimble install" instead of "nimble installOmniCollider", make sure omnicollider-lang is still getting installed
before install:
    let package_dir = getPkgDir()
    
    withDir(package_dir):
        exec "git submodule update --init --recursive"

    withDir(package_dir & "/omnicollider_lang"):
        exec "nimble install"

#before/after are BOTH needed for any of the two to work
after install:
    discard