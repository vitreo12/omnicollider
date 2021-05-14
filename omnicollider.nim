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

template printError(msg : string) : untyped =
    setForegroundColor(fgRed)
    writeStyled("ERROR: ", {styleBright}) 
    setForegroundColor(fgWhite, true)
    writeStyled(msg & "\n")

template printDone(msg : string) : void =
    setForegroundColor(fgGreen)
    writeStyled("\nSUCCESS: ", {styleBright}) 
    setForegroundColor(fgWhite, true)
    writeStyled(msg & "\n")

proc omnicollider_single_file(is_multi : bool = false, fileFullPath : string, outDir : string = "", scPath : string = "", architecture : string = "native", supernova : bool = true, removeBuildFiles : bool = true) : int =

    #Check if file exists
    if not fileFullPath.fileExists():
        printError($fileFullPath & " does not exist.")
        return 1
    
    var 
        omniFile     = splitFile(fileFullPath)
        omniFileDir  = omniFile.dir
        omniFileName = omniFile.name
        omniFileExt  = omniFile.ext
    
    #Check file first charcter, must be a capital letter
    if not omniFileName[0].isUpperAscii:
        omniFileName[0] = omniFileName[0].toUpperAscii()

    #Check file extension
    if not(omniFileExt == ".omni") and not(omniFileExt == ".oi"):
        printError($fileFullPath & " is not an Omni file.")
        return 1

    var expanded_sc_path : string

    if scPath == "":
        expanded_sc_path = default_sc_path
    else:
        expanded_sc_path = scPath

    expanded_sc_path = expanded_sc_path.normalizedPath().expandTilde().absolutePath()
    
    #Check scPath
    if not expanded_sc_path.dirExists():
        printError("scPath: " & $expanded_sc_path & " does not exist.")
        return 1
    
    var expanded_out_dir : string

    if outDir == "":
        expanded_out_dir = default_extensions_path
    else:
        expanded_out_dir = outDir

    expanded_out_dir = expanded_out_dir.normalizedPath().expandTilde().absolutePath()

    #Check outDir
    if not expanded_out_dir.dirExists():
        printError("outDir: " & $expanded_out_dir & " does not exist.")
        return 1
    
    #x86_64 and amd64 are aliases for x86-64
    var real_architecture = architecture
    if real_architecture == "x86_64" or real_architecture == "amd64":
        real_architecture = "x86-64"

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

    #Compile omni file 
    let omni_command = "omni \"" & $fileFullPath & "\" --silent:true --architecture:" & $real_architecture & " --lib:static --wrapper:omnicollider_lang --performBits:32 --define:omni_locks_disable --define:omni_buffers_disable_multithreading --exportIO:true --outDir:\"" & $fullPathToNewFolder & "\""

    #Windows requires powershell to figure out the .nimble path...
    when defined(Windows):
        let failedOmniCompilation = execShellCmd(omni_command)
    else:
        let failedOmniCompilation = execCmd(omni_command)

    #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
    if failedOmniCompilation > 0:
        removeDir(fullPathToNewFolder)
        if is_multi:
            printError("Failed compilation of '" & omniFileName & omniFileExt & "'.")
        return 1
    
    #Also for supernova
    if supernova:
        #supernova gets passed both supercollider (which turns on the rt_alloc) and supernova (for buffer handling) flags
        var omni_command_supernova = "omni \"" & $fileFullPath & "\" --silent:true --architecture:" & $real_architecture & " --lib:static --outName:" & $omniFileName & "_supernova --wrapper:omnicollider_lang --performBits:32 --define:omni_locks_disable --define:supernova --exportIO:true --outDir:\"" & $fullPathToNewFolder & "\""
        
        #Windows requires powershell to figure out the .nimble path... go figure!
        when defined(Windows):
            let failedOmniCompilation_supernova = execShellCmd(omni_command_supernova)
        else:
            let failedOmniCompilation_supernova = execCmd(omni_command_supernova)
        
        #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
        if failedOmniCompilation_supernova > 0:
            removeDir(fullPathToNewFolder)
            if is_multi:
                printError("Failed compilation of '" & omniFileName & omniFileExt & "'.")
            return 1
    
    # ================ #
    #  RETRIEVE I / O  #
    # ================ #
    
    let 
        fullPathToIOFile = fullPathToNewFolder & "/" & omniFileName & "_io.txt"
        io_file = readFile(fullPathToIOFile)
        io_file_seq = io_file.split('\n')

    if io_file_seq.len != 11:
        printError("Invalid io file: " & fullPathToIOFile & ".")
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

    var num_inputs_buffers_params = num_inputs

    #Check for 0 inputs, cleanup the entries ("NIL" and 0)
    if num_inputs == 0:
        inputs_names.del(0)
        inputs_defaults.del(0)

    #Do this check cause no buffers == "NIL", don't wanna add that
    if num_buffers > 0:
        num_inputs_buffers_params += num_buffers
        inputs_names.add(buffers_names)
    
    #Do this check cause no params == "NIL", don't wanna add that
    if num_params > 0:
        num_inputs_buffers_params += num_params
        inputs_names.add(params_names)
        inputs_defaults.add(params_defaults)

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

    if num_inputs_buffers_params == 0:
        multiNew_string.add(");")
    else:
        arg_string.add("arg ")
        multiNew_string.add(",")
        for index, input_name in inputs_names:
            var 
                default_val : string
                is_param  = false
                is_buffer = false

            #buffer
            if index >= num_inputs and index < num_inputs + num_buffers:
                is_buffer = true
                default_val = "0"
            
            #param
            elif index >= num_inputs + num_buffers:
                PARAMS_INDICES_CPP.add($index & ",")
                PARAMS_NAMES_CPP.add("\"" & $input_name & "\",")
                is_param    = true
                default_val = inputs_defaults[index - num_buffers]

            #ins
            else:
                default_val = inputs_defaults[index]

            if is_param:
                arg_rates.add("if(" & $input_name & ".rate == 'audio', { ((this.class).asString.replace(\"Meta_\", \"\") ++ \": expected argument \'" & $input_name & "\' to be at control rate. Wrapping it in a A2K.kr UGen.\").warn; " & $input_name & " = A2K.kr(" & $input_name & "); });\n\t\t")
            elif is_buffer:
                arg_rates.add("if(" & $input_name & ".class != Buffer, { if(" & $input_name & ".rate == 'audio', { ((this.class).asString.replace(\"Meta_\", \"\") ++ \": expected argument \'" & $input_name & "\' to be at control rate. Wrapping it in a A2K.kr UGen.\").warn; " & $input_name & " = A2K.kr(" & $input_name & "); }) });\n\t\t")
            else:
                arg_rates.add("if(" & $input_name & ".rate != 'audio', { ((this.class).asString.replace(\"Meta_\", \"\") ++ \": expected argument \'" & $input_name & "\' to be at audio rate. Wrapping it in a K2A.ar UGen.\").warn; " & $input_name & " = K2A.ar(" & $input_name & "); });\n\t\t")

            if index == num_inputs_buffers_params - 1:
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
        sc_cmake_cmd = "cmake -G \"MinGW Makefiles\" -DCMAKE_MAKE_PROGRAM:PATH=\"make\" -DOMNI_BUILD_DIR=\"" & $fullPathToNewFolder_Unix & "\" -DSC_PATH=\"" & $expanded_sc_path & "\" -DSUPERNOVA=" & $supernova_on_off & " -DCMAKE_BUILD_TYPE=Release -DBUILD_MARCH=" & $real_architecture & " .."
    else:
        sc_cmake_cmd = "cmake -DOMNI_BUILD_DIR=\"" & $fullPathToNewFolder & "\" -DSC_PATH=\"" & $expanded_sc_path & "\" -DSUPERNOVA=" & $supernova_on_off & " -DCMAKE_BUILD_TYPE=Release -DBUILD_MARCH=" & $real_architecture & " .."
        
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
    let compilation_cmd = "cmake --build . --config Release"
    when defined(Windows):
        let failedSCCompilation = execShellCmd(compilation_cmd) #execCmd doesn't work on Windows (since it wouldn't go through the powershell)
    else:
        let failedSCCompilation = execCmd(compilation_cmd)
        
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

    printDone("The '" & $omniFileName & "' UGen has been correctly built and installed in \"" & $expanded_out_dir & "\".")

    return 0

proc omnicollider(files : seq[string], outDir : string = "", scPath : string = "", architecture : string = "native", supernova : bool = true, removeBuildFiles : bool = true) : int =
    #no files provided, print --version
    if files.len == 0:
        echo version_flag
        return 0

    for omniFile in files:
        #Get full extended path
        let omniFileFullPath = omniFile.normalizedPath().expandTilde().absolutePath()

        #if just one file in CLI, also pass the outName flag
        if omniFileFullPath.fileExists():
            if files.len == 1:
                return omnicollider_single_file(false, omniFileFullPath, outDir, scPath, architecture, supernova, removeBuildFiles):
            else:
                if omnicollider_single_file(true, omniFileFullPath, outDir, scPath, architecture, supernova, removeBuildFiles) > 0:
                    return 1

        #If it's a dir, compile all .omni/.oi files in it
        elif omniFileFullPath.dirExists():
            for kind, dirFile in walkDir(omniFileFullPath):
                if kind == pcFile:
                    let 
                        dirFileFullPath = dirFile.normalizedPath().expandTilde().absolutePath()
                        dirFileExt = dirFileFullPath.splitFile().ext
                    
                    if dirFileExt == ".omni" or dirFileExt == ".oi":
                        if omnicollider_single_file(true, dirFileFullPath, outDir, scPath, architecture, supernova, removeBuildFiles) > 0:
                            return 1

        else:
            printError($omniFileFullPath & " does not exist.")
            return 1
    
    return 0

#Workaround to pass custom version
clCfg.version = version_flag
 
#Remove --help-syntax
clCfg.helpSyntax = ""

#Arguments string
let arguments = "Arguments:\n  Omni file(s) or folder."

#Ignore clValType
clCfg.hTabCols = @[ clOptKeys, #[clValType,]# clDflVal, clDescrip ]

#Dispatch the omnicollider function as the CLI one
dispatch(
    omnicollider, 
    
    #Remove "Usage: ..."
    noHdr = true,
    
    #Custom options printing
    usage = version_flag & "\n\n" & arguments & "\n\nOptions:\n$options",
    
    short = {
        "version" : 'v',
        "scPath" : 'p',
        "supernova" : 's'
    }, 
    
    help = { 
        "help" : "CLIGEN-NOHELP",
        "version" : "CLIGEN-NOHELP",
        "outDir" : "Output directory. Defaults to SuperCollider's 'Platform.userExtensionDir': \"" & $default_extensions_path & "\".",
        "scPath" : "Path to the SuperCollider source code folder. Defaults to the one in OmniCollider's dependencies: \"" & $default_sc_path & "\".", 
        "architecture" : "Build architecture.",
        "supernova" : "Build with supernova support.",
        "removeBuildFiles" : "Remove all source files used for compilation from outDir."        
    }
)
