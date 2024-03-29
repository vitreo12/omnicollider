# **omnicollider**

Compile [omni](https://github.com/vitreo12/omni) code into [SuperCollider](https://github.com/supercollider/supercollider) `UGens`.

## **Requirements**

1) [nim](https://nim-lang.org/)
2) [git](https://git-scm.com/)
3) [cmake](https://cmake.org/) 
4) [gcc](https://gcc.gnu.org/) (`Linux` and `Windows`)  /  [clang](https://clang.llvm.org/) (`MacOS`)

Note that omni only supports nim version 1.6.0. It is recommended to install it via [choosenim](https://github.com/dom96/choosenim).

## **Installation**

To install `omnicollider`, simply use the `nimble` package manager (it comes bundled with the `nim` installation).The command will also take care of installing `omni`:

    nimble install omnicollider -y

## **Usage**

    omnicollider ~/.nimble/pkgs/omni-0.4.2/examples/OmniSaw.omni

## **Website / Docs**

Check omni's [website](https://vitreo12.github.io/omni).
