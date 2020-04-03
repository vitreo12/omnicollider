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
    proc unlock_buffer_SC(buf : pointer) : void {.importc, cdecl.}

proc get_float_value_buffer_SC(buf : pointer, index : clong, channel : clong) : cfloat {.importc, cdecl.}

proc set_float_value_buffer_SC(buf : pointer, value : cfloat, index : clong, channel : clong) : void {.importc, cdecl.}

proc get_frames_buffer_SC(buf : pointer) : cint {.importc, cdecl.}

proc get_samples_buffer_SC(buf : pointer) : cint {.importc, cdecl.}

proc get_channels_buffer_SC(buf : pointer) : cint {.importc, cdecl.}

proc get_samplerate_buffer_SC(buf : pointer) : cdouble {.importc, cdecl.}

proc get_sampledur_buffer_SC(buf : pointer) : cdouble {.importc, cdecl.}

type
    Buffer_obj = object
        sc_world   : pointer
        snd_buf    : pointer
        bufnum     : float32
        input_num* : int       #need to export it in order to be retrieved with the ins_Nim[buffer.input_num][0] syntax for get_buffer.

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

    #Update buffer pointer only with a new buffer number as input
    if buffer.bufnum != bufnum:
        buffer.bufnum  = bufnum
        buffer.snd_buf = get_buffer_SC(buffer.sc_world, cfloat(bufnum))
    
    if isNil(buffer.snd_buf):
        return false
    
    return true

#Supernova unlocking
when defined(multithreadBuffers):
    proc unlock_buffer*(buffer : Buffer) : void {.inline.} =
        unlock_buffer_SC(cast[pointer](buffer.snd_buf))

##########
# GETTER #
##########

#1 channel
proc `[]`*[I : SomeNumber](a : Buffer, i : I) : float32 {.inline.} =
    return get_float_value_buffer_SC(a.snd_buf, clong(i), clong(0))

#more than 1 channel
proc `[]`*[I1 : SomeNumber, I2 : SomeNumber](a : Buffer, i1 : I1, i2 : I2) : float32 {.inline.} =
    return get_float_value_buffer_SC(a.snd_buf, clong(i1), clong(i2))

##########
# SETTER #
##########

#1 channel
proc `[]=`*[I : SomeNumber, S : SomeNumber](a : Buffer, i : I, x : S) : void {.inline.} =
    set_float_value_buffer_SC(a.snd_buf, cfloat(x), clong(i), clong(0))

#more than 1 channel
proc `[]=`*[I1 : SomeNumber, I2 : SomeNumber, S : SomeNumber](a : Buffer, i1 : I1, i2 : I2, x : S) : void {.inline.} =
    set_float_value_buffer_SC(a.snd_buf, cfloat(x), clong(i1), clong(i2))

#########
# INFOS #
#########

#length of each frame in buffer
proc len*(buffer : Buffer) : int {.inline.} =
    return int(get_frames_buffer_SC(buffer.snd_buf))

#Returns total size (snd_buf->samples)
proc size*(buffer : Buffer) : int {.inline.} =
    return int(get_samples_buffer_SC(buffer.snd_buf))

#Number of channels
proc nchans*(buffer : Buffer) : int {.inline.} =
    return int(get_channels_buffer_SC(buffer.snd_buf))

#Samplerate (float64)
proc samplerate*(buffer : Buffer) : float {.inline.} =
    return float(get_samplerate_buffer_SC(buffer.snd_buf))

#Sampledur (Float64)
proc sampledur*(buffer : Buffer) : float {.inline.} =
    return float(get_sampledur_buffer_SC(buffer.snd_buf))