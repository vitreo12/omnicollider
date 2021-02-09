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
import omni_lang/core/wrapper/omni_wrapper except omni_buffer_interface

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
#[ omniBufferInterface:
    debug: true

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
        discard

    #(buffer : Buffer) -> bool
    lock:
        let bufnum = buffer.input_bufnum
        if buffer.bufnum != bufnum:
            buffer.snd_buf = get_buffer_SC(buffer.sc_world, cfloat(bufnum),cint(buffer.print_invalid))
            buffer.bufnum = bufnum
            if not isNil(buffer.snd_buf):
                buffer.print_invalid = true
                return false

        if isNil(buffer.snd_buf):
            buffer.bufnum = float(-1000000000.0)
            buffer.print_invalid = false
            return false

        when defined(supernova):
            lock_buffer_SC(buffer.snd_buf)

        return true
    
    #(buffer : Buffer) -> void
    unlock:
        when defined(supernova):
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
        set_float_value_buffer_SC(buffer.snd_buf, cfloat(x), clong(index), clong(channel)) ]#

type 
    Buffer_omni_struct* = object of Buffer_inherit
        sc_world*: pointer
        snd_buf*: pointer
        bufnum*: float
        input_bufnum*: float
        print_invalid*: bool

    Buffer* = ptr Buffer_omni_struct
    Buffer_omni_struct_ptr* = Buffer

proc Buffer_omni_struct_new*(buffer_name: string; buffer_interface: pointer; omni_struct_type: typedesc[Buffer_omni_struct_ptr]; omni_auto_mem: Omni_AutoMem; omni_call_type: typedesc[Omni_CallType] = Omni_InitCall): Buffer {.inline.} =
    when omni_call_type is Omni_PerformCall:
        {.fatal: "Buffer: attempting to allocate memory in the \'perform\' or \'sample\' blocks".}
    var buffer = cast[Buffer](omni_alloc(culong(sizeof(Buffer_omni_struct))))
    omni_auto_mem.omni_auto_mem_register_child(buffer)
    buffer.valid = false
    buffer.name = buffer_name
    buffer.sc_world = buffer_interface
    buffer.bufnum = float32(-1000000000.0)
    buffer.print_invalid = true
    buffer.init  = true
    return buffer

proc omni_update_buffer*(buffer: Buffer; val: cstring = ""): void {.inline.} =
    discard

proc omni_lock_buffer*(buffer: Buffer): bool {.inline.} =
    let bufnum = buffer.input_bufnum
    if buffer.bufnum != bufnum:
        buffer.snd_buf = get_buffer_SC(buffer.sc_world, cfloat(bufnum),cint(buffer.print_invalid))
        buffer.bufnum = bufnum
        if not isNil(buffer.snd_buf):
            buffer.print_invalid = true
            return false
    if isNil(buffer.snd_buf):
        buffer.bufnum = float(-1000000000.0)
        buffer.print_invalid = false
        return false
    when defined(supernova):
        lock_buffer_SC(buffer.snd_buf)
    return true

proc omni_unlock_buffer*(buffer: Buffer): void {.inline.} =
    when defined(supernova):
        unlock_buffer_SC(buffer.snd_buf)

proc omni_get_length_buffer*(buffer: Buffer, omni_call_type: typedesc[Omni_CallType] = Omni_InitCall): int {.inline.} =
    when omni_call_type is Omni_InitCall:
        {.fatal: "\'Buffers\' can only be accessed in the \'perform\' / \'sample\' blocks".}
    return get_frames_buffer_SC(buffer.snd_buf)

proc omni_get_samplerate_buffer*(buffer: Buffer, omni_call_type: typedesc[Omni_CallType] = Omni_InitCall): float {.inline.} =
    when omni_call_type is Omni_InitCall:
        {.fatal: "\'Buffers\' can only be accessed in the \'perform\' / \'sample\' blocks".}
    return get_samplerate_buffer_SC(buffer.snd_buf)

proc omni_get_channels_buffer*(buffer: Buffer, omni_call_type: typedesc[Omni_CallType] = Omni_InitCall): int {.inline.} =
    when omni_call_type is Omni_InitCall:
        {.fatal: "\'Buffers\' can only be accessed in the \'perform\' / \'sample\' blocks".}
    return get_channels_buffer_SC(buffer.snd_buf)

proc omni_get_value_buffer*(buffer: Buffer; channel: int = 0; index: int = 0; omni_call_type: typedesc[Omni_CallType] = Omni_InitCall): float {.inline.} =
    when omni_call_type is Omni_InitCall:
        {.fatal: "\'Buffers\' can only be accessed in the \'perform\' / \'sample\' blocks".}
    return get_float_value_buffer_SC(buffer.snd_buf, clong(index), clong(channel))

proc omni_set_value_buffer*[T: SomeNumber](buffer: Buffer; channel: int = 0; index: int = 0; x: T; omni_call_type: typedesc[Omni_CallType] = Omni_InitCall): void {.inline.} =
    when omni_call_type is Omni_InitCall:
        {.fatal: "\'Buffers\' can only be accessed in the \'perform\' / \'sample\' blocks".}
    set_float_value_buffer_SC(buffer.snd_buf, cfloat(x), clong(index), clong(channel))

proc omni_read_value_buffer*[I: SomeNumber](buffer: Buffer; index: I; omni_call_type: typedesc[Omni_CallType] = Omni_InitCall): float {.inline.} =
    when omni_call_type is Omni_InitCall:
        {.fatal: "\'Buffers\' can only be accessed in the \'perform\' / \'sample\' blocks".}
    let buf_len = buffer.omni_get_length_buffer
    if buf_len <= 0:
        return 0.0'f64
    let
        index_int = int(index)
        index1: int = index_int mod buf_len
        index2: int = (index1 + 1) mod buf_len
        frac: float = float(index) - float(index_int)
    return linear_interp(frac, buffer.omni_get_value_buffer(0, index1,omni_call_type), buffer.omni_get_value_buffer(0, index2, omni_call_type))

proc omni_read_value_buffer*[I1: SomeNumber; I2: SomeNumber](buffer: Buffer; chan: I1; index: I2; omni_call_type: typedesc[Omni_CallType] = Omni_InitCall): float {.inline.} =
    when omni_call_type is Omni_InitCall:
        {.fatal: "\'Buffers\' can only be accessed in the \'perform\' / \'sample\' blocks".}
    let buf_len = buffer.omni_get_length_buffer
    if buf_len <= 0:
        return 0.0'f64
    let
        chan_int = int(chan)
        index_int = int(index)
        index1: int = index_int mod buf_len
        index2: int = (index1 + 1) mod buf_len
        frac: float = float(index) - float(index_int)
    return linear_interp(frac, buffer.omni_get_value_buffer(chan_int, index1, omni_call_type), buffer.omni_get_value_buffer(chan_int, index2, omni_call_type))