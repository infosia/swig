/* File : example.i */
%module example

%{
#include "example.h"
%}

/* Let's set custom destructor for Circle class */
%extend Circle {
  ~Circle() {
    printf("Custom destructor for Circle is called!\n");
    delete $self;
  }
};

/* Let's just grab the original header file here */
%include "example.h"


