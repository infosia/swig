/* -----------------------------------------------------------------------------
 * squirrel_fnptr.i
 *
 * SWIG Library file containing the main typemap code to support Squirrel modules.
 * ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
 *                          Basic function pointer support
 * ----------------------------------------------------------------------------- */
/*
The structure: SWIGSQUIRREL_FN provides a simple (local only) wrapping for a function.

For example if you wanted to have a C/C++ function take a squirrel function as a parameter.
You could declare it as:
  int my_func(int a, int b, SWIGSQUIRREL_FN fn);
note: it should be passed by value, not byref or as a pointer.

The SWIGSQUIRREL_FN holds a pointer to the squirrel vm, and the stack index where the function is held.
After that its fairly simple to write the rest of the code (assuming know how to use squirrel),
just push the parameters, call the function and return the result.

  int my_func(int a, int b, SWIGSQUIRREL_FN fn)
  {
    sq_push(fn.v, fn.idx);
    sq_pushroottable(fn.v);
    sq_pushinteger(fn.v, a);
    sq_pushinteger(fn.v, b);

    SQInteger result;
    if (SQ_SUCCEEDED(sq_call(fn.v, 3, SQTrue, SQFalse))) {
      sq_getinteger(fn.v, -1, &result);
    }

    return result;
  }

SWIG will automatically performs the wrapping of the arguments in and out.

*/
// this is for the C code only, we don't want SWIG to wrapper it for us.
%{
typedef struct{
  HSQUIRRELVM v; /* the vm */
  int idx;       /* the index on the stack */
}SWIGSQUIRREL_FN;
%}

// the actual typemap
%typemap(in,checkfn="is_closure") SWIGSQUIRREL_FN
%{  $1.v=v; $1.idx=$input; %}

