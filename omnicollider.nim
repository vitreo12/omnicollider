import cligen, terminal, os, strutils, osproc

include "omnicolliderpkg/Static/Omni_PROTO.cpp.nim"
include "omnicolliderpkg/Static/CMakeLists.txt.nim"
include "omnicolliderpkg/Static/Omni_PROTO.sc.nim"

#Package version is passed as argument when building. It will be constant and set correctly
const 
    NimblePkgVersion {.strdefine.} = ""
    omnicollider_ver = NimblePkgVersion

#Default to the omni nimble folder, which should have it installed if omni has been installed correctly
const default_sc_path = "~/.nimble/pkgs/omnicollider_lang-" & omnicollider_ver & "/omnicollider_lang/deps/supercollider"

#Extension for static lib
const static_lib_extension = ".a"

when defined(Linux):
    const
        default_extensions_path = "~/.local/share/SuperCollider/Extensions"
        ugen_extension = ".so"

when defined(MacOSX) or defined(MacOS):
    const 
        default_extensions_path = "~/Library/Application Support/SuperCollider/Extensions"
        ugen_extension = ".scx"

when defined(Windows):
    const 
        default_extensions_path = "~\\AppData\\Local\\SuperCollider\\Extensions"
        ugen_extension = ".scx"

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

proc omnicollider_single_file(omniFile : string, supernova : bool = false, architecture : string = "native", outDir : string = default_extensions_path, scPath : string = default_sc_path, removeBuildFiles : bool = true) : int =

    let 
        fullPathToFile = omniFile.normalizedPath().expandTilde().absolutePath()
        
        #This is the path to the original nim file to be used in shell.
        #Using this one in nim command so that errors are shown on this one when CTRL+Click on terminal
        #fullPathToOriginalOmniFileShell = fullPathToFile.replace(" ", "\\ ")

    #Check if file exists
    if not fullPathToFile.existsFile():
        printError($fullPathToFile & " does not exist.")
        return 1
    
    var 
        omniFile     = splitFile(fullPathToFile)
        omniFileDir  = omniFile.dir
        omniFileName = omniFile.name
        omniFileExt  = omniFile.ext

    #Check file first charcter, must be a capital letter
    if not omniFileName[0].isUpperAscii:
        omniFileName[0] = omniFileName[0].toUpperAscii()

    #Check file extension
    if not(omniFileExt == ".omni") and not(omniFileExt == ".oi"):
        printError($fullPathToFile & " is not an omni file.")
        return 1

    let expanded_sc_path = scPath.normalizedPath().expandTilde().absolutePath()

    #Check scPath
    if not expanded_sc_path.existsDir():
        printError("scPath: " & $expanded_sc_path & " does not exist.")
        return 1
    
    let expanded_out_dir = outDir.normalizedPath().expandTilde().absolutePath()

    #Check outDir
    if not expanded_out_dir.existsDir():
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
        fullPathToStaticLib = $fullPathToNewFolder & "/lib" & $omniFileName & $static_lib_extension
        fullPathToStaticLib_supernova = $fullPathToNewFolder & "/lib" & $omniFileName & "_supernova" & $static_lib_extension
    
    #Create directory in same folder as .omni file
    removeDir(fullPathToNewFolder)
    createDir(fullPathToNewFolder)

    #Copy omniFile to folder
    copyFile(fullPathToFile, fullPathToOmniFile)

    # ================ #
    # COMPILE NIM FILE #
    # ================ #

    #Compile nim file. Only pass the -d:omnicli and -d:tempDir flag here, so it generates the IO.txt file.
    let omni_command = "omni \"" & $fullPathToFile & "\" -i:omnicollider_lang -l:static -d:writeIO -d:tempDir:\"" & $fullPathToNewFolder & "\" -o:\"" & $fullPathToNewFolder & "\""

    #Windows requires powershell to figure out the .nimble path... go figure!
    when not defined(Windows):
        let failedOmniCompilation = execCmd(omni_command)
    else:
        let failedOmniCompilation = execShellCmd(omni_command)

    #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
    if failedOmniCompilation > 0:
        printError("Unsuccessful compilation of " & $omniFileName & $omniFileExt & ".")
        return 1
    
    #Also for supernova
    if supernova:
        #supernova gets passed both supercollider (which turns on the rt_alloc) and supernova (for buffer handling) flags
        var omni_command_supernova = "omni \"" & $fullPathToFile & "\" -n:lib" & $omniFileName & "_supernova -i:omnicollider_lang -l:static -d:multithreadBuffers -o:\"" & $fullPathToNewFolder & "\""
        
        #Windows requires powershell to figure out the .nimble path... go figure!
        when not defined(Windows):
            let failedOmniCompilation_supernova = execCmd(omni_command_supernova)
        else:
            let failedOmniCompilation_supernova = execShellCmd(omni_command_supernova)
        
        #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
        if failedOmniCompilation_supernova > 0:
            printError("Unsuccessful supernova compilation of " & $omniFileName & $omniFileExt & ".")
            return 1
    
    # ================ #
    #  RETRIEVE I / O  #
    # ================ #
    
    let 
        fullPathToIOFile = fullPathToNewFolder & "/IO.txt"
        io_file = readFile(fullPathToIOFile)
        io_file_seq = io_file.split('\n')

    if io_file_seq.len != 3:
        printError("Invalid IO.txt file.")
        return 1
    
    let 
        num_inputs  = parseInt(io_file_seq[0])
        input_names_string = io_file_seq[1]
        input_names = input_names_string.split(',') #this is a seq now
        num_outputs = parseInt(io_file_seq[2])

    # ================ #
    # CREATE NEW FILES #
    # ================ #

    #Create .ccp/.sc/cmake files in the new folder
    let
        cppFile   = open(fullPathToCppFile, fmWrite)
        scFile    = open(fullPathToSCFile, fmWrite)
        cmakeFile = open(fullPathToCMakeFile, fmWrite)
    
    # ======== #
    # SC I / O #
    # ======== #
    
    var 
        arg_string = ""
        arg_rates = ""
        multiNew_string = "^this.multiNew('audio'"
        multiOut_string = ""

    #No input names
    if input_names[0] == "__NO_PARAM_NAMES__":
        if num_inputs == 0:
            multiNew_string.add(");")
        else:
            arg_string.add("arg ")
            multiNew_string.add(",")
            
            for i in 1..num_inputs:

                arg_rates.add("if(in" & $i & ".rate != 'audio', { ((this.class).asString.replace(\"Meta_\", \"\") ++ \": argument in" & $i & " must be audio rate\").warn; ^Silent.ar; });\n\t\t")

                if i == num_inputs:
                    arg_string.add("in" & $i & ";")
                    multiNew_string.add("in" & $i & ");")
                    break

                arg_string.add("in" & $i & ", ")
                multiNew_string.add("in" & $i & ", ")
        
    #input names
    else:
        if num_inputs == 0:
            multiNew_string.add(");")
        else:
            arg_string.add("arg ")
            multiNew_string.add(",")
            for index, input_name in input_names:

                #This duplication is not good at all. Find a neater way.
                arg_rates.add("if(" & $input_name & ".class == Buffer, { ((this.class).asString.replace(\"Meta_\", \"\") ++ \": argument " & $input_name & " must be audio rate. Wrap it in a DC.ar UGen\").warn; ^Silent.ar; });\n\t\t")
                arg_rates.add("if(" & $input_name & ".rate != 'audio', { ((this.class).asString.replace(\"Meta_\", \"\") ++ \": argument " & $input_name & " must be audio rate. Wrap it in a DC.ar UGen.\").warn; ^Silent.ar; });\n\t\t")

                if index == num_inputs - 1:
                    arg_string.add($input_name & ";")
                    multiNew_string.add($input_name & ");")
                    break

                arg_string.add($input_name & ", ")
                multiNew_string.add($input_name & ", ")

    
    OMNI_PROTO_SC = OMNI_PROTO_SC.replace("//args", arg_string)
    OMNI_PROTO_SC = OMNI_PROTO_SC.replace("//rates", arg_rates)
    OMNI_PROTO_SC = OMNI_PROTO_SC.replace("//multiNew", multiNew_string)

    #Multiple outputs UGen
    if num_outputs > 1:
        multiOut_string = "init { arg ... theInputs;\n\t\tinputs = theInputs;\n\t\t^this.initOutputs(" & $num_outputs & ", rate);\n\t}"
        OMNI_PROTO_SC = OMNI_PROTO_SC.replace("//multiOut", multiOut_string)
        OMNI_PROTO_SC = OMNI_PROTO_SC.replace(" : UGen", " : MultiOutUGen")

    # =========== #
    # WRITE FILES #
    # =========== #

    #Replace Omni_PROTO with the name of the Omni file
    OMNI_PROTO_CPP   = OMNI_PROTO_CPP.replace("Omni_PROTO", omniFileName)
    OMNI_PROTO_SC    = OMNI_PROTO_SC.replace("Omni_PROTO", omniFileName)
    OMNI_PROTO_CMAKE = OMNI_PROTO_CMAKE.replace("Omni_PROTO", omniFileName)

    cppFile.write(OMNI_PROTO_CPP)
    scFile.write(OMNI_PROTO_SC)
    cmakeFIle.write(OMNI_PROTO_CMAKE)

    cppFile.close
    scFile.close
    cmakeFIle.close
    
    # ========== #
    # BUILD UGEN #
    # ========== #

    #Create build folder
    removeDir($fullPathToNewFolder & "/build")
    createDir($fullPathToNewFolder & "/build")
    
    var sc_cmake_cmd : string
    
    when(not(defined(Windows))):
        if supernova:
            sc_cmake_cmd = "cmake -DOMNI_BUILD_DIR=\"" & $fullPathToNewFolder & "\" -DSC_PATH=\"" & $expanded_sc_path & "\" -DSUPERNOVA=ON -DCMAKE_BUILD_TYPE=Release -DBUILD_MARCH=" & $architecture & " .."
        else:
            sc_cmake_cmd = "cmake -DOMNI_BUILD_DIR=\"" & $fullPathToNewFolder & "\" -DSC_PATH=\"" & $expanded_sc_path & "\" -DCMAKE_BUILD_TYPE=Release -DBUILD_MARCH=" & $architecture & " .."
    else:
        #Cmake wants a path in unix style, not windows! Replace "/" with "\"
        let fullPathToNewFolder_Unix = fullPathToNewFolder.replace("\\", "/")
        
        if supernova:
            sc_cmake_cmd = "cmake -G \"MinGW Makefiles\" -DOMNI_BUILD_DIR=\"" & $fullPathToNewFolder_Unix & "\" -DSC_PATH=\"" & $expanded_sc_path & "\" -DSUPERNOVA=ON -DCMAKE_BUILD_TYPE=Release -DBUILD_MARCH=" & $architecture & " .."
        else:
            sc_cmake_cmd = "cmake -G \"MinGW Makefiles\" -DOMNI_BUILD_DIR=\"" & $fullPathToNewFolder_Unix & "\" -DSC_PATH=\"" & $expanded_sc_path & "\" -DCMAKE_BUILD_TYPE=Release -DBUILD_MARCH=" & $architecture & " .."
    
    #cd into the build directory
    setCurrentDir(fullPathToNewFolder & "/build")
    
    #Execute CMake
    when not defined(Windows):
        let failedSCCmake = execCmd(sc_cmake_cmd)
    else:
        let failedSCCmake = execShellCmd(sc_cmake_cmd)

    #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
    if failedSCCmake > 0:
        printError("Unsuccessful cmake generation of the UGen file \"" & $omniFileName & ".cpp\".")
        return 1

    #make command
    when not(defined(Windows)):
        let 
            sc_compilation_cmd = "make"
            failedSCCompilation = execCmd(sc_compilation_cmd)
    else:
        let 
            sc_compilation_cmd = "mingw32-make"
            failedSCCompilation = execShellCmd(sc_compilation_cmd)
        
    
    #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
    if failedSCCompilation > 0:
        printError("Unsuccessful compilation of the UGen file \"" & $omniFileName & ".cpp\".")
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
    let fullPathToNewFolderInExtenstions = $expanded_out_dir  & "/" & omniFileName
    
    #Remove previous folder in Extensions if there was, then copy the new one over
    removeDir(fullPathToNewFolderInExtenstions)
    copyDir(fullPathToNewFolder, fullPathToNewFolderInExtenstions)

    #Remove temp folder used for compilation
    removeDir(fullPathToNewFolder)

    printDone("The " & $omniFileName & " UGen has been correctly built and installed in \"" & $expanded_out_dir & "\".")

    return 0

proc omnicollider(omniFiles : seq[string], supernova : bool = false, architecture : string = "native", outDir : string = default_extensions_path, scPath : string = default_sc_path, removeBuildFiles : bool = true) : int =
    for omniFile in omniFiles:
        if omnicollider_single_file(omniFile, supernova, architecture, outDir, scPath, removeBuildFiles) > 0:
            return 1
    
    return 0

#Dispatch the omnicollider function as the CLI one
dispatch(omnicollider, 
    short={
        "scPath" : 'p',
        "supernova" : 's'
    }, 
    
    help={ 
        "supernova" : "Build with supernova support.",
        "architecture" : "Build architecture.",
        "outDir" : "Output directory. Defaults to SuperCollider's \"Platform.userExtensionDir\".",
        "scPath" : "Path to the SuperCollider source code folder. Defaults to the one in omnicollider's dependencies.", 
        "removeBuildFiles" : "Remove source files used for compilation from outDir."        
    }
)