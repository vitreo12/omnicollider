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

#Wrapping of cpp functions
proc get_buffer_SC(buffer_SCWorld : pointer, fbufnum : cfloat, print_invalid : cint) : pointer {.importc, cdecl.}

#To retrieve world
proc get_sc_world*() : pointer {.importc, cdecl.}

when defined(multithreadBuffers):
    proc lock_buffer_SC  (buf : pointer) : void {.importc, cdecl.}
    proc unlock_buffer_SC(buf : pointer) : void {.importc, cdecl.}

proc get_float_value_buffer_SC(buf : pointer, index : clong, channel : clong) : cfloat {.importc, cdecl.}

proc set_float_value_buffer_SC(buf : pointer, value : cfloat, index : clong, channel : clong) : void {.importc, cdecl.}

proc get_frames_buffer_SC(buf : pointer) : cint {.importc, cdecl.}

proc get_samples_buffer_SC(buf : pointer) : cint {.importc, cdecl.}

proc get_channels_buffer_SC(buf : pointer) : cint {.importc, cdecl.}

proc get_samplerate_buffer_SC(buf : pointer) : cdouble {.importc, cdecl.}

#proc get_sampledur_buffer_SC(buf : pointer) : cdouble {.importc, cdecl.}

type
    Buffer_struct_inner* = object
        sc_world      : pointer
        snd_buf       : pointer
        bufnum        : float32
        print_invalid : bool
        input_num*    : int       #need to export it in order to be retrieved with the ins_Nim[buffer.input_num][0] syntax for get_buffer.
        length*       : int
        size*         : int
        chans*        : int
        samplerate*   : float
        #sampledur    : float

    Buffer* = ptr Buffer_struct_inner

    Buffer_struct_export* = Buffer

proc Buffer_struct_new_inner*[S : SomeInteger](input_num : S, buffer_interface : pointer, obj_type : typedesc[Buffer_struct_export], ugen_auto_mem : ptr OmniAutoMem, ugen_call_type : typedesc[CallType] = InitCall) : Buffer {.inline.} =
    #Trying to allocate in perform block! nonono
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

#Register child so that it will be picked up in perform to run get_buffer / unlock_buffer
proc checkValidity*(obj : Buffer, ugen_auto_buffer : ptr OmniAutoMem) : bool =
    ugen_auto_buffer.registerChild(cast[pointer](obj))
    return true

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

proc get_float_value_buffer* [I : SomeNumber](a : Buffer, i : I, ugen_call_type : typedesc[CallType] = InitCall) : float {.inline.} =
    when ugen_call_type is InitCall:
        {.fatal: "`Buffers` can only be accessed in the `perform` / `sample` blocks".}
    return float(get_float_value_buffer_SC(a.snd_buf, clong(i), clong(0)))

proc get_float_value_buffer*[I1 : SomeNumber, I2 : SomeNumber](a : Buffer, i1 : I1, i2 : I2, ugen_call_type : typedesc[CallType] = InitCall) : float {.inline.} =
    when ugen_call_type is InitCall:
        {.fatal: "`Buffers` can only be accessed in the `perform` / `sample` blocks".}
    return float(get_float_value_buffer_SC(a.snd_buf, clong(i2), clong(i1)))

#1 channel
template `[]`*[I : SomeNumber](a : Buffer, i : I) : untyped {.dirty.} =
    get_float_value_buffer(a, i, ugen_call_type)

#more than 1 channel (i1 == channel, i2 == index)
template `[]`*[I1 : SomeNumber, I2 : SomeNumber](a : Buffer, i1 : I1, i2 : I2) : untyped {.dirty.} =
    get_float_value_buffer(a, i1, i2, ugen_call_type)

#linear interp read (1 channel)
proc read_inner*[I : SomeNumber](buffer : Buffer, index : I, ugen_call_type : typedesc[CallType] = InitCall) : float {.inline.} =
    when ugen_call_type is InitCall:
        {.fatal: "`Buffers` can only be accessed in the `perform` / `sample` blocks".}

    let buf_len = buffer.length
    
    if buf_len <= 0:
        return 0.0
        
    let
        index_int = int(index)
        index1 = index_int mod buf_len
        index2 = (index1 + 1) mod buf_len
        frac : float = float(index) - float(index_int)
    
    return float(linear_interp(frac, get_float_value_buffer(buffer, index1, ugen_call_type), get_float_value_buffer(buffer, index2, ugen_call_type)))
        
#linear interp read (more than 1 channel) (i1 == channel, i2 == index)
proc read_inner*[I1 : SomeNumber, I2 : SomeNumber](buffer : Buffer, chan : I1, index : I2, ugen_call_type : typedesc[CallType] = InitCall) : float {.inline.} =
    when ugen_call_type is InitCall:
        {.fatal: "`Buffers` can only be accessed in the `perform` / `sample` blocks".}

    let buf_len = buffer.length
    
    if buf_len <= 0:
        return 0.0

    let
        index_int = int(index)
        index1 = index_int mod buf_len
        index2 = (index1 + 1) mod buf_len
        frac : float = float(index) - float(index_int)
    
    return float(linear_interp(frac, get_float_value_buffer(buffer, chan, index1, ugen_call_type), get_float_value_buffer(buffer, chan, index2, ugen_call_type)))

template read*[I : SomeNumber](buffer : Buffer, index : I) : untyped {.dirty.} =
    read_inner(buffer, index, ugen_call_type)

template read*[I1 : SomeNumber, I2 : SomeNumber](buffer : Buffer, chan : I1, index : I2) : untyped {.dirty.} =
    read_inner(buffer, chan, index, ugen_call_type)

##########
# SETTER #
##########

proc set_float_value_buffer*[I : SomeNumber, S : SomeNumber](a : Buffer, i : I, x : S, ugen_call_type : typedesc[CallType] = InitCall) : void {.inline.} =
    when ugen_call_type is InitCall:
        {.fatal: "`Buffers` can only be accessed in the `perform` / `sample` blocks".}
    set_float_value_buffer_SC(a.snd_buf, cfloat(x), clong(i), clong(0))

proc set_float_value_buffer*[I1 : SomeNumber, I2 : SomeNumber, S : SomeNumber](a : Buffer, i1 : I1, i2 : I2, x : S, ugen_call_type : typedesc[CallType] = InitCall) : void {.inline.} =
    when ugen_call_type is InitCall:
        {.fatal: "`Buffers` can only be accessed in the `perform` / `sample` blocks".}
    set_float_value_buffer_SC(a.snd_buf, cfloat(x), clong(i2), clong(i1))

#1 channel
template `[]=`*[I : SomeNumber, S : SomeNumber](a : Buffer, i : I, x : S) : untyped {.dirty.} =
    set_float_value_buffer(a, i, x, ugen_call_type)

#more than 1 channel (i1 == channel, i2 == index)
template `[]=`*[I1 : SomeNumber, I2 : SomeNumber, S : SomeNumber](a : Buffer, i1 : I1, i2 : I2, x : S) : untyped {.dirty.} =
    set_float_value_buffer(a, i1, i2, x, ugen_call_type)

#########
# INFOS #
#########

#length of each frame in buffer
proc len*(buffer : Buffer) : int {.inline.} =
    return buffer.length

#Returns total size (snd_buf->samples)
#proc size*(buffer : Buffer) : int {.inline.} =
#    return buffer.size

#Number of channels
#proc chans*(buffer : Buffer) : int {.inline.} =
#    return buffer.chans

#Samplerate (float64)
#proc samplerate*(buffer : Buffer) : float {.inline.} =
#    return buffer.samplerate

#Sampledur (Float64)
#[ proc sampledur*(buffer : Buffer) : float {.inline.} =
    return buffer.sampledur ]#