/* -----------------------------------------------------------------------------
 * squirrel.swg
 *
 * SWIG Configuration File for Squirrel.
 * This file is parsed by SWIG before reading any other interface file.
 * ----------------------------------------------------------------------------- */

%runtime "swigrun.swg";         /* Common C API type-checking code */
%runtime "squirrelrun.swg";

/* -----------------------------------------------------------------------------
 *                          standard typemaps
 * ----------------------------------------------------------------------------- */

%typemap(in, checkfn="is_integer") int,short,long,
             unsigned int,unsigned short,unsigned long,
             signed char,unsigned char, char  
%{ { SQInteger temp; sq_getinteger(v, $input , &temp); $1 = temp; } %}

%typemap(out) int,short,long,
             unsigned int,unsigned short,unsigned long,
             signed char,unsigned char, char
%{sq_pushinteger(v, (SQInteger) $1); %}


%typemap(in, checkfn="is_integer") enum SWIGTYPE 
%{ { SQInteger temp; sq_getinteger(v, $input , &temp); $1 = ($type) temp; } %}

%typemap(out) enum SWIGTYPE
%{sq_pushinteger(v, (SQInteger) $1); %}

%typemap(in, checkfn="is_number") float, double 
%{{SQFloat temp;  sq_getfloat(v, $input , &temp); $1 = temp; } %}

%typemap(out) float, double
%{sq_pushfloat(v, (SQFloat) $1); %}


%typemap(in, checkfn="is_bool") bool 
%{{ SQBool temp; sq_getbool(v, $input, &temp); $1 = temp; } %}

%typemap(out) bool, const bool &
%{sq_pushbool(v, (SQBool) $1); %}


%typemap(in, checkfn="is_string") const char*, char*, const char[ANY], char[ANY]
%{sq_getstring(v, $input, (const SQChar**)&$1); %}

%typemap(out) const char*, char*, const char[ANY], char[ANY]
%{sq_pushstring(v, (const SQChar*) $1, -1); %}

// pointers and references
%typemap(in, checkfn="is_userdata") SWIGTYPE*,SWIGTYPE&,SWIGTYPE[]
%{$1=($1_ltype)SWIG_MustGetPtr(v, $input,$descriptor,0,$argnum,"$symname");%}

%typemap(out) SWIGTYPE*,SWIGTYPE&
%{SWIG_NewPointerObj(v,$1,$descriptor,$owner);%}

// passing objects by value (yuk: do you really have to do this?)
// what we do is get it as a pointer (the $&ltype argp)
// then do an assignment
%typemap(in, checkfn="is_userdata") SWIGTYPE
{
   $&ltype argp;
   if(SWIG_ConvertPtr(v,$input,(void**)(&argp),$&descriptor,0)) SWIG_fail;
   $1 = *argp;
}

// Primitive types--return by value
// must make a new object, copy the data & return the new object
#ifdef __cplusplus
%typemap(out) SWIGTYPE
{
  $&1_ltype resultptr;
  resultptr = new $1_ltype(($1_ltype &) $1);
  SWIG_NewPointerObj(L,(void *) resultptr,$&1_descriptor,1);
}
#else
%typemap(out) SWIGTYPE
{
  $&1_ltype resultptr;
  resultptr = ($&1_ltype) malloc(sizeof($1_type));
  *resultptr = $1;
  SWIG_NewPointerObj(v,(void *) resultptr,$&1_descriptor,1);
}
#endif

%typemap(out) void "";


/* -----------------------------------------------------------------------------
 *                          constants typemaps
 * ----------------------------------------------------------------------------- */
// this basically adds to a table of constants
%typemap(consttab) int, unsigned int, short, unsigned short, long, unsigned long, unsigned char, signed char, bool, enum SWIGTYPE
       { SWIG_SQUIRREL_INT,     (char *)"$symname", (long) $value, 0, 0, 0}

%typemap(consttab) float, double
       { SWIG_SQUIRREL_FLOAT,   (char *)"$symname", 0, (double) $value, 0, 0}

