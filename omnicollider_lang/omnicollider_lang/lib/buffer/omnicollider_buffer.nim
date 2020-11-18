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

#If supernova defined, also pass the supernova flag to cpp
when defined(multithreadBuffers):
    {.passC: "-D SUPERNOVA".}

#cpp file to compile together. Should I compile it ahead and use the link pragma on the .o instead?
{.compile: "omnicollider_buffer.cpp".}

#Flags to cpp compiler
{.localPassc: "-O3".}
{.passC: "-O3".}

proc get_sc_world() : pointer {.importc, cdecl.}
proc get_buffer_SC(buffer_SCWorld : pointer, fbufnum : cfloat, print_invalid : cint) : pointer {.importc, cdecl.}
proc get_float_value_buffer_SC(buf : pointer, index : clong, channel : clong) : cfloat {.importc, cdecl.}
proc set_float_value_buffer_SC(buf : pointer, value : cfloat, index : clong, channel : clong) : void {.importc, cdecl.}
proc get_frames_buffer_SC(buf : pointer) : cint {.importc, cdecl.}
proc get_samples_buffer_SC(buf : pointer) : cint {.importc, cdecl.}
proc get_channels_buffer_SC(buf : pointer) : cint {.importc, cdecl.}
proc get_samplerate_buffer_SC(buf : pointer) : cdouble {.importc, cdecl.}

when defined(multithreadBuffers):
    proc lock_buffer_SC  (buf : pointer) : void {.importc, cdecl.}
    proc unlock_buffer_SC(buf : pointer) : void {.importc, cdecl.}
    
type
    Buffer_struct_inner* = object of Buffer_inherit
        sc_world      : pointer
        snd_buf       : pointer
        bufnum        : float32
        print_invalid : bool

    Buffer* = ptr Buffer_struct_inner

    Buffer_struct_export* = Buffer

proc Buffer_struct_new_inner*[S : SomeInteger](input_num : S, buffer_interface : pointer, obj_type : typedesc[Buffer_struct_export], ugen_auto_mem : ptr OmniAutoMem, ugen_call_type : typedesc[CallType] = InitCall) : Buffer {.inline.} =
    #Trying to allocate in perform block!
    when ugen_call_type is PerformCall:
        {.fatal: "attempting to allocate memory in the `perform` or `sample` blocks for `struct Buffer`".}

    result = cast[Buffer](omni_alloc(culong(sizeof(Buffer_struct_inner))))

    #Register this Buffer's memory to the ugen_auto_mem
    ugen_auto_mem.registerChild(result)
    
    result.sc_world  = get_sc_world()
    result.bufnum    = float32(-1e9)

    #1 should be 0, 2 1, 3 2, etc... 32 31
    result.input_num = int(input_num) - int(1)
    if result.input_num < 0:
        result.input_num = 0

    result.print_invalid = true

    result.length = 0
    result.size = 0
    result.chans = 0
    result.samplerate = 0.0

#Called at start of perform. If supernova is active, this will also lock the buffer.
#HERE THE WHOLE ins_Nim should be passed through, not just fbufnum (which is ins_Nim[buffer.input_num][0]).
proc get_buffer*(buffer : Buffer, fbufnum : float32) : bool {.inline.} =
    var bufnum = fbufnum
    if bufnum < 0.0:
        bufnum = 0.0

    #supernova
    when defined(multithreadBuffers):
        #If same buffer number, just lock it
        if buffer.bufnum == bufnum:
            if isNil(buffer.snd_buf):
                buffer.bufnum = float32(-1e9)
                buffer.print_invalid = false #stop printing invalid buffer
                return false
            
            lock_buffer_SC(buffer.snd_buf)
        
        #Retrieve and lock the new buffer
        else:
            #When supernova defined, get_buffer_SC will also lock the buffer!
            buffer.snd_buf = get_buffer_SC(buffer.sc_world, cfloat(bufnum), cint(buffer.print_invalid))
            buffer.bufnum  = bufnum

            if isNil(buffer.snd_buf):
                buffer.bufnum = float32(-1e9)
                buffer.print_invalid = false #stop printing invalid buffer
                return false
            
            buffer.print_invalid = true #next time an invalid buffer is provided, print it out
            buffer.length     = int(get_frames_buffer_SC(buffer.snd_buf))
            buffer.size       = int(get_samples_buffer_SC(buffer.snd_buf))
            buffer.chans      = int(get_channels_buffer_SC(buffer.snd_buf))
            buffer.samplerate = float(get_samplerate_buffer_SC(buffer.snd_buf))
    #scsynth
    else:
        #Update buffer pointer only with a new buffer number as input
        if buffer.bufnum != bufnum:
            buffer.snd_buf = get_buffer_SC(buffer.sc_world, cfloat(bufnum), cint(buffer.print_invalid))
            buffer.bufnum  = bufnum
            
            if not isNil(buffer.snd_buf):
                buffer.print_invalid = true #next time an invalid buffer is provided, print it out
                buffer.length     = int(get_frames_buffer_SC(buffer.snd_buf))
                buffer.size       = int(get_samples_buffer_SC(buffer.snd_buf))
                buffer.chans      = int(get_channels_buffer_SC(buffer.snd_buf))
                buffer.samplerate = float(get_samplerate_buffer_SC(buffer.snd_buf))

        #If isNil, also reset the bufnum
        if isNil(buffer.snd_buf):
            buffer.bufnum = float32(-1e9)
            buffer.print_invalid = false #stop printing invalid buffer
            return false
    
    return true

#Supernova unlocking
when defined(multithreadBuffers):
    proc unlock_buffer*(buffer : Buffer) : void {.inline.} =
        #This check is needed as buffers could be unlocked when another one has been failed to acquire!
        if not isNil(buffer.snd_buf):
            unlock_buffer_SC(buffer.snd_buf)

##########
# GETTER #
##########

proc getter*(buffer : Buffer, channel : int = 0, index : int = 0, ugen_call_type : typedesc[CallType] = InitCall) : float {.inline.} =
    when ugen_call_type is InitCall:
        {.fatal: "`Buffers` can only be accessed in the `perform` / `sample` blocks".}
    return float(get_float_value_buffer_SC(buffer.snd_buf, clong(index), clong(channel)))

##########
# SETTER #
##########

proc setter*[Y : SomeNumber](buffer : Buffer, channel : int = 0, index : int = 0, x : Y, ugen_call_type : typedesc[CallType] = InitCall) : void {.inline.} =
    when ugen_call_type is InitCall:
        {.fatal: "`Buffers` can only be accessed in the `perform` / `sample` blocks".}
    set_float_value_buffer_SC(buffer.snd_buf, cfloat(x), clong(index), clong(channel))