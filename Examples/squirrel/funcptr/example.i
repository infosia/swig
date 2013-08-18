/* File : example.i */
%module example
%{
#include "example.h"
%}

/* Let's just grab the original header file here */
%include "example.h"

%inline %{
typedef int (*OP_FUNC)(int, int);

int callback(int a, int b, OP_FUNC op)
{
  return (*op)(a, b);
}  
%}

/* Now install a bunch of "ops" as constants */
%constant int (*ADD)(int,int) = add;
%constant int (*SUB)(int,int) = sub;
%constant int (*MUL)(int,int) = mul;