%typemap(consttab) char, char *
       { SWIG_SQUIRREL_STRING,  (char *)"$symname", 0, 0, (void *)"$value", 0}

%typemap(consttab) long long, unsigned long long
       { SWIG_SQUIRREL_INT, (char *) "$symname", 0, 0, (long long)"$value", 0}

%typemap(consttab) SWIGTYPE *, SWIGTYPE &, SWIGTYPE []
       { SWIG_SQUIRREL_POINTER, (char *)"$symname", 0, 0, (void *)$value, &$1_descriptor}


/* -----------------------------------------------------------------------------
 *                          Const reference issues
 * ----------------------------------------------------------------------------- */
// additional typemaps for privitives by const reference:
// given a function:
//  int intbyref(const int& i);
// SWIG assumes that this code will need a pointer to int to be passed in
// (this might be ok for passing objects by const ref, but not a primitive)
// therefore we add a set of blanket typemaps to fix this
// also a set for fns which return const X&

%define SWIG_NUMBER_BY_CONST_REF(TYPE)
%typemap(in,checkfn="is_number") const TYPE &
%{ { SQInteger temp; sq_getinteger(v, $input , &temp); $1 = ($type) temp; } %}
%typemap(out) const TYPE&
%{  sq_pushinteger(v, (SQInteger) $1); %}
%enddef

SWIG_NUMBER_BY_CONST_REF(int);
SWIG_NUMBER_BY_CONST_REF(unsigned int);
SWIG_NUMBER_BY_CONST_REF(signed int);
SWIG_NUMBER_BY_CONST_REF(short);
SWIG_NUMBER_BY_CONST_REF(unsigned short);
SWIG_NUMBER_BY_CONST_REF(signed short);
SWIG_NUMBER_BY_CONST_REF(long);
SWIG_NUMBER_BY_CONST_REF(unsigned long);
SWIG_NUMBER_BY_CONST_REF(signed long);
//SWIG_NUMBER_BY_CONST_REF(char); // char's are now small strings
SWIG_NUMBER_BY_CONST_REF(unsigned char);
SWIG_NUMBER_BY_CONST_REF(signed char);
SWIG_NUMBER_BY_CONST_REF(float);
SWIG_NUMBER_BY_CONST_REF(double);
SWIG_NUMBER_BY_CONST_REF(enum SWIGTYPE);

/* ------------------------------------------------------------
 *                              SWIG_init
 * ------------------------------------------------------------ */
%insert(initbeforefunc) "swiginit.swg"

%insert(initbeforefunc) %{

#ifdef __cplusplus
extern "C" {
#endif

SWIGEXPORT int SWIG_init(HSQUIRRELVM v)
{

  int i;
    
  sq_pushroottable(v);

  SWIG_InitializeModule((void*)v);
  SWIG_PropagateClientData();
    
  /* begin the module (its a table with the same name as the module) */
  SWIG_Squirrel_module_begin(v,SWIG_MODULE_NAME);
  
  /* add commands/functions */
  for (i = 0; swig_commands[i].name; i++)
  {
    SWIG_Squirrel_module_add_function(v,swig_commands[i].name,swig_commands[i].func);     
  }
  for (i = 0; swig_variables[i].name; i++)
  {
    SWIG_Squirrel_module_add_variable(v,swig_variables[i].name, swig_variables[i].get, swig_variables[i].set);     
  }

  /* additional registration structs & classes */
  for (i = 0; swig_types[i]; i++){
    if (swig_types[i]->clientdata){
      SWIG_Squirrel_class_register(v,(swig_squirrel_class*)(swig_types[i]->clientdata));
    }
  }
    
  /* constants */
  SWIG_Squirrel_InstallConstants(v,swig_constants);

  /* end the module */
  SWIG_Squirrel_module_end(v,SWIG_MODULE_NAME);

  return 1;
}



#ifdef __cplusplus
}
#endif
%}

/* Note: the initialization function is closed after all code is generated */


/*************************** end squirrel.swg ******************************/

