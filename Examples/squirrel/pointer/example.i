/* File : example.i */
%module example

%inline %{
extern void add(int *x, int *y, int *result);
extern int divide(int n, int d, int *r);
%}

/* include helper functions */
%include cpointer.i
%pointer_functions(int, intp);
