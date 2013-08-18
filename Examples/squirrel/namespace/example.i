/* File : example.i */
%module example

%{
#include "example.h"
%}

%feature("nspace", 1);

/* Let's just grab the original header file here */
%include "example.h"

