var OMNI_PROTO_CPP = """
#include <atomic>
#include "SC_PlugIn.h"
#include "omni.h"

#define NAME "Omni_PROTO"

#ifdef __APPLE__
    #define EXTENSION ".scx"
#elif __linux__
    #define EXTENSION ".so"
#elif _WIN32
    #define EXTENSION ".scx"
#endif

//Interface table
static InterfaceTable *ft;

//Use an atomic flag so it works for supernova too
std::atomic_flag has_init_world = ATOMIC_FLAG_INIT;
bool world_init = false;

//Initialization functions. Wrapped in C since the Omni lib is exported with C named libraries
extern "C" 
{
    //World pointer. This is declared in SCBuffer.cpp
    extern World* SCWorld;

    //Initialization of World
    extern void init_sc_world(void* inWorld);
}

//Wrappers around RTAlloc, RTRealloc, RTFree
void* RTAlloc_func(size_t in_size)
{
    Print("Calling RTAlloc_func with size: %d\n", in_size);
    return ft->fRTAlloc(SCWorld, in_size);
}

void* RTRealloc_func(void* in_ptr, size_t in_size)
{
    Print("Calling RTRealloc_func with size: %d\n", in_size);
    return ft->fRTRealloc(SCWorld, in_ptr, in_size);
}

void RTFree_func(void* in_ptr)
{
    Print("Calling RTFree_func\n");
    ft->fRTFree(SCWorld, in_ptr);
}

//Wrapper around Print
void RTPrint_func(const char* format_string, ...)
{
    ft->fPrint(format_string);
}

//Wrapper around world->mSampleRate
double getSampleRate_func()
{
    return SCWorld->mSampleRate;
}

//Wrapper around world->mBufLength
int getBufLength_func()
{
    return SCWorld->mBufLength;
}

//SC struct
struct Omni_PROTO : public Unit 
{
    void* omni_ugen;
};

//SC functions
static void Omni_PROTO_next(Omni_PROTO* unit, int inNumSamples);
static void Omni_PROTO_Ctor(Omni_PROTO* unit);
static void Omni_PROTO_Dtor(Omni_PROTO* unit);

void Omni_PROTO_Ctor(Omni_PROTO* unit) 
{
    //Initialization routines for the Omni_PROTO UGen. 
    if(!world_init)
    {
        //Acquire lock
        while(has_init_world.test_and_set(std::memory_order_acquire))
            ; //spin

        //First thread that reaches this will set it for all
        if(!world_init)
        {
            if(!(&init_sc_world) || !(&Omni_InitGlobal))
                Print("ERROR: No %s%s loaded\n", NAME, EXTENSION);
            else 
            {
                //Init SCWorld also in the omni module
                init_sc_world((void*)unit->mWorld);
                
                //Get SCWorld pointer needed for RTAlloc wrappers
                SCWorld = unit->mWorld;
                
                //Init omni with all the function pointers
                Omni_InitGlobal(
                    (omni_alloc_func_t*)RTAlloc_func, 
                    (omni_realloc_func_t*)RTRealloc_func, 
                    (omni_free_func_t*)RTFree_func, 
                    (omni_print_func_t*)RTPrint_func,
                    (omni_get_samplerate_func_t*)getSampleRate_func,
                    (omni_get_bufsize_func_t*)getBufLength_func
                );
            }

            //Still init. Things won't change up until next server reboot.
            world_init = true;
        }

        //Release lock
        has_init_world.clear(std::memory_order_release); 
    }

    if(&Omni_UGenAllocInit32 && &init_sc_world && &Omni_InitGlobal)
        unit->omni_ugen = Omni_UGenAllocInit32(unit->mInBuf, unit->mWorld->mBufLength, unit->mWorld->mSampleRate, (void*)unit->mWorld);
    else
    {
        Print("ERROR: No %s%s loaded\n", NAME, EXTENSION);
        unit->omni_ugen = nullptr;
    }
        
    SETCALC(Omni_PROTO_next);
    
    Omni_PROTO_next(unit, 1);
}

void Omni_PROTO_Dtor(Omni_PROTO* unit) 
{
    if(unit->omni_ugen)
        Omni_UGenFree(unit->omni_ugen);
}

void Omni_PROTO_next(Omni_PROTO* unit, int inNumSamples) 
{
    if(unit->omni_ugen)
        Omni_UGenPerform32(unit->omni_ugen, unit->mInBuf, unit->mOutBuf, inNumSamples);
    else
    {
        for(int i = 0; i < unit->mNumOutputs; i++)
        {
            for(int y = 0; y < inNumSamples; y++)
                unit->mOutBuf[i][y] = 0.0f;
        }
    }
}

PluginLoad(Omni_PROTOUGens) 
{
    ft = inTable; 
    DefineDtorUnit(Omni_PROTO);
}
"""