var OMNI_PROTO_CPP = """

#include <atomic>

#include "SC_PlugIn.h"

#define NAME "Omni_PROTO"

#ifdef __APPLE__
    #define EXTENSION "dylib"
#elif __linux__
    #define EXTENSION "so"
#elif _WIN32
    #define EXTENSION "dll"
#endif

//Interface table
static InterfaceTable *ft;

//Use an atomic flag so it works for supernova too
std::atomic_flag has_init_world = ATOMIC_FLAG_INIT;
bool world_init = false;

//Initialization functions. Wrapped in C since the Nim lib is exported with C named libraries
extern "C" 
{
    //World pointer. This is declared in SCBuffer.cpp
    extern World* SCWorld;

    //Initialization of World
    extern void init_sc_world(void* inWorld);

    //Initialization function prototypes for the real time allocator
    typedef void* alloc_func_t(size_t inSize);
    typedef void* realloc_func_t(void *inPtr, size_t inSize);
    typedef void  free_func_t(void *inPtr);
    extern  void  Omni_Init_Alloc(alloc_func_t* In_RTAlloc, realloc_func_t* In_RTRealloc, free_func_t* In_RTFree);

    //Nim module functions
    extern void* OmniConstructor(float** ins_SC, int bufsize, double samplerate);
    extern void  OmniDestructor(void* obj_void);
    extern void  OmniPerform(void* ugen_void, int buf_size, float** ins_SC, float** outs_SC);
}

//Wrappers around RTAlloc, RTRealloc, RTFree
void* RTAlloc_func(size_t inSize)
{
    printf("Calling RTAlloc_func with size: %d\n", inSize);
    return ft->fRTAlloc(SCWorld, inSize);
}

void* RTRealloc_func(void* inPtr, size_t inSize)
{
    printf("Calling RTRealloc_func with size: %d\n", inSize);
    return ft->fRTRealloc(SCWorld, inPtr, inSize);
}

void RTFree_func(void* inPtr)
{
    printf("Calling RTFree_func\n");
    ft->fRTFree(SCWorld, inPtr);
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
    //Initialization routines for the Nim UGen. 
    if(!world_init)
    {
        //Acquire lock
        while(has_init_world.test_and_set(std::memory_order_acquire))
            ; //spin

        //First thread that reaches this will set it for all
        if(!world_init)
        {
            if(!(&init_sc_world) || !(&Omni_Init_Alloc))
                Print("ERROR: No %s.%s loaded\n", NAME, EXTENSION);
            else 
            {
                init_sc_world((void*)unit->mWorld);
                SCWorld = unit->mWorld;
                Omni_Init_Alloc((alloc_func_t*)RTAlloc_func, (realloc_func_t*)RTRealloc_func, (free_func_t*)RTFree_func);
            }

            //Still init. Things won't change up until next server reboot.
            world_init = true;
        }

        //Release lock
        has_init_world.clear(std::memory_order_release); 
    }

    if(&OmniConstructor && &init_sc_world && &Omni_Init_Alloc)
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

//Rename Omni_PROTO to the name of the nim file to compile
PluginLoad(Omni_PROTOUGens) 
{
    ft = inTable; 
    DefineDtorUnit(Omni_PROTO);
}

"""