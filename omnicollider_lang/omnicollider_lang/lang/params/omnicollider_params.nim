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


import macros, strutils

#overwrite the omni_unpack_params_perform template! 
#instead of calling SetParam at each cycle from SC's CPP interface, just replace the template and use the inputs directly instead
macro omnicollider_params*(ins_number : typed, params_number : typed, params_names : typed) : untyped =
    let params_names_val = params_names.getImpl()
    if params_names_val.kind != nnkStrLit:
        error "params: omnicollider can't retrieve params' names."    
    
    let 
        ins_number_lit    = ins_number.intVal()
        params_number_lit = params_number.intVal()
        params_names_seq   = params_names_val.strVal().split(',')

    result = nnkStmtList.newTree()

    if params_number_lit > 0:
        var 
            new_omni_unpack_params_body = nnkStmtList.newTree(
                nnkLetSection.newTree()
            )

            new_omni_unpack_params_perform = nnkTemplateDef.newTree(
                newIdentNode("omni_unpack_params_perform"),
                newEmptyNode(),
                newEmptyNode(),
                nnkFormalParams.newTree(
                    newIdentNode("untyped")
                ),
                nnkPragma.newTree(
                    newIdentNode("dirty")
                ),
                newEmptyNode(),
                new_omni_unpack_params_body
            ) 
        
        result.add(
            new_omni_unpack_params_perform
        )

        for index, param_name in params_names_seq:
            let 
                param_name_ident = newIdentNode(param_name)
                omni_ins_ptr     = newIdentNode("omni_ins_ptr")
                param_index      = int(ins_number_lit + index)
            
            let let_stmt_ident_defs = nnkIdentDefs.newTree(
                param_name_ident,
                newEmptyNode(),
                nnkCall.newTree(
                    newIdentNode("omni_param_" & param_name & "_min_max"),
                    nnkBracketExpr.newTree(
                        nnkBracketExpr.newTree(
                            omni_ins_ptr,
                            newLit(param_index)
                        ),
                        newLit(0)
                    )
                )
            )
            
            new_omni_unpack_params_body[0].add(
                let_stmt_ident_defs
            )

#register the omni_params_post_hook call
template omni_params_pre_perform_hook*() : untyped =
    omnicollider_params(omni_inputs, omni_params, omni_params_names_const)