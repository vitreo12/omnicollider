# **omnicollider**

Compile [omni](https://github.com/vitreo12/omni) code into [SuperCollider](https://github.com/supercollider/supercollider) `UGens`.

## **Requirements**

The software needed to run `omnicollider` is the same as `omni`'s, with the addition of [cmake](https://cmake.org/) for all platforms and
[MinGW](http://mingw.org/) for Windows.

### **Linux**

Refer to your distribution's package manager and make sure you've got installed:
1) [nim](https://nim-lang.org/)
2) [git](https://git-scm.com/)
3) [cmake](https://cmake.org/) 

### **MacOS**

To install dependencies on MacOS it is suggested to use a package manager like [brew](https://brew.sh/). 
To install `brew`, simply open the `Terminal` app and run this command :
    
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

After `brew` has been installed, run the following command in the `Terminal` app to install `nim` and `cmake`:

    brew install nim cmake

### **Windows:**

On Windows, the [MinGW](http://mingw.org/)'s `gcc` compiler needs also to be installed.

To install dependencies on Windows it is suggested to use a package manager like [scoop](https://scoop.sh/). 
To install `scoop`, simply open `PowerShell` and run this command :
    
    iwr -useb get.scoop.sh | iex

After `scoop` has been installed, run the following command in `PowerShell` to install `nim`, `git`, `cmake` and `gcc`:

    scoop install nim git cmake gcc

## **Installation**

First, install `omni`:

    git clone https://github.com/vitreo12/omni

    cd omni
        
    nimble installOmni

Then, install `omnicollider`:

    git clone --recursive https://github.com/vitreo12/omnicollider
    
    cd omnicollider
    
    nimble installOmniCollider