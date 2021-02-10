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

#Explicit import of omni_wrapper for all things needed to declare new omni structs
import omni_lang/core/wrapper/omni_wrapper

#If supernova flag is defined, pass it to cpp too
when defined(supernova):
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

#The interface has been generated with this command:
omniBufferInterface:
    debug: true

    struct:
        sc_world      : pointer
        snd_buf       : pointer
        bufnum        : float
        input_bufnum  : float
        print_invalid : bool

    #(buffer_interface : pointer, buffer_name : cstring) -> void
    init:
        buffer.sc_world  = buffer_interface #SC's World* is passed in as the buffer_interface argument
        buffer.bufnum    = float32(-1e9)
        buffer.print_invalid = true

    #(buffer : Buffer, val : cstring) -> void
    update:
        discard

    #(buffer : Buffer) -> bool
    lock:
        var snd_buf : pointer
        let bufnum = buffer.input_bufnum
        if buffer.bufnum != bufnum:
            snd_buf = get_buffer_SC(buffer.sc_world, cfloat(bufnum),cint(buffer.print_invalid))

        #Valid
        if not isNil(snd_buf):
            buffer.snd_buf = snd_buf
            buffer.bufnum = bufnum
            buffer.print_invalid = true #next time there's an invalid buffer, print it out
            buffer.length = get_frames_buffer_SC(snd_buf)
            buffer.samplerate = get_samplerate_buffer_SC(snd_buf)
            buffer.channels = get_channels_buffer_SC(snd_buf)
        #Invalid
        else:
            buffer.bufnum = float(-1000000000.0)
            buffer.print_invalid = false
            return false

        when defined(supernova):
            lock_buffer_SC(snd_buf)

        return true
    
    #(buffer : Buffer) -> void
    unlock:
        when defined(supernova):
            unlock_buffer_SC(buffer.snd_buf)

    #(buffer : Buffer, index : SomeInteger, channel : SomeInteger) -> float
    getter:
        return get_float_value_buffer_SC(buffer.snd_buf, clong(index), clong(channel))
    
    #(buffer : Buffer, x : SomeFloat, index : SomeInteger, channel : SomeInteger) -> void
    setter:
        set_float_value_buffer_SC(buffer.snd_buf, cfloat(x), clong(index), clong(channel))
