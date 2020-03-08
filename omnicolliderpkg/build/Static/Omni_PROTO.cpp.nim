var OMNI_PROTO_CPP = """
#include <atomic>

#include "SC_PlugIn.h"

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

    //Initialization function prototypes
    typedef void* alloc_func_t(size_t inSize);
    typedef void* realloc_func_t(void *inPtr, size_t inSize);
    typedef void  free_func_t(void *inPtr);
    typedef int   print_func_t(const char* formatString, ...);

    //Initialization function
    extern  void  Omni_Init(alloc_func_t* alloc_func, realloc_func_t* realloc_func, free_func_t* free_func, print_func_t* print_func);

    //Omni module functions
    extern void* OmniConstructor(float** ins_SC, int bufsize, double samplerate);
    extern void  OmniDestructor(void* obj_void);
    extern void  OmniPerform(void* ugen_void, int buf_size, float** ins_SC, float** outs_SC);
}

//Wrappers around RTAlloc, RTRealloc, RTFree
void* RTAlloc_func(size_t inSize)
{
    Print("Calling RTAlloc_func with size: %d\n", inSize);
    return ft->fRTAlloc(SCWorld, inSize);
}

void* RTRealloc_func(void* inPtr, size_t inSize)
{
    Print("Calling RTRealloc_func with size: %d\n", inSize);
    return ft->fRTRealloc(SCWorld, inPtr, inSize);
}

void RTFree_func(void* inPtr)
{
    Print("Calling RTFree_func\n");
    ft->fRTFree(SCWorld, inPtr);
}

void RTPrint_func(const char* formatString, ...)
{
    ft->fPrint(formatString);
}

//struct
struct Omni_PROTO : public Unit 
{
    void* omni_obj;
};

//DSP functions
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
            if(!(&init_sc_world) || !(&Omni_Init))
                Print("ERROR: No %s%s loaded\n", NAME, EXTENSION);
            else 
            {
                init_sc_world((void*)unit->mWorld);
                SCWorld = unit->mWorld;
                Omni_Init((alloc_func_t*)RTAlloc_func, (realloc_func_t*)RTRealloc_func, (free_func_t*)RTFree_func, (print_func_t*)RTPrint_func);
            }

            //Still init. Things won't change up until next server reboot.
            world_init = true;
        }

        //Release lock
        has_init_world.clear(std::memory_order_release); 
    }

    if(&OmniConstructor && &init_sc_world && &Omni_Init)
        unit->omni_obj = (void*)OmniConstructor(unit->mInBuf, unit->mWorld->mBufLength, unit->mWorld->mSampleRate);
    else
    {
        Print("ERROR: No %s.%s loaded\n", NAME, EXTENSION);
        unit->omni_obj = nullptr;
    }
        
    SETCALC(Omni_PROTO_next);
    
    Omni_PROTO_next(unit, 1);
}

void Omni_PROTO_Dtor(Omni_PROTO* unit) 
{
    if(unit->omni_obj)
        OmniDestructor(unit->omni_obj);
}

void Omni_PROTO_next(Omni_PROTO* unit, int inNumSamples) 
{
    if(unit->omni_obj)
        OmniPerform(unit->omni_obj, inNumSamples, unit->mInBuf, unit->mOutBuf);
    else
    {
        for(int i = 0; i < unit->mNumOutputs; i++)
        {
            for(int y = 0; y < inNumSamples; y++)
                unit->mOutBuf[i][y] = 0.0f;
        }
    }
}

//Rename Omni_PROTO to the name of the Omni file to compile
PluginLoad(Omni_PROTOUGens) 
{
    ft = inTable; 
    DefineDtorUnit(Omni_PROTO);
}
"""