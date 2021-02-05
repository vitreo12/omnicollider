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

#explicit import of omni_wrapper (for omniBufferInterface)
import omni_lang/core/wrapper/omni_wrapper

#If omni_multithread_buffers or supernova are defined, pass the supernova flag to cpp
when defined(omni_multithread_buffers) or defined(supernova):
    {.passC: "-D SUPERNOVA".}

#cpp file to compile together.
{.compile: "omnicollider_buffer.cpp".}

#Flags to cpp compiler
{.localPassc: "-O3".}
{.passC: "-O3".}

proc get_buffer_SC(buffer_SCWorld : pointer, fbufnum : cfloat, print_invalid : cint) : pointer {.importc, cdecl.}
proc get_float_value_buffer_SC(buf : pointer, index : clong, channel : clong) : cfloat {.importc, cdecl.}
proc set_float_value_buffer_SC(buf : pointer, value : cfloat, index : clong, channel : clong) : void {.importc, cdecl.}
proc get_frames_buffer_SC(buf : pointer) : cint {.importc, cdecl.}
proc get_channels_buffer_SC(buf : pointer) : cint {.importc, cdecl.}
proc get_samplerate_buffer_SC(buf : pointer) : cdouble {.importc, cdecl.}
proc lock_buffer_SC  (buf : pointer) : void {.importc, cdecl.}
proc unlock_buffer_SC(buf : pointer) : void {.importc, cdecl.}

#Declare a new omniBufferInterface for omnicollider
omniBufferInterface:
    struct:
        sc_world      : pointer
        snd_buf       : pointer
        bufnum        : float
        input_bufnum  : float
        print_invalid : bool

    #(buffer_interface : pointer) -> void
    init:
        buffer.sc_world  = buffer_interface #SC's World* is passed in as the buffer_interface argument
        buffer.bufnum    = float32(-1e9)
        buffer.print_invalid = true

    #(buffer : Buffer, val : cstring) -> void
    update:
        #this has been set accordingly in omni_unpack_buffers_perform()
        let bufnum = buffer.input_bufnum

        #Update buffer pointer only with a new buffer number as input
        if buffer.bufnum != bufnum:
            buffer.snd_buf = get_buffer_SC(buffer.sc_world, cfloat(bufnum), cint(buffer.print_invalid))
            buffer.bufnum  = bufnum
            
            #Update entries only on change of snd_buf
            if not isNil(buffer.snd_buf):
                buffer.valid = true #allows the locking to be executed
                buffer.print_invalid = true #next time an invalid buffer is provided, print it out
        
        #If not, reset bufnum and set validity to false. This can happen when releasing a Buffer that's in use
        if isNil(buffer.snd_buf):
            buffer.bufnum = float(-1e9)
            buffer.print_invalid = false #stop printing invalid buffer
            buffer.valid = false #blocks any other action: output silence

    #(buffer : Buffer) -> bool
    lock:
        when defined(omni_multithread_buffers) or defined(supernova):
            lock_buffer_SC(buffer.snd_buf)
        return true
    
    #(buffer : Buffer) -> void
    unlock:
        when defined(omni_multithread_buffers) or defined(supernova):
            unlock_buffer_SC(buffer.snd_buf)

    #(buffer : Buffer) -> int
    length:
        return get_frames_buffer_SC(buffer.snd_buf)

    #(buffer : Buffer) -> float
    samplerate:
        return get_samplerate_buffer_SC(buffer.snd_buf)

    #(buffer : Buffer) -> int
    channels:
        return get_channels_buffer_SC(buffer.snd_buf)

    #(buffer : Buffer, index : SomeInteger, channel : SomeInteger) -> float
    getter:
        return get_float_value_buffer_SC(buffer.snd_buf, clong(index), clong(channel))
    
    #(buffer : Buffer, x : SomeFloat, index : SomeInteger, channel : SomeInteger) -> void
    setter:
        set_float_value_buffer_SC(buffer.snd_buf, cfloat(x), clong(index), clong(channel))