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

import macros, strutils

#[ #override params handling in init
template omni_unpack_params_init(): untyped {.dirty.} =
    discard

#override params handling in perform
template omni_unpack_params_perform(): untyped {.dirty.} =
    discard ]#

macro omnicollider_params*(ins_number : typed, params_number : typed, params_names : typed) : untyped =
    let param_names_val = params_names.getImpl()
    if param_names_val.kind != nnkStrLit:
        error "params: omnicollider can't retrieve params names."    
    let param_names_seq = param_names_val.strVal().split(',')

    var 
        new_omni_unpack_params_init = nnkTemplateDef.newTree(

        ) 

        new_omni_unpack_params_perform = nnkTemplateDef.newTree(

        )
    
    result = nnkStmtList.newTree(
        new_omni_unpack_params_init,
        new_omni_unpack_params_perform
    )

    error astGenRepr result

#register the omni_params_post_hook call
template omni_params_post_hook*() : untyped =
    omnicollider_params(omni_inputs, omni_params, omni_params_names_const)