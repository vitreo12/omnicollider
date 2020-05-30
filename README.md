# **omnicollider**

Compile [omni](https://github.com/vitreo12/omni) code into [SuperCollider](https://github.com/supercollider/supercollider) `UGens`.

## **Requirements**

1) [nim](https://nim-lang.org/)
2) [git](https://git-scm.com/)
3) [cmake](https://cmake.org/) 
4) [gcc](https://gcc.gnu.org/) (`Linux` and `Windows`)  /  [clang](https://clang.llvm.org/) (`MacOS`)

### **Linux**

Refer to your distribution's package manager and make sure you've got installed `nim`, `git` and `cmake`.

### **MacOS**

To install dependencies on MacOS it is suggested to use a package manager like [brew](https://brew.sh/). 
To install `brew`, simply open the `Terminal` app and run this command :
    
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

After `brew` has been installed, run the following command in the `Terminal` app to install `nim` and `cmake`:

    brew install nim cmake

Then, make sure that the `~/.nimble/bin` directory is set in your shell `$PATH`.
If using bash (the default shell in MacOS), simply edit (or create if it doesn't exist) the `~/.bash_profile` file and add this line to it: 

    export PATH=$PATH:~/.nimble/bin

### **Windows:**

On Windows, the [MinGW](http://mingw.org/)'s `gcc` compiler needs also to be installed.

To install dependencies on Windows it is suggested to use a package manager like [scoop](https://scoop.sh/). 
To install `scoop`, simply open `PowerShell` and run this command :
    
    iwr -useb get.scoop.sh | iex

After `scoop` has been installed, run the following command in `PowerShell` to install `nim`, `git`, `cmake` and `gcc`:

    scoop install nim git cmake gcc

## **Installation**

To install `omnicollider`, simply use the `nimble` package manager (it comes bundled with the `nim` installation).The command will also take care of installing `omni`:

    nimble install omnicollider

## **Usage**

    omnicollider ~/.nimble/pkgs/omni-0.1.0/examples/OmniSaw.omni                                                                             
## **Website / Docs**

Check omni's [website](https://vitreo12.github.io/omni).