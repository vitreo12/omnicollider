import cligen, terminal, os, strutils, osproc

include "omnicolliderpkg/build/Static/Omni_PROTO.cpp.nim"
include "omnicolliderpkg/build/Static/CMakeLists.txt.nim"
include "omnicolliderpkg/build/Static/Omni_PROTO.sc.nim"

#Package version is passed as argument when building. It will be constant and set correctly
const 
    NimblePkgVersion {.strdefine.} = ""
    omnicollider_ver = NimblePkgVersion

#Default to the omni nimble folder, which should have it installed if omni has been installed correctly
const default_sc_path = "~/.nimble/pkgs/omnicollider-" & omnicollider_ver & "/omnicolliderpkg/deps/supercollider"

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

proc printErrorMsg(msg : string) : void =
    setForegroundColor(fgRed)
    writeStyled("ERROR: ", {styleBright}) 
    setForegroundColor(fgWhite, true)
    writeStyled(msg)

proc printDone(msg : string) : void =
    setForegroundColor(fgGreen)
    writeStyled("DONE: ", {styleBright}) 
    setForegroundColor(fgWhite, true)
    writeStyled(msg)

proc omnicollider(file : string, scPath : string = default_sc_path, extensionsPath : string = default_extensions_path, architecture : string = "native", supernova : bool = false, removeBuildDir : bool = true) : void = 

    let 
        fullPath = absolutePath(file)
        
        #This is the path to the original nim file to be used in shell.
        #Using this one in nim command so that errors are shown on this one when CTRL+Click on terminal
        fullPathToOriginalOmniFileShell = fullPath.replace(" ", "\\ ")

    #Check if file exists
    if not fullPath.existsFile():
        printErrorMsg($fullPath & " doesn't exist.")
        return
    
    var 
        omniFile     = splitFile(fullPath)
        omniFileDir  = omniFile.dir
        omniFileName = omniFile.name
        omniFileExt  = omniFile.ext

    #Check file first charcter, must be a capital letter
    if not omniFileName[0].isUpperAscii:
        omniFileName[0] = omniFileName[0].toUpperAscii()

    #Check file extension
    if not(omniFileExt == ".omni") and not(omniFileExt == ".oi"):
        printErrorMsg($fullPath & " is not an omni file.")
        return

    let expanded_sc_path = scPath.expandTilde()

    #Check scPath
    if not expanded_sc_path.existsDir():
        printErrorMsg($scPath & " doesn't exist.")
        return
    
    let expanded_extensions_path = extensionsPath.expandTilde()

    #Check extensionsPath
    if not expanded_extensions_path.existsDir():
        printErrorMsg($extensionsPath & " doesn't exist.")
        return

    #Full paths to the new file in omniFileName directory
    let 
        #New folder named with the name of the Omni file
        fullPathToNewFolder = $omniFileDir & "/" & $omniFileName

        #This is to use in shell cmds instead of fullPathToNewFolder, expands spaces to "\ "
        fullPathToNewFolderShell = fullPathToNewFolder.replace(" ", "\\ ")

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
    copyFile(fullPath, fullPathToOmniFile)

    # ================ #
    # COMPILE NIM FILE #
    # ================ #

    #Compile nim file. Only pass the -d:omnicli and -d:tempDir flag here, so it generates the IO.txt file.
    let omni_command = "omni -i:omnicollider_lang -l:static -d:writeIO -d:tempDir=" & $fullPathToNewFolderShell & " -o:" & $fullPathToNewFolderShell & " " & $fullPathToOriginalOmniFileShell 
    
    echo omni_command

    if true:
        return
    
    let failedOmniCompilation = execCmd(omni_command)

    #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
    if failedOmniCompilation > 0:
        printErrorMsg("Unsuccessful compilation of " & $omniFileName & $omniFileExt)
        return
    
    #Also for supernova
    if supernova:
        #supernova gets passed both supercollider (which turns on the rt_alloc) and supernova (for buffer handling) flags
        var omni_command_supernova = "omni -i:omnicollider_lang -l:static -d:writeIO -d:multithreadBuffers -o:" & $fullPathToNewFolderShell & " " & $fullPathToOriginalOmniFileShell
        let failedOmniCompilation_supernova = execCmd(omni_command_supernova)
        
        #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
        if failedOmniCompilation_supernova > 0:
            printErrorMsg("Unsuccessful supernova compilation of " & $omniFileName & $omniFileExt)
            return
    
    # ================ #
    #  RETRIEVE I / O  #
    # ================ #
    
    let 
        io_file = readFile($fullPathToNewFolder & "/IO.txt")
        io_file_seq = io_file.split('\n')

    if io_file_seq.len != 3:
        printErrorMsg("Invalid IO.txt file")
        return   
    
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
            sc_cmake_cmd = "cmake -DWORKING_FOLDER=" & $fullPathToNewFolderShell & " -DSC_PATH=" & $expanded_sc_path & " -DSUPERNOVA=ON -DCMAKE_BUILD_TYPE=Release -DBUILD_MARCH=" & $architecture & " .."
        else:
            sc_cmake_cmd = "cmake -DWORKING_FOLDER=" & $fullPathToNewFolderShell & " -DSC_PATH=" & $expanded_sc_path & " -DCMAKE_BUILD_TYPE=Release -DBUILD_MARCH=" & $architecture & " .."
    else:
        #cmake wants a path in unix style, not windows!!!
        let fullPathToNewFolderShell_Unix = fullPathToNewFolderShell.replace("\\", "/")
        
        if supernova:
            sc_cmake_cmd = "cmake -G \"MinGW Makefiles\" -DWORKING_FOLDER=" & $fullPathToNewFolderShell_Unix & " -DSC_PATH=" & $expanded_sc_path & " -DSUPERNOVA=ON -DCMAKE_BUILD_TYPE=Release -DBUILD_MARCH=" & $architecture & " .."
        else:
            sc_cmake_cmd = "cmake -G \"MinGW Makefiles\" -DWORKING_FOLDER=" & $fullPathToNewFolderShell_Unix & " -DSC_PATH=" & $expanded_sc_path & " -DCMAKE_BUILD_TYPE=Release -DBUILD_MARCH=" & $architecture & " .."
    
    #cd into the build directory
    setCurrentDir(fullPathToNewFolderShell & "/build")
    
    #Execute CMake
    let failedSCCmake = execCmd(sc_cmake_cmd)

    #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
    if failedSCCmake > 0:
        printErrorMsg("Unsuccessful cmake generation of the UGen file " & $omniFileName & ".cpp")
        return

    #make command
    when not(defined(Windows)):
        let sc_compilation_cmd = "make"
    else:
        let sc_compilation_cmd = "mingw32-make"

    #Execute make command
    let failedSCCompilation = execCmd(sc_compilation_cmd)
    
    #error code from execCmd is usually some 8bit number saying what error arises. I don't care which one for now.
    if failedSCCompilation > 0:
        printErrorMsg("Unsuccessful compilation of the UGen file " & $omniFileName & ".cpp")
        return
    
    #cd back to the original folder where omni file is
    setCurrentDir(omniFileDir)

    # ========================= #
    # COPY TO EXTENSIONS FOLDER #
    # ========================= #
    copyFile($fullPathToNewFolder & "/build/" & $omniFileName & $ugen_extension, $fullPathToNewFolder & "/" & $omniFileName & $ugen_extension)
    if supernova:
        copyFile($fullPathToNewFolder & "/build/" & $omniFileName & "_supernova" & $ugen_extension, $fullPathToNewFolder & "/" & $omniFileName & "_supernova" & $ugen_extension)

    #Remove build, .cpp, cmake, .omni, and static libs
    removeDir(fullPathToNewFolder & "/build")
    removeFile(fullPathToCppFile)
    removeFile(fullPathToOmniFile)
    removeFile(fullPathToCMakeFile)
    removeFile(fullPathToStaticLib)
    if supernova:
        removeFile(fullPathToStaticLib_supernova)

    #Copy to extensions folder
    let fullPathToNewFolderInExtenstions = $expanded_extensions_path  & "/" & omniFileName
    
    #Remove previous folder there if there was, then copy the new one over to the extensions folder
    removeDir(fullPathToNewFolderInExtenstions)
    copyDir(fullPathToNewFolder, fullPathToNewFolderInExtenstions)

    #Remove temp folder
    if removeBuildDir:
        removeDir(fullPathToNewFolder)

    printDone("The " & $omniFileName & " UGen has been correctly built and installed in " & $expanded_extensions_path & ".")

proc omnicollider_cli(files : seq[string], scPath : string = default_sc_path, extensionsPath : string = default_extensions_path, architecture : string = "native", supernova : bool = false, removeBuildDir : bool = true) : void =
    for file in files:
        omnicollider(file, scPath, extensionsPath, architecture, supernova, removeBuildDir)

#Dispatch the omnicollider function as the CLI one
dispatch(omnicollider_cli, 
    short={"scPath" : 'p', "supernova" : 's'}, 
    
    help={ 
           "scPath" : "Path to the SuperCollider source code folder.", 
           "extensionsPath" : "Path to SuperCollider's \"Platform.userExtensionDir\" or \"Platform.systemExtensionDir\".\n",
           "architecture" : "Build architecture.",
           "supernova" : "Build with supernova support.",
           "removeBuildDir" : "Remove the directory created in the build process at the current path."
    }

)