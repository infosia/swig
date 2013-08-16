# SWIG (Simplified Wrapper and Interface Generator) with Squirrel Language Support

[SWIG](https://github.com/swig/swig) is an interface compiler that connects programs written in C and C++ with scripting languages such as Perl, Python, Ruby, and Tcl. It works by taking the declarations found in C/C++ header files and using them to generate the wrapper code that scripting languages need to access the underlying C/C++ code. In addition, SWIG provides a variety of customization features that let you tailor the wrapping process to suit your application. 

This branch is a fork from [SWIG](https://github.com/swig/swig) version 2.0.11 and meant to add Squirrel language support.

## How to Compile

1. Make sure you already have Squirrel source/library compiled on your device. 
2. run configure with '--with-squirrel' option. 
   SWIG will search 'include/squirrel.h' and 'lib/libsquirrel.a' from the directory
3. run make

```
$ cd swig-squirrel
$ ./autogen.sh
$ ./configure --with-squirrel=YOUR_SQUIRREL_SOURCE_ROOT_DIRECTORY
$ make
```

## How to Run Sample Code

```
$ cd Example/squirrel/simple
$ make
```

## License

Please see the LICENSE file for details of the SWIG license. For further insight into the license including the license of SWIG's output code, please visit http://www.swig.org/legal.html

-- SWIG-Squirrel Maintainer
