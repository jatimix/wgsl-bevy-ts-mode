
Emacs [tree-sitter](https://tree-sitter.github.io/tree-sitter/) support for the [WebGPU Shading Language (WGSL)](https://gpuweb.github.io/gpuweb/wgsl.html) with additionnal support for Naga OIL (Bevy) extension 
[naga-oil](https://github.com/bevyengine/naga_oil)

providing syntax highlighting, indenting and navigation.


# Installation

In order to use this mode, you must arrange that the [tree-sitter-bevy-wgsl grammar]
(https://github.com/jatimix/tree-sitter-bevy-wgsl/tree/master) is available.

## Installing tree-sitter for emacs

* Emacs 29+

Follow [section](https://www.masteringemacs.org/article/how-to-get-started-tree-sitter#installing-the-language-grammars) 
on installing grammars as part of a helpful article on getting started with tree-sitter in emacs that will likely be of use.

But as a rule of thumbs on linux-*:
- Build grammar lib
- sudo cp libtreesitter* /usr/local/lib
- sudo ldconfig
- Should work

## Contributions

Welcome.


