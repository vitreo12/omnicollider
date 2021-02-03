# MIT License
# 
# Copyright (c) 2020 Francesco Cameli
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

import macros

#[ #override params handling in init
template omni_unpack_params_init(): untyped {.dirty.} =
    discard

#override params handling in perform
template omni_unpack_params_perform(): untyped {.dirty.} =
    discard ]#

macro omnicollider_generate_params_interface*(params_number : typed, params_names : untyped) : untyped =
    error astGenRepr params_names

#Run omni's inner param + omnicollider's
macro omni_params_inner*(params_number : typed, params_names : untyped) : untyped =
    error "mhmh"
    #return quote do:
    #    omnicollider_generate_params_interface()
        #omni_io.omni_params_inner(`params_number`, `params_names`)