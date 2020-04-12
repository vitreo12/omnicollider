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
{.passC: "-O3".}

#Wrapping of cpp functions
proc get_buffer_SC(buffer_SCWorld : pointer, fbufnum : cfloat) : pointer {.importc, cdecl.}

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
    Buffer_obj = object
        sc_world   : pointer
        snd_buf    : pointer
        bufnum     : float32
        input_num* : int       #need to export it in order to be retrieved with the ins_Nim[buffer.input_num][0] syntax for get_buffer.
        length     : int
        size       : int
        chans      : int
        samplerate : float
        #sampledur  : float

    Buffer* = ptr Buffer_obj

const
    exceeding_max_ugen_inputs = "ERROR [omni]: Buffer: exceeding maximum number of inputs: "
    upper_exceed_input_error  = "ERROR [omni]: Buffer: Maximum input number is 32. Out of bounds: "
    lower_exceed_input_error  = "ERROR [omni]: Buffer: Minimum input number is 1. Out of bounds: "

proc innerInit*[S : SomeInteger](obj_type : typedesc[Buffer], input_num : S, omni_inputs : int, buffer_interface : pointer, ugen_auto_mem : ptr OmniAutoMem) : Buffer {.inline.} =
    result = cast[Buffer](omni_alloc(culong(sizeof(Buffer_obj))))

    #Register this Buffer's memory to the ugen_auto_mem
    ugen_auto_mem.registerChild(result)
    
    result.sc_world  = get_sc_world()
    result.bufnum    = float32(-1e9)

    #1 should be 0, 2 1, 3 2, etc... 32 31
    result.input_num = int(input_num) - int(1)

    result.length = 0
    result.size = 0
    result.chans = 0
    result.samplerate = 0.0

    #If these checks fail set to sc_world to nil, which will invalidate the Buffer.
    #result.input_num is needed for get_buffer(buffer, ins[0][0), as 1 is the minimum number for ins, for now...
    if input_num > omni_inputs:
        omni_print_debug(exceeding_max_ugen_inputs, culong(omni_inputs))
        result.sc_world = nil
        result.input_num = 0

    elif input_num > 32:
        omni_print_debug(upper_exceed_input_error, culong(input_num))
        result.sc_world = nil
        result.input_num = 0

    elif input_num < 1:
        omni_print_debug(lower_exceed_input_error, culong(input_num)) #this prints out a ridicolous number if < 0... ulong overflow. 
        result.sc_world = nil
        result.input_num = 0

#Template which also uses the const omni_inputs, which belongs to the omni dsp new module. It will string substitute Buffer.init(1) with initInner(Buffer, 1, omni_inputs)
template new*[S : SomeInteger](obj_type : typedesc[Buffer], input_num : S) : untyped =
    innerInit(Buffer, input_num, omni_inputs, buffer_interface, ugen_auto_mem) #omni_inputs belongs to the scope of the dsp module

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
                return false
            
            lock_buffer_SC(buffer.snd_buf)
        
        #Retrieve and lock the new buffer
        else:
            #When supernova defined, get_buffer_SC will also lock the buffer!
            buffer.snd_buf = get_buffer_SC(buffer.sc_world, cfloat(bufnum))
            buffer.bufnum  = bufnum

            if isNil(buffer.snd_buf):
                return false

            buffer.length     = int(get_frames_buffer_SC(buffer.snd_buf))
            buffer.size       = int(get_samples_buffer_SC(buffer.snd_buf))
            buffer.chans      = int(get_channels_buffer_SC(buffer.snd_buf))
            buffer.samplerate = float(get_samplerate_buffer_SC(buffer.snd_buf))
    #scsynth
    else:
        #Update buffer pointer only with a new buffer number as input
        if buffer.bufnum != bufnum:
            buffer.snd_buf = get_buffer_SC(buffer.sc_world, cfloat(bufnum))
            buffer.bufnum  = bufnum
            
            if not isNil(buffer.snd_buf):
                buffer.length     = int(get_frames_buffer_SC(buffer.snd_buf))
                buffer.size       = int(get_samples_buffer_SC(buffer.snd_buf))
                buffer.chans      = int(get_channels_buffer_SC(buffer.snd_buf))
                buffer.samplerate = float(get_samplerate_buffer_SC(buffer.snd_buf))

        if isNil(buffer.snd_buf):
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

#1 channel
proc `[]`*[I : SomeNumber](a : Buffer, i : I) : float {.inline.} =
    return float(get_float_value_buffer_SC(a.snd_buf, clong(i), clong(0)))

#more than 1 channel (i1 == channel, i2 == index)
proc `[]`*[I1 : SomeNumber, I2 : SomeNumber](a : Buffer, i1 : I1, i2 : I2) : float {.inline.} =
    return float(get_float_value_buffer_SC(a.snd_buf, clong(i2), clong(i1)))

#linear interp read (1 channel)
proc read*[I : SomeNumber](buffer : Buffer, index : I) : float {.inline.} =
    let 
        buf_len = buffer.length
        index1 = safemod(int(index), buf_len)
        index2 = safemod(index1 + 1, buf_len)
        frac : float  = float(index) - float(index1)
    
    return linear_interp(frac, buffer[index1], buffer[index2])

#linear interp read (more than 1 channel) (i1 == channel, i2 == index)
proc read*[I1 : SomeNumber, I2 : SomeNumber](buffer : Buffer, chan : I1, index : I2) : float {.inline.} =
    let 
        buf_len = buffer.length
        index1 = safemod(int(index), buf_len)
        index2 = safemod(index1 + 1, buf_len)
        frac : float  = float(index) - float(index1)
    
    return linear_interp(frac, buffer[chan, index1], buffer[chan, index2])

##########
# SETTER #
##########

#1 channel
proc `[]=`*[I : SomeNumber, S : SomeNumber](a : Buffer, i : I, x : S) : void {.inline.} =
    set_float_value_buffer_SC(a.snd_buf, cfloat(x), clong(i), clong(0))

#more than 1 channel (i1 == channel, i2 == index)
proc `[]=`*[I1 : SomeNumber, I2 : SomeNumber, S : SomeNumber](a : Buffer, i1 : I1, i2 : I2, x : S) : void {.inline.} =
    set_float_value_buffer_SC(a.snd_buf, cfloat(x), clong(i2), clong(i1))

#########
# INFOS #
#########

#length of each frame in buffer
proc len*(buffer : Buffer) : int {.inline.} =
    return buffer.length

#Returns total size (snd_buf->samples)
proc size*(buffer : Buffer) : int {.inline.} =
    return buffer.size

#Number of channels
proc chans*(buffer : Buffer) : int {.inline.} =
    return buffer.chans

#Samplerate (float64)
proc samplerate*(buffer : Buffer) : float {.inline.} =
    return buffer.samplerate

#Sampledur (Float64)
#[ proc sampledur*(buffer : Buffer) : float {.inline.} =
    return buffer.sampledur ]#