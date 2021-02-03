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
proc lock_buffer_SC  (buf : pointer) : void {.importc, cdecl.}
proc unlock_buffer_SC(buf : pointer) : void {.importc, cdecl.}

#newBufferInterface takes care of omni_lang export (excluding standard Buffer's implementation)
#[ newBufferInterface:
    obj:
        sc_world      : pointer
        snd_buf       : pointer
        bufnum        : float
        print_invalid : bool

    #(buffer : Buffer, input_num : int, buffer_interface : pointer) : void
    init:
        buffer.sc_world  = get_sc_world()
        buffer.bufnum    = float32(-1e9)
        buffer.print_invalid = true

    #(buffer : Buffer, inputVal : float) : void
    getFromInput:
        var bufnum = inputVal
        if bufnum < 0.0:
            bufnum = 0.0

        #Update buffer pointer only with a new buffer number as input
        if buffer.bufnum != bufnum:
            buffer.snd_buf = get_buffer_SC(buffer.sc_world, cfloat(bufnum), cint(buffer.print_invalid))
            buffer.bufnum  = bufnum
            
            if not isNil(buffer.snd_buf):
                buffer.length = int(get_frames_buffer_SC(buffer.snd_buf))
                buffer.samplerate = float(get_samplerate_buffer_SC(buffer.snd_buf))
                buffer.channels = int(get_channels_buffer_SC(buffer.snd_buf))
                buffer.valid = true
                buffer.print_invalid = true #next time an invalid buffer is provided, print it out

        #If isNil, also reset the bufnum
        if isNil(buffer.snd_buf):
            buffer.bufnum = float(-1e9)
            buffer.print_invalid = false #stop printing invalid buffer
            buffer.valid = false
    
    #(buffer : Buffer, paramVal : cstring) : void
    getFromParam:
        discard

    lock:
        lock_buffer_SC(buffer.snd_buf)
    
    unlock:
        unlock_buffer_SC(buffer.snd_buf)

    #[
    length:
        int(get_frames_buffer_SC(buffer.snd_buf))

    samplerate:
        float(get_samplerate_buffer_SC(buffer.snd_buf))

    channels:
        int(get_channels_buffer_SC(buffer.snd_buf))
    ]#

    #(buffer : Buffer, channel : int, index : int) : float
    getter:
        return float(get_float_value_buffer_SC(buffer.snd_buf, clong(index), clong(channel)))

    #(buffer : Buffer, x : T, channel : int, index : int) : void
    setter:
        set_float_value_buffer_SC(buffer.snd_buf, cfloat(x), clong(index), clong(channel)) ]#