// MIT License
// 
// Copyright (c) 2020 Francesco Cameli
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#include <cstdio>

//Can't include the ones from deps/supercollider/include/plugin_interface, because the #include "SC_Types.h" in SC_World.h would give error
//as it is not in plugin_interface, but in common. Perhaps I could pass a -I flag to the cpp compiler pointing to the common folder. Maybe in the future.
#include "SC_Utilities/SC_World.h"
#include "SC_Utilities/SC_Unit.h"

extern "C"
{
    //Global variable that will live in each Nim module that compiles this "SCBuffer.c" file
    World* SCWorld;

    void init_sc_world(void* inWorld)
    {
        printf("Calling init_world\n");

        if(!inWorld)
            printf("ERROR: Invalid SCWorld\n");

        SCWorld = (World*)inWorld;
    }

    void* get_sc_world()
    {
        return (void*)SCWorld;
    }

    //Called at start of perform (scsynth)
    void* get_buffer_SC(void* buffer_SCWorld, float fbufnum)
    {
        if(!buffer_SCWorld)
            return nullptr;

        World* SCWorld = (World*)buffer_SCWorld;

        uint32 bufnum = (int)fbufnum; 

        //If bufnum is not more that maximum number of buffers in World* it means bufnum doesn't point to a LocalBuf
        if(!(bufnum >= SCWorld->mNumSndBufs))
        {
            SndBuf* buf = SCWorld->mSndBufs + bufnum; 

            if(!buf->data)
            {
                printf("WARNING: Omni: Invalid buffer: %d\n", bufnum);
                return nullptr;
            }

            //If supernova, lock buffer aswell
            #ifdef SUPERNOVA
            ACQUIRE_SNDBUF_SHARED(buf);
            #endif

            return (void*)buf;
        }
        else
        {
            printf("WARNING: Omni: local buffers are not yet supported \n");
            return nullptr;

            //It would require to provide "unit" here (to retrieve parent). Perhaps it can be passed in void* buffer_interface?
        }
    }

    #ifdef SUPERNOVA
    void lock_buffer_SC(void* buf)
    {
        SndBuf* snd_buf = (SndBuf*)buf;
        ACQUIRE_SNDBUF_SHARED(snd_buf);
        return;
    }

    void unlock_buffer_SC(void* buf)
    {
        SndBuf* snd_buf = (SndBuf*)buf;
        RELEASE_SNDBUF_SHARED(snd_buf);
        return;
    }
    #endif

    /* 
        For all these function, the validity of void* buf has already been tested at the start of the perform function!
        
        if isNil(buffer.snd_buf):
            return false
    */
    float get_float_value_buffer_SC(void* buf, long index, long channel)
    {
        SndBuf* snd_buf = (SndBuf*)buf;

        int channels = snd_buf->channels;
                
        long actual_index;

        if (channels== 1)
            actual_index = index;
        else
            actual_index = (index * channels) + channel; //Interleaved data
        
        if(index >= 0 && (actual_index < snd_buf->samples))
            return snd_buf->data[actual_index];

        return 0.f;
    }

    void set_float_value_buffer_SC(void* buf, float value, long index, long channel)
    {
        SndBuf* snd_buf = (SndBuf*)buf;
        
        int channels = snd_buf->channels;
                
        long actual_index;

        if (channels== 1)
            actual_index = index;
        else
            actual_index = (index * channels) + channel; //Interleaved data
        
        if(index >= 0 && (actual_index < snd_buf->samples))
            snd_buf->data[actual_index] = value;
    }

    //Length of each channel
    int get_frames_buffer_SC(void* buf)
    {
        SndBuf* snd_buf = (SndBuf*)buf;
        return snd_buf->frames;
    }

    //Total allocated length
    int get_samples_buffer_SC(void* buf)
    {
        SndBuf* snd_buf = (SndBuf*)buf;
        return snd_buf->samples;
    }

    //Number of channels
    int get_channels_buffer_SC(void* buf)
    {
        SndBuf* snd_buf = (SndBuf*)buf;
        return snd_buf->channels;
    }

    //Samplerate
    double get_samplerate_buffer_SC(void* buf)
    {
        SndBuf* snd_buf = (SndBuf*)buf;
        return snd_buf->samplerate;
    }

    //Sampledur
    /* double get_sampledur_buffer_SC(void* buf)
    {
        SndBuf* snd_buf = (SndBuf*)buf;
        return snd_buf->sampledur;
    } */
}