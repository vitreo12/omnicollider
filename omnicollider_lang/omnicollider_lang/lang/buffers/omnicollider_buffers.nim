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

macro omnicollider_buffers*(ins_number : typed, params_number : typed, buffers_number : typed, omni_buffers_names : typed) : untyped =
    let buffers_names_val = omni_buffers_names.getImpl()
    if buffers_names_val.kind != nnkStrLit:
        error "buffers: omnicollider can't retrieve buffers' names."    
    
    let 
        ins_number_lit     = ins_number.intVal()
        params_number_lit  = params_number.intVal()
        buffers_number_lit = buffers_number.intVal()
        buffers_names_seq  = buffers_names_val.strVal().split(',')

    result = nnkStmtList.newTree()

    if buffers_number_lit > 0:  
        var 
            perform_block = nnkStmtList.newTree()
            omni_unpack_buffers_perform = nnkTemplateDef.newTree(
                newIdentNode("omni_unpack_buffers_perform"),
                newEmptyNode(),
                newEmptyNode(),
                nnkFormalParams.newTree(
                    newIdentNode("untyped")
                ),
                nnkPragma.newTree(
                    newIdentNode("dirty")
                ),
                newEmptyNode(),
                perform_block
            )
        
        result.add(
            omni_unpack_buffers_perform
        )

        for index, buffer_name in buffers_names_seq:
            let 
                buffer_name_ident = newIdentNode(buffer_name)
                buffer_name_omni_buffer_ident = newIdentNode(buffer_name & "_omni_buffer")
                omni_ins_ptr = newIdentNode("omni_ins_ptr")
                buffer_index = int(ins_number_lit + params_number_lit + index) #shift by ins + params

            perform_block.add(
                nnkLetSection.newTree(
                    nnkIdentDefs.newTree(
                        buffer_name_ident,
                        newEmptyNode(),
                        nnkDotExpr.newTree(
                            newIdentNode("omni_ugen"),
                            buffer_name_omni_buffer_ident
                        )
                    )
                ),
                nnkCall.newTree(
                    newIdentNode("omnicollider_set_input_bufnum_buffer"),
                    buffer_name_ident,
                    nnkBracketExpr.newTree(
                        nnkBracketExpr.newTree(
                            omni_ins_ptr,
                            newLit(buffer_index)
                        ),
                        newLit(0)
                    )
                )
            )

    #error repr result

template omni_buffers_post_hook*() : untyped =
    omnicollider_buffers(omni_inputs, omni_params, omni_buffers, omni_buffers_names_const)