/* File : example.i */
%module example
%{
#include "example.h"
%}

%include "squirrel_fnptr.i"

/* Let's just grab the original header file here */
%include "example.h"

%inline %{
typedef int (*OP_FUNC)(int, int);

int callback(int a, int b, OP_FUNC op, SWIGSQUIRREL_FN fn)
{
  int r = (*op)(a, b);

  sq_pushroottable(fn.v);
  sq_pushinteger(fn.v, r);

  SQInteger result;
  if (SQ_SUCCEEDED(sq_call(fn.v, 2, SQTrue, SQFalse))) {
    sq_getinteger(fn.v, -1, &result);
  }

  return result;
}
%}

/* Now install a bunch of "ops" as constants */
%constant int (*ADD)(int,int) = add;
%constant int (*SUB)(int,int) = sub;
%constant int (*MUL)(int,int) = mul;

