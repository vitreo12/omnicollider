# **omnicollider**

Compile omni code into SuperCollider UGens.

## **Requirements**

1) [cmake](https://cmake.org/download/)
2) [omni](https://github.com/vitreo12/omni)

        git clone https://github.com/vitreo12/omni

        cd omni
        
        nimble installOmni

### **Windows:**

The [MinGW](https://sourceforge.net/projects/mingw-w64/) compiler is also needed for Windows use.

To install dependencies on Windows, it is suggested to use a package manager like [chocolatey](https://chocolatey.org/why-chocolatey). To install chocolatey, check its [installation guide](https://chocolatey.org/install).

After chocolatey has been installed, run the following commands in your command line or PowerShell to install cmake and MinGW:

    choco install cmake --pre 

    choco install mingw

## **Installation**

    git clone --recursive https://github.com/vitreo12/omnicollider
    
    cd omnicollider
    
    nimble installOmniCollider