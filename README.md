# **omnicollider**

Compile [omni](https://github.com/vitreo12/omni) code into [SuperCollider](https://github.com/supercollider/supercollider) `UGens`.

## **Requirements**

### **All Platforms**

1) [nim](https://nim-lang.org/)
2) [git](https://git-scm.com/)
3) [cmake](https://cmake.org/)

### **Windows:**

On Windows, the [MinGW](http://mingw.org/)'s `gcc` compiler needs also to be installed.

To install dependencies on Windows, it is suggested to use a package manager like [scoop](https://scoop.sh/). 
To install `scoop`, simply open `PowerShell` and run this command :
    
    iwr -useb get.scoop.sh | iex

After `scoop` has been installed, run the following command in `PowerShell` to install `git`, `cmake` and `gcc`:

    scoop install git cmake gcc


## **Installation**

First, install `omni`:

    git clone https://github.com/vitreo12/omni

    cd omni
        
    nimble installOmni

Then, install `omnicollider`:

    git clone --recursive https://github.com/vitreo12/omnicollider
    
    cd omnicollider
    
    nimble installOmniCollider