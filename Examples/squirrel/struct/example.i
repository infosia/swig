/* File : example.i */

%module example

%{
#include "example.h"
%}

%nodefaultctor Foo;

/* Let's set custom destructor for Color struct */
%extend Color {
  ~Color() {
    colorFree($self);
  }
};

%include "example.h"

%inline %{
extern void colorFree(Color *p);
%}

