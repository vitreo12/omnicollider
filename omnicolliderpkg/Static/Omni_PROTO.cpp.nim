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

var OMNI_PROTO_INCLUDES = """
#include <atomic>
#include <array>
#include <string>
#include "SC_PlugIn.h"
#include "omni.h"
"""

var OMNI_PROTO_CPP = """
#define NAME "Omni_PROTO"

#if defined(__APPLE__) || defined(_WIN32)
    #define EXTENSION ".scx"
#elif __linux__
    #define EXTENSION ".so"
#endif

//Interface table
static InterfaceTable *ft;

//Use an atomic flag so it works for supernova too
std::atomic_flag init_global_lock = ATOMIC_FLAG_INIT;
bool init_global = false;

//World pointer. This global pointer is used for RT allocation functions
World* SCWorld;

//Wrappers around RTAlloc, RTRealloc, RTFree
void* RTAlloc_func(size_t in_size)
{
    return ft->fRTAlloc(SCWorld, in_size);
}

void* RTRealloc_func(void* in_ptr, size_t in_size)
{
    return ft->fRTRealloc(SCWorld, in_ptr, in_size);
}

void RTFree_func(void* in_ptr)
{
    ft->fRTFree(SCWorld, in_ptr);
}

void RTPrint_str_func(const char* format_string)
{
    ft->fPrint("%s\n", format_string);
}

void RTPrint_float_func(float value)
{
    ft->fPrint("%f\n", value);
}

void RTPrint_int_func(int value)
{
    ft->fPrint("%d\n", value);
}

/*********************************/
/* omnicollider buffer interface */
/*********************************/
extern "C"
{
    void* get_buffer_SC(void* buffer_SCWorld, float fbufnum, int print_invalid)
    {
        if(!buffer_SCWorld)
            return nullptr;

        World* SCWorld = (World*)buffer_SCWorld;

        uint32 bufnum = (int)fbufnum; 

        //If bufnum is not more that maximum number of buffers in World* it means bufnum doesn't point to a LocalBuf
        if(!(bufnum >= SCWorld->mNumSndBufs))
        {
            SndBuf* snd_buf = SCWorld->mSndBufs + bufnum; 

            if(!(snd_buf->data))
            {
                if(print_invalid)
                    printf("WARNING: Omni: Invalid buffer at index %d\n", bufnum);
                return nullptr;
            }

            return (void*)snd_buf;
        }
        else
        {
            printf("ERROR: Omni: local buffers are not yet supported\n");
            return nullptr;
            //It would require to provide "unit" here (to retrieve parent). 
            //Perhaps it can be passed in void* buffer_interface?
        }
    }

    void lock_buffer_SC(void* snd_buf)
    {
        #ifdef SUPERNOVA
        ACQUIRE_SNDBUF_SHARED((SndBuf*)snd_buf);
        #endif
    }

    void unlock_buffer_SC(void* snd_buf)
    {
        #ifdef SUPERNOVA
        RELEASE_SNDBUF_SHARED((SndBuf*)snd_buf);
        #endif
    }

    int get_frames_buffer_SC(void* snd_buf)
    {
        return ((SndBuf*)snd_buf)->frames;
    }

    double get_samplerate_buffer_SC(void* snd_buf)
    {
        return ((SndBuf*)snd_buf)->samplerate;
    }

    int get_channels_buffer_SC(void* snd_buf)
    {
        return ((SndBuf*)snd_buf)->channels;
    }
}

//SC struct
struct Omni_PROTO : public Unit 
{
    void* omni_ugen;
};

//SC functions
static void Omni_PROTO_Ctor(Omni_PROTO* unit);
static void Omni_PROTO_Dtor(Omni_PROTO* unit);
static void Omni_PROTO_next(Omni_PROTO* unit, int inNumSamples);
static void Omni_PROTO_silence_next(Omni_PROTO* unit, int inNumSamples);

void Omni_PROTO_Ctor(Omni_PROTO* unit) 
{
    //Initialization routines. These are executed only the first time an OMNI_PROTO UGen is created.
    if(!init_global)
    {
        //Acquire lock
        while(init_global_lock.test_and_set(std::memory_order_acquire))
            ; //spin

        //First thread that reaches this will set it for the entire shared object just once
        if(!init_global)
        {
            if(!(&Omni_InitGlobal))
                Print("ERROR: No %s%s loaded\n", NAME, EXTENSION);
            else 
            {               
                //Set SCWorld pointer used in the RT functions
                SCWorld = unit->mWorld;
                
                //Init omni with all the correct function pointers
                Omni_InitGlobal(
                    (omni_alloc_func_t*)RTAlloc_func, 
                    (omni_realloc_func_t*)RTRealloc_func, 
                    (omni_free_func_t*)RTFree_func,
                    (omni_print_str_func_t*)RTPrint_str_func,
                    (omni_print_float_func_t*)RTPrint_float_func,
                    (omni_print_int_func_t*)RTPrint_int_func
                );
            }

            //Completed initialization
            init_global = true;
        }

        //Release lock
        init_global_lock.clear(std::memory_order_release); 
    }

    //Alloc
    unit->omni_ugen = Omni_UGenAlloc();

    //Set starting input values for params
    for(int i = 0; i < NUM_PARAMS; i++)
    {
        int param_index = params_indices[i];
        float in_val = unit->mInBuf[param_index][0];
        const char* param_name = params_names[i].c_str();
        Omni_UGenSetParam(unit->omni_ugen, param_name, in_val);
    }
    
    //Initialize
    bool omni_initialized = Omni_UGenInit(
        unit->omni_ugen,
        unit->mWorld->mBufLength, 
        unit->mWorld->mSampleRate, 
        (void*)unit->mWorld
    );

    if(!omni_initialized)
        unit->omni_ugen = nullptr;
        
    if(unit->omni_ugen)
    {
        SETCALC(Omni_PROTO_next);
        Omni_PROTO_next(unit, 1);
    }
    else
    {
        SETCALC(Omni_PROTO_silence_next);
        Omni_PROTO_silence_next(unit, 1);
    }
}

void Omni_PROTO_Dtor(Omni_PROTO* unit) 
{
    if(unit->omni_ugen)
        Omni_UGenFree(unit->omni_ugen);
}

void Omni_PROTO_next(Omni_PROTO* unit, int inNumSamples) 
{
    Omni_UGenPerform32(
        unit->omni_ugen, 
        unit->mInBuf, 
        unit->mOutBuf, 
        inNumSamples
    );
}

void Omni_PROTO_silence_next(Omni_PROTO* unit, int inNumSamples)
{
    for(int i = 0; i < unit->mNumOutputs; i++)
    {
        for(int y = 0; y < inNumSamples; y++)
            unit->mOutBuf[i][y] = 0.0f;
    }
}

PluginLoad(Omni_PROTOUGens) 
{
    ft = inTable; 
    DefineDtorCantAliasUnit(Omni_PROTO);
}
"""