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

import cligen, terminal, os, strutils

when not defined(Windows):
    import osproc

#Package version is passed as argument when building. It will be constant and set correctly
const 
    NimblePkgVersion {.strdefine.} = ""
    omnicollider_ver = NimblePkgVersion

#-v / --version
let version_flag = "OmniCollider - version " & $omnicollider_ver & "\n(c) 2020-2021 Francesco Cameli"

#Default to the omni nimble folder, which should have it installed if omni has been installed correctly
const default_sc_path = "~/.nimble/pkgs/omnicollider-" & omnicollider_ver & "/omnicolliderpkg/deps/supercollider"

when defined(Linux):
    const
        default_extensions_path = "~/.local/share/SuperCollider/Extensions"
        ugen_extension          = ".so"
        lib_prepend             = "lib"
        static_lib_extension    = ".a"

when defined(MacOSX) or defined(MacOS):
    const 
        default_extensions_path = "~/Library/Application Support/SuperCollider/Extensions"
        ugen_extension          = ".scx"
        lib_prepend            = "lib"
        static_lib_extension   = ".a"

when defined(Windows):
    const 
        default_extensions_path = "~\\AppData\\Local\\SuperCollider\\Extensions"
        ugen_extension          = ".scx"
        lib_prepend             = ""
        static_lib_extension    = ".lib"

proc printError(msg : string) : void =
    setForegroundColor(fgRed)
    writeStyled("ERROR [omnicollider]: ", {styleBright}) 
    setForegroundColor(fgWhite, true)
    writeStyled(msg & "\n")

proc printDone(msg : string) : void =
    setForegroundColor(fgGreen)
    writeStyled("DONE [omnicollider]: ", {styleBright}) 
    setForegroundColor(fgWhite, true)
    writeStyled(msg & "\n")

proc omnicollider_single_file(fileFullPath : string, supernova : bool = true, architecture : string = "native", outDir : string = default_extensions_path, scPath : string = default_sc_path, removeBuildFiles : bool = true) : int =

    #Check if file exists
    if not fileFullPath.fileExists():
        printError($fileFullPath & " does not exist.")
        return 1
    
    var 
        omniFile     = splitFile(fileFullPath)
        omniFileDir  = omniFile.dir
        omniFileName = omniFile.name
        omniFileExt  = omniFile.ext
    
    let originalOmniFileName = omniFileName

    #Check file first charcter, must be a capital letter
    if not omniFileName[0].isUpperAscii:
        omniFileName[0] = omniFileName[0].toUpperAscii()

    #Check file extension
    if not(omniFileExt == ".omni") and not(omniFileExt == ".oi"):
        printError($fileFullPath & " is not an omni file.")
        return 1

    let expanded_sc_path = scPath.normalizedPath().expandTilde().absolutePath()

    #Check scPath
    if not expanded_sc_path.dirExists():
        printError("scPath: " & $expanded_sc_path & " does not exist.")
        return 1
    
    let expanded_out_dir = outDir.normalizedPath().expandTilde().absolutePath()

    #Check outDir
    if not expanded_out_dir.dirExists():
        printError("outDir: " & $expanded_out_dir & " does not exist.")
        return 1

    #Full paths to the new file in omniFileName directory
    let 
        #New folder named with the name of the Omni file
        fullPathToNewFolder = $omniFileDir & "/" & $omniFileName

        #This is to use in shell cmds instead of fullPathToNewFolder, expands spaces to "\ "
        #fullPathToNewFolderShell = fullPathToNewFolder.replace(" ", "\\ ")

        #This is the Omni file copied to the new folder
        fullPathToOmniFile   = $fullPathToNewFolder & "/" & $omniFileName & $omniFileExt

        #These are the .cpp, .sc and cmake files in new folder
        fullPathToCppFile   = $fullPathToNewFolder & "/" & $omniFileName & ".cpp"
        fullPathToSCFile    = $fullPathToNewFolder & "/" & $omniFileName & ".sc" 
        fullPathToCMakeFile = $fullPathToNewFolder & "/" & "CMakeLists.txt"

        #These are the paths to the generated static libraries
        fullPathToStaticLib = $fullPathToNewFolder & "/" & $lib_prepend & $omniFileName & $static_lib_extension
        fullPathToStaticLib_supernova = $fullPathToNewFolder & "/" & $lib_prepend & $omniFileName & "_supernova" & $static_lib_extension
    
    #Create directory in same folder as .omni file
    removeDir(fullPathToNewFolder)
    createDir(fullPathToNewFolder)

    #Copy omniFile to folder
    copyFile(fileFullPath, fullPathToOmniFile)

    # ================= #
    # COMPILE OMNI FILE #
    # ================= #

    #Compile omni file. Only pass the -d:omnicli and -d:tempDir flag here, so it generates the IO.txt file.
    let omni_command = "omni \"" & $fileFullPath & "\" --architecture:" & $architecture & " --lib:static --wrapper:omnicollider_lang --performBits:32 --define:omni_locks_disable --define:omni_buffers_disable_multithreading --exportIO:true --outDir:\"" & $fullPathToNewFolder & "\""

    #Windows requires powershell to figure out the .nimble path... go figure!
    when defined(Windows):
        let failedOmniCompilation = execShellCmd(omni_command)
    else:
        let failedOmniCompilation = execCmd(omni_command)

    #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
    if failedOmniCompilation > 0:
        printError("Unsuccessful compilation of " & $originalOmniFileName & $omniFileExt & ".")
        removeDir(fullPathToNewFolder)
        return 1
    
    #Also for supernova
    if supernova:
        #supernova gets passed both supercollider (which turns on the rt_alloc) and supernova (for buffer handling) flags
        var omni_command_supernova = "omni \"" & $fileFullPath & "\" --architecture:" & $architecture & " --lib:static --outName:" & $omniFileName & "_supernova --wrapper:omnicollider_lang --performBits:32 --define:omni_locks_disable --define:supernova --outDir:\"" & $fullPathToNewFolder & "\""
        
        #Windows requires powershell to figure out the .nimble path... go figure!
        when defined(Windows):
            let failedOmniCompilation_supernova = execShellCmd(omni_command_supernova)
        else:
            let failedOmniCompilation_supernova = execCmd(omni_command_supernova)
        
        #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
        if failedOmniCompilation_supernova > 0:
            printError("Unsuccessful supernova compilation of " & $originalOmniFileName & $omniFileExt & ".")
            removeDir(fullPathToNewFolder)
            return 1
    
    # ================ #
    #  RETRIEVE I / O  #
    # ================ #
    
    let 
        fullPathToIOFile = fullPathToNewFolder & "/omni_io.txt"
        io_file = readFile(fullPathToIOFile)
        io_file_seq = io_file.split('\n')

    if io_file_seq.len != 11:
        printError("Invalid omni_io.txt file.")
        removeDir(fullPathToNewFolder)
        return 1
    
    var 
        num_inputs  = parseInt(io_file_seq[0])     
        inputs_names_string = io_file_seq[1]
        inputs_names = inputs_names_string.split(',')
        inputs_defaults_string = io_file_seq[2]
        inputs_defaults = inputs_defaults_string.split(',')
        num_params = parseInt(io_file_seq[3])
        params_names_string = io_file_seq[4]
        params_names = params_names_string.split(',')
        params_defaults_string = io_file_seq[5]
        params_defaults = params_defaults_string.split(',')
        num_buffers = parseInt(io_file_seq[6])
        buffers_names_string = io_file_seq[7]
        buffers_names = buffers_names_string.split(',')
        num_outputs = parseInt(io_file_seq[9])

    #Merge inputs with buffers and params

    #Do this check cause no params == "NIL", don't wanna add that
    if num_params > 0:
        num_inputs += num_params
        inputs_names.add(params_names)
        inputs_defaults.add(params_defaults)
    
    #Do this check cause no buffers == "NIL", don't wanna add that
    if num_buffers > 0:
        num_inputs += num_buffers
        inputs_names.add(buffers_names)
    
    # ======== #
    # SC I / O #
    # ======== #
    
    var 
        #SC
        arg_string = ""
        arg_rates = ""
        multiNew_string = "^this.multiNew('audio'"
        multiOut_string = ""

        #CPP
        NUM_PARAMS_CPP     = "#define NUM_PARAMS " & $num_params
        PARAMS_INDICES_CPP = "const std::array<int,NUM_PARAMS> params_indices = { "
        PARAMS_NAMES_CPP   = "const std::array<std::string,NUM_PARAMS> params_names = { "

    if num_inputs == 0:
        multiNew_string.add(");")
    else:
        arg_string.add("arg ")
        multiNew_string.add(",")
        for index, input_name in inputs_names:
            var 
                default_val : string
                is_param  = false
                is_buffer = false

            #ins and params, num_inputs is (num_inputs + num_params + num_buffers)
            if index < (num_inputs - num_buffers):
                default_val = inputs_defaults[index]

                if index >= (num_inputs - num_params - num_buffers):
                    PARAMS_INDICES_CPP.add($index & ",")
                    PARAMS_NAMES_CPP.add("\"" & $input_name & "\",")
                    is_param = true

            #buffers default to 0
            else:
                is_buffer   = true
                default_val = "0"

            if is_param or is_buffer:
                arg_rates.add("if(" & $input_name & ".rate == 'audio', { ((this.class).asString.replace(\"Meta_\", \"\") ++ \": expected argument \'" & $input_name & "\' to be at control rate. Wrapping it in a A2K.kr UGen.\").warn; " & $input_name & " = A2K.kr(" & $input_name & "); });\n\t\t")
            else:
                arg_rates.add("if(" & $input_name & ".rate != 'audio', { ((this.class).asString.replace(\"Meta_\", \"\") ++ \": expected argument \'" & $input_name & "\' to be at audio rate. Wrapping it in a K2A.ar UGen.\").warn; " & $input_name & " = K2A.ar(" & $input_name & "); });\n\t\t")

            if index == num_inputs - 1:
                arg_string.add($input_name & "=(" & $default_val & ");")
                multiNew_string.add($input_name & ");")
                break

            arg_string.add($input_name & "=(" & $default_val & "), ")
            multiNew_string.add($input_name & ", ")
                
    PARAMS_INDICES_CPP.removeSuffix(',')
    PARAMS_NAMES_CPP.removeSuffix(',')
    PARAMS_INDICES_CPP.add(" };")
    PARAMS_NAMES_CPP.add(" };")

    #These are the files to overwrite! Need them at every iteration (when compiling multiple files or a folder)
    include "omnicolliderpkg/Static/Omni_PROTO.cpp.nim"
    include "omnicolliderpkg/Static/CMakeLists.txt.nim"
    include "omnicolliderpkg/Static/Omni_PROTO.sc.nim"
    
    OMNI_PROTO_SC = OMNI_PROTO_SC.replace("//args", arg_string)
    OMNI_PROTO_SC = OMNI_PROTO_SC.replace("//rates", arg_rates)
    OMNI_PROTO_SC = OMNI_PROTO_SC.replace("//multiNew", multiNew_string)

    #Multiple outputs UGen
    if num_outputs > 1:
        multiOut_string = "init { arg ... theInputs;\n\t\tinputs = theInputs;\n\t\t^this.initOutputs(" & $num_outputs & ", rate);\n\t}"
        OMNI_PROTO_SC = OMNI_PROTO_SC.replace("//multiOut", multiOut_string)
        OMNI_PROTO_SC = OMNI_PROTO_SC.replace(" : UGen", " : MultiOutUGen")
    
    #Replace Omni_PROTO with the name of the Omni file
    OMNI_PROTO_CPP   = OMNI_PROTO_CPP.replace("Omni_PROTO", omniFileName)
    OMNI_PROTO_SC    = OMNI_PROTO_SC.replace("Omni_PROTO", omniFileName)
    OMNI_PROTO_CMAKE = OMNI_PROTO_CMAKE.replace("Omni_PROTO", omniFileName)

    #Chain the file together with all correct infos too
    OMNI_PROTO_CPP = $OMNI_PROTO_INCLUDES & "\n" & $NUM_PARAMS_CPP & "\n" & $PARAMS_INDICES_CPP & "\n" & PARAMS_NAMES_CPP & "\n" & "\n" & $OMNI_PROTO_CPP
    
    # =========== #
    # WRITE FILES #
    # =========== #

    #Create .ccp/.sc/cmake files in the new folder
    let
        cppFile   = open(fullPathToCppFile, fmWrite)
        scFile    = open(fullPathToSCFile, fmWrite)
        cmakeFile = open(fullPathToCMakeFile, fmWrite)

    cppFile.write(OMNI_PROTO_CPP)
    scFile.write(OMNI_PROTO_SC)
    cmakeFile.write(OMNI_PROTO_CMAKE)

    cppFile.close
    scFile.close
    cmakeFile.close

    # ========== #
    # BUILD UGEN #
    # ========== #

    #Create build folder
    removeDir($fullPathToNewFolder & "/build")
    createDir($fullPathToNewFolder & "/build")
    
    var 
        supernova_on_off = "OFF"
        sc_cmake_cmd : string

    if supernova:
        supernova_on_off = "ON"
    
    when defined(Windows):
        #Cmake wants a path in unix style, not windows! Replace "/" with "\"
        let fullPathToNewFolder_Unix = fullPathToNewFolder.replace("\\", "/")
        sc_cmake_cmd = "cmake -G \"MinGW Makefiles\" -DOMNI_BUILD_DIR=\"" & $fullPathToNewFolder_Unix & "\" -DSC_PATH=\"" & $expanded_sc_path & "\" -DSUPERNOVA=" & $supernova_on_off & " -DCMAKE_BUILD_TYPE=Release -DBUILD_MARCH=" & $architecture & " .."
    else:
        sc_cmake_cmd = "cmake -DOMNI_BUILD_DIR=\"" & $fullPathToNewFolder & "\" -DSC_PATH=\"" & $expanded_sc_path & "\" -DSUPERNOVA=" & $supernova_on_off & " -DCMAKE_BUILD_TYPE=Release -DBUILD_MARCH=" & $architecture & " .."
        
    #cd into the build directory
    setCurrentDir(fullPathToNewFolder & "/build")
    
    #Execute CMake
    when defined(Windows):
        let failedSCCmake = execShellCmd(sc_cmake_cmd)
    else:
        let failedSCCmake = execCmd(sc_cmake_cmd)

    #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
    if failedSCCmake > 0:
        printError("Unsuccessful cmake generation of the UGen file \"" & $omniFileName & ".cpp\".")
        removeDir(fullPathToNewFolder)
        return 1

    #make command
    when defined(Windows):
        let 
            sc_compilation_cmd  = "mingw32-make"
            #sc_compilation_cmd = "cmake --build . --config Release"
            failedSCCompilation = execShellCmd(sc_compilation_cmd) #execCmd doesn't work on Windows (since it wouldn't go through the powershell)
    else:
        let 
            sc_compilation_cmd = "make"
            #sc_compilation_cmd = "cmake --build . --config Release"  #https://scsynth.org/t/update-to-build-instructions-for-sc3-plugins/2671
            failedSCCompilation = execCmd(sc_compilation_cmd)
        
    
    #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
    if failedSCCompilation > 0:
        printError("Unsuccessful compilation of the UGen file \"" & $omniFileName & ".cpp\".")
        removeDir(fullPathToNewFolder)
        return 1
    
    #cd back to the original folder where omni file is
    setCurrentDir(omniFileDir)

    # ========================= #
    # COPY TO EXTENSIONS FOLDER #
    # ========================= #
    copyFile($fullPathToNewFolder & "/build/" & $omniFileName & $ugen_extension, $fullPathToNewFolder & "/" & $omniFileName & $ugen_extension)
    if supernova:
        copyFile($fullPathToNewFolder & "/build/" & $omniFileName & "_supernova" & $ugen_extension, $fullPathToNewFolder & "/" & $omniFileName & "_supernova" & $ugen_extension)

    #Remove build dir
    removeDir(fullPathToNewFolder & "/build")
    
    #If removeBuildFiles, remove all sources and static libraries compiled
    if removeBuildFiles:
        let fullPathToOmniHeaderFile = fullPathToNewFolder & "/omni.h"

        removeFile(fullPathToOmniHeaderFile)
        removeFile(fullPathToCppFile)
        removeFile(fullPathToOmniFile)
        removeFile(fullPathToCMakeFile)
        removeFile(fullPathToIOFile)
        removeFile(fullPathToStaticLib)
        if supernova:
            removeFile(fullPathToStaticLib_supernova)

    #Copy to extensions folder
    let fullPathToNewFolderInOutDir = $expanded_out_dir  & "/" & omniFileName
    
    #Remove temp folder used for compilation only if it differs from outDir (otherwise, it's gonna delete the actual folder)
    if fullPathToNewFolderInOutDir != fullPathToNewFolder:
        #Remove previous folder in outDir if there was, then copy the new one over, then delete the temporary one
        removeDir(fullPathToNewFolderInOutDir)
        copyDir(fullPathToNewFolder, fullPathToNewFolderInOutDir)
        removeDir(fullPathToNewFolder)

    printDone("The " & $omniFileName & " UGen has been correctly built and installed in \"" & $expanded_out_dir & "\".")

    return 0

proc omnicollider(files : seq[string], supernova : bool = true, architecture : string = "native", outDir : string = default_extensions_path, scPath : string = default_sc_path, removeBuildFiles : bool = true) : int =
    #no files provided, print --version
    if files.len == 0:
        echo version_flag
        return 0

    for omniFile in files:
        #Get full extended path
        let omniFileFullPath = omniFile.normalizedPath().expandTilde().absolutePath()

        #If it's a file, compile it
        if omniFileFullPath.fileExists():
            if omnicollider_single_file(omniFileFullPath, supernova, architecture, outDir, scPath, removeBuildFiles) > 0:
                return 1

        #If it's a dir, compile all .omni/.oi files in it
        elif omniFileFullPath.dirExists():
            for kind, dirFile in walkDir(omniFileFullPath):
                if kind == pcFile:
                    let 
                        dirFileFullPath = dirFile.normalizedPath().expandTilde().absolutePath()
                        dirFileExt = dirFileFullPath.splitFile().ext
                    
                    if dirFileExt == ".omni" or dirFileExt == ".oi":
                        if omnicollider_single_file(dirFileFullPath, supernova, architecture, outDir, scPath, removeBuildFiles) > 0:
                            return 1

        else:
            printError($omniFileFullPath & " does not exist.")
            return 1
    
    return 0

#Workaround to pass custom version
clCfg.version = version_flag

#Dispatch the omnicollider function as the CLI one
dispatch(omnicollider, 
    short={
        "version" : 'v',
        "scPath" : 'p',
        "supernova" : 's'
    }, 
    
    help={ 
        "supernova" : "Build with supernova support.",
        "architecture" : "Build architecture.",
        "outDir" : "Output directory. Defaults to SuperCollider's \"Platform.userExtensionDir\".",
        "scPath" : "Path to the SuperCollider source code folder. Defaults to the one in omnicollider's dependencies.", 
        "removeBuildFiles" : "Remove all source files used for compilation from outDir."        
    }
)
