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

var OMNI_PROTO_CMAKE = """
set(FILENAME "Omni_PROTO.cpp")
cmake_minimum_required (VERSION 3.0)
get_filename_component(PROJECT ${FILENAME} NAME_WE)

#Needed for generic OSX builds. MacOS 10.10 is the minimum.
set(CMAKE_OSX_DEPLOYMENT_TARGET "10.10" CACHE STRING "Minimum OS X deployment version")

#Define project
project (${PROJECT})

message(STATUS "Build dir: ${OMNI_BUILD_DIR}")

#Include build dir for omni.h. OMNI_BUILD_DIR also contains the compiled static lib (linked later in target_link_libraries)
include_directories(${OMNI_BUILD_DIR})

#SC includes
include_directories(${SC_PATH}/include/plugin_interface)
include_directories(${SC_PATH}/include/common)
include_directories(${SC_PATH}/common)

#Supernova includes
option(SUPERNOVA "Build plugins for supernova" OFF)
if (SUPERNOVA)
    include_directories(${SC_PATH}/external_libraries/nova-tt)
    # actually just boost.atomic
    include_directories(${SC_PATH}/external_libraries/boost)
    include_directories(${SC_PATH}/external_libraries/boost_lockfree)
    include_directories(${SC_PATH}/external_libraries/boost-lockfree)
endif()

#Compiled UGen suffix
set(CMAKE_SHARED_MODULE_PREFIX "")
if(APPLE OR WIN32)
    set(CMAKE_SHARED_MODULE_SUFFIX ".scx")
endif()

#CPP11
option(CPP11 "Build with c++11." ON)
set (CMAKE_CXX_STANDARD 11)

#Set release build type as default
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
endif()

#Set Clang on OSX
if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
	set(CMAKE_COMPILER_IS_CLANG 1)
endif()

#Should all these C flags be disabled for generic builds???
if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_COMPILER_IS_CLANG)
    add_definitions(-fvisibility=hidden)

    include (CheckCCompilerFlag)
    include (CheckCXXCompilerFlag)

    CHECK_C_COMPILER_FLAG(-msse HAS_SSE)
    CHECK_CXX_COMPILER_FLAG(-msse HAS_CXX_SSE)

    if (HAS_SSE)
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -msse")
    endif()
    if (HAS_CXX_SSE)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -msse")
    endif()

    CHECK_C_COMPILER_FLAG(-msse2 HAS_SSE2)
    CHECK_CXX_COMPILER_FLAG(-msse2 HAS_CXX_SSE2)

    if (HAS_SSE2)
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -msse2")
    endif()
    if (HAS_CXX_SSE2)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -msse2")
    endif()

    CHECK_C_COMPILER_FLAG(-mfpmath=sse HAS_FPMATH_SSE)
    CHECK_CXX_COMPILER_FLAG(-mfpmath=sse HAS_CXX_FPMATH_SSE)

    if (HAS_FPMATH_SSE)
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfpmath=sse")
    endif()
    if (HAS_CXX_FPMATH_SSE)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mfpmath=sse")
    endif()

    if(CPP11)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
        if(CMAKE_COMPILER_IS_CLANG)
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")
        endif()
    endif()
endif()

#Windows build.
if(MINGW)
    set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS} -mstackrealign")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mstackrealign")
endif()

#Set optimizer flags
set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS}   -O3 -DNDEBUG")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -DNDEBUG")
set(CMAKE_C_FLAGS_RELEASE   "${CMAKE_C_FLAGS_RELEASE}   -O3 -DNDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3 -DNDEBUG")

#Build architecture... if not none, pass the flags through
message(STATUS "BUILD ARCHITECTURE : ${BUILD_MARCH}")
if (NOT BUILD_MARCH STREQUAL "none")
    add_definitions(-march=${BUILD_MARCH})
    set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS} -march=${BUILD_MARCH}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=${BUILD_MARCH}")
    set(CMAKE_C_FLAGS_RELEASE   "${CMAKE_C_FLAGS_RELEASE} -march=${BUILD_MARCH}")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -march=${BUILD_MARCH}")
endif()

#If native, also add mtune=native
if (BUILD_MARCH STREQUAL "native")
    set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS} -mtune=native")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mtune=native")
    set(CMAKE_C_FLAGS_RELEASE   "${CMAKE_C_FLAGS_RELEASE} -mtune=native")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -mtune=native")
    add_definitions(-mtune=native)
endif()

#Declare the new UGen shared lib to build
add_library(${PROJECT} MODULE ${FILENAME})

#Linker flags for scsynth UGen
target_link_libraries(${PROJECT} "-fPIC -L'${OMNI_BUILD_DIR}' -l${PROJECT}")

if(SUPERNOVA)
    #Declare the new supernova UGen shared lib to build
    add_library(${PROJECT}_supernova MODULE ${FILENAME})
    
    #Add all the supernova definitions
    set_property(TARGET ${PROJECT}_supernova
                 PROPERTY COMPILE_DEFINITIONS SUPERNOVA)
    
    #Linker flags for supernova UGen
    target_link_libraries(${PROJECT}_supernova "-fPIC -L'${OMNI_BUILD_DIR}' -l${PROJECT}_supernova")
endif()
"""
