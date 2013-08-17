/***********************************************************************
 * squirrelrun.swg
 *
 *     This file contains the runtime support for squirrel modules
 *     and includes code for managing global variables and pointer
 *     type checking.
 ************************************************************************/
#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <assert.h>

#include <squirrel.h>
#include <sqstdio.h>
#include <sqstdaux.h>

/* -----------------------------------------------------------------------------
 * global swig types
 * ----------------------------------------------------------------------------- */
/* Constant table */
#define SWIG_SQUIRREL_INT     1
#define SWIG_SQUIRREL_FLOAT   2
#define SWIG_SQUIRREL_STRING  3
#define SWIG_SQUIRREL_POINTER 4
#define SWIG_SQUIRREL_BINARY  5

typedef struct
{
  const char *name;
  SQFUNCTION func;
} swig_squirrel_command_info;

typedef struct
{
  const char *name;
  SQFUNCTION method;
} swig_squirrel_method;


typedef struct
{
  const char     *name;
  SQFUNCTION   getmethod;
  SQFUNCTION   setmethod;
} swig_squirrel_attribute;


/* Structure for variable linking table */
typedef struct
{
  const char *name;
  SQFUNCTION get;
  SQFUNCTION set;
} swig_squirrel_var_info;


/* Constant information structure */
typedef struct
{
  int type;
  char *name;
  SQInteger lvalue;
  SQFloat dvalue;
  void   *pvalue;
  swig_type_info **ptype;
} swig_squirrel_const_info;


typedef struct
{
  void             *ptr;
  swig_type_info   *type;
  int               own;  /* 1 if owned & must be destroyed */
} swig_squirrel_userdata;


typedef struct swig_squirrel_class
{
  const char         *name;
  swig_type_info   **type;
  SQFUNCTION       constructor;
  SQRELEASEHOOK    destructor;
  swig_squirrel_method        *methods;
  swig_squirrel_attribute     *attributes;
  struct swig_squirrel_class **bases;
  const char **base_names;
  swig_squirrel_const_info *constants;
} swig_squirrel_class;


/* Common SWIG API */
#define SWIG_NewPointerObj(v, ptr, type, owner) \
  SWIG_Squirrel_NewPointerObj(v, (void *)ptr, type, owner)
#define SWIG_ConvertPtr(v,idx, ptr, type, flags) \
  SWIG_Squirrel_ConvertPtr(v,idx,ptr,type,flags)
#define SWIG_MustGetPtr(v,idx, type,flags, argnum,fnname) \
  SWIG_Squirrel_MustGetPtr(v,idx, type,flags, argnum,fnname)
#define SWIG_GetModule(clientdata) SWIG_Squirrel_GetModule((HSQUIRRELVM)(clientdata))
#define SWIG_SetModule(clientdata, pointer) SWIG_Squirrel_SetModule((HSQUIRRELVM) (clientdata), pointer)
#define SWIG_MODULE_CLIENTDATA_TYPE HSQUIRRELVM

/* helper #defines */
#define SWIG_fail {goto fail;}
#define SWIG_fail_arg(func_name,argnum,type) \
  {\
    char msg[200]; snprintf(msg, sizeof(msg), "in %s (index=%d, type=%s)", func_name, argnum, type); \
    sq_pushstring(v, msg, -1); \
    goto fail;\
  }

static SQRESULT print_error(HSQUIRRELVM v, const char *fmt, ...)
{
  char msg[200];
  va_list ap;

  va_start(ap, fmt);

  vsnprintf(msg, sizeof(msg), fmt, ap);
  va_end(ap);
  return sq_throwerror(v, msg);
}

static int is_null(HSQUIRRELVM v, int index)
{
  return (OT_NULL == sq_gettype(v, index));
}

static int is_integer(HSQUIRRELVM v, int index)
{
  return (OT_INTEGER == sq_gettype(v, index));
}

static int is_float(HSQUIRRELVM v, int index)
{
  return (OT_FLOAT == sq_gettype(v, index));
}

static int is_number(HSQUIRRELVM v, int index)
{
  return is_integer(v, index) || is_float(v, index);
}

static int is_bool(HSQUIRRELVM v, int index)
{
  return (OT_BOOL == sq_gettype(v, index));
}

static int is_string(HSQUIRRELVM v, int index)
{
  return (OT_STRING == sq_gettype(v, index));
}

static int is_table(HSQUIRRELVM v, int index)
{
  return (OT_TABLE == sq_gettype(v, index));
}

static int is_class(HSQUIRRELVM v, int index)
{
  return (OT_CLASS == sq_gettype(v, index));
}

static int is_userdata(HSQUIRRELVM v, int index)
{
  return (OT_USERDATA == sq_gettype(v, index));
}

static int is_cfunction(HSQUIRRELVM v, int index)
{
  return (OT_NATIVECLOSURE == sq_gettype(v, index));
}

static int is_userpointer(HSQUIRRELVM v, int index)
{
  return (OT_USERPOINTER == sq_gettype(v, index));
}

static int is_instance(HSQUIRRELVM v, int index)
{
  return (OT_INSTANCE == sq_gettype(v, index));
}

static SQInteger print_args(HSQUIRRELVM v)
{
  int n;
  SQInteger nargs = sq_gettop(v);
  for (n = 1; n <= nargs; n++)
  {
    printf("arg %d is ", n);
    switch (sq_gettype(v, n))
    {
    case OT_NULL:
      printf("null");
      break;
    case OT_INTEGER:
      printf("integer");
      break;
    case OT_FLOAT:
      printf("float");
      break;
    case OT_STRING:
      printf("string");
      break;
    case OT_TABLE:
      printf("table");
      break;
    case OT_ARRAY:
      printf("array");
      break;
    case OT_USERDATA:
      printf("userdata");
      break;
    case OT_CLOSURE:
      printf("closure(function)");
      break;
    case OT_NATIVECLOSURE:
      printf("native closure(C function)");
      break;
    case OT_GENERATOR:
      printf("generator");
      break;
    case OT_USERPOINTER:
      printf("userpointer");
      break;
    case OT_CLASS:
      printf("class");
      break;
    case OT_INSTANCE:
      printf("instance");
      break;
    case OT_WEAKREF:
      printf("weak reference");
      break;
    default:
      return sq_throwerror(v, "invalid param");
    }
    printf("\n");
  }
}

static const SQChar *obj_tostring(HSQUIRRELVM v, int index)
{
  HSQOBJECT p;
  SQRESULT r;
  const SQChar *ret = 0;
  r = sq_getstackobj(v, index, &p);
  if (SQ_FAILED(r))
  {
    print_error(v, "failed at %s:%d\n", __FILE__, __LINE__);
    return 0;
  }
  ret = sq_objtostring(&p);

  return ret;
}

/*
 * Returns string on top
 */
static const char *get_last_error(HSQUIRRELVM v)
{
  return obj_tostring(v, -1);
}

static SQInteger add_new_function(HSQUIRRELVM v, const char *fname, SQFUNCTION f)
{
#ifdef SWIGRUNTIME_DEBUG
  printf("add_new_function %s\n", fname);
#endif
  assert(is_table(v, -1) || is_class(v, -1));
  sq_pushstring(v, fname, -1);
  sq_newclosure(v, f, 0);
  sq_newslot(v, -3, SQFalse);

  return 0;
}

static int get_object_by_name(HSQUIRRELVM v, const char *name)
{
  SQRESULT r;
  sq_pushstring(v, name, -1);
  r = sq_get(v, -2);
  if (SQ_SUCCEEDED(r))
  {
    return 1;
  }
  else
  {
    return 0;
  }
}

/* add meta table that is used for getting/setting variables */
static void add_meta_table(HSQUIRRELVM v, SQFUNCTION getter, SQFUNCTION setter, int create_new_table)
{
  if (create_new_table)
  {
    sq_newtable(v);
  }

  add_new_function(v, _SC("_get"), getter);
  add_new_function(v, _SC("_set"), setter);

  /* getter function table */
  sq_pushstring(v, ".get", -1);
  sq_newtable(v);
  sq_newslot(v, -3, SQFalse);

  /* setter function table */
  sq_pushstring(v, ".set", -1);
  sq_newtable(v);
  sq_newslot(v, -3, SQFalse);

  /* set meta table in module */
  if (create_new_table)
  {
    sq_setdelegate(v, -2);
  }
}

/* register meta table for variables */
static void install_variable_functions(HSQUIRRELVM v, const char *name, SQFUNCTION getter, SQFUNCTION setter)
{
  assert(is_table(v, -1) || is_class(v, -1));

  get_object_by_name(v, ".get");
  assert(is_table(v, -1));
  add_new_function(v, name, getter);
  sq_pop(v, 1);

  if (setter)
  {
    get_object_by_name(v, ".set");
    assert(is_table(v, -1));
    add_new_function(v, name, setter);
    sq_pop(v, 1);
  }
}

/* -----------------------------------------------------------------------------
 * global variable support code: modules
 * ----------------------------------------------------------------------------- */

/* the module.get method used for getting linked data */
SWIGINTERN SQInteger SWIG_Squirrel_module_get(HSQUIRRELVM v)
{
  const SQChar *name;
  sq_getstring(v, -1, &name);

#ifdef SWIGRUNTIME_DEBUG
  printf("SWIG_Squirrel_module_get %s\n", name);
#endif

  /* get meta table */
  assert(is_table(v, 1));
  sq_getdelegate(v, 1);
  assert(is_table(v, -1));

  /* get .get table */
  get_object_by_name(v, ".get");
  sq_remove(v, 3);

  if (is_table(v, -1))
  {
    /* push key */
    sq_push(v, 2);
    sq_rawget(v, -2);

    /* remove .get */
    sq_remove(v, 3);

    /* found it so call the fn & return its value */
    if (is_cfunction(v, -1))
    {
      sq_pushroottable(v);
      sq_call(v, 1, 1, SQTrue);
      return 1;
    }
    /* remove top */
    sq_pop(v, 1);
  }

  /* remove .get */
  sq_pop(v, 1);

  return print_error(v, "the index '%s' does not exist", name);
}

/* the module.set method used for setting linked data */
SWIGINTERN SQInteger SWIG_Squirrel_module_set(HSQUIRRELVM v)
{
  const SQChar *name;
  sq_getstring(v, -2, &name);

#ifdef SWIGRUNTIME_DEBUG
  printf("SWIG_Squirrel_module_set %s\n", name);
#endif

  /* get meta table */
  assert(is_table(v, 1));
  sq_getdelegate(v, 1);
  assert(is_table(v, -1));

  /* get .set table */
  get_object_by_name(v, ".set");
  sq_remove(v, 4); /* remove meta table */
  if (is_table(v, -1))
  {
    /* push key */
    sq_push(v, 2);
    sq_rawget(v, -2);

    /* remove .set */
    sq_remove(v, 4);

    /* found it so call the fn & return its value */
    if (is_cfunction(v, -1))
    {
      sq_pushroottable(v);

      /* push value */
      sq_push(v, 3);
      sq_call(v, 2, 0, SQTrue);

      return 0;
    }
    /* remove top */
    sq_pop(v, 1);
  }
  /* remove .set */
  sq_pop(v, 1);

  return print_error(v, "the index '%s' does not exist", name);
}

/* registering a module in squirrel */
SWIGINTERN void  SWIG_Squirrel_module_begin(HSQUIRRELVM v, const char *name)
{
#ifdef SWIGRUNTIME_DEBUG
  printf("SWIG_Squirrel_module_begin %s\n", name);
#endif

  /* create module table */
  assert(is_table(v, -1));
  sq_pushstring(v, name, -1);
  sq_newtable(v);

  /* add meta table */
  add_meta_table(v, SWIG_Squirrel_module_get, SWIG_Squirrel_module_set, 1);

  /* add module table */
  sq_newslot(v, -3, SQFalse);

  get_object_by_name(v, name);
}

/* ending the register */
SWIGINTERN void  SWIG_Squirrel_module_end(HSQUIRRELVM v, const char *name)
{
  sq_pop(v, 1); /* remove module */
#ifdef SWIGRUNTIME_DEBUG
  printf("SWIG_Squirrel_module_end %s\n", name);
#endif
}

/* adding a linked variable to the module */
SWIGINTERN void SWIG_Squirrel_module_add_variable(HSQUIRRELVM v, const char *name, SQFUNCTION getter, SQFUNCTION setter)
{
#ifdef SWIGRUNTIME_DEBUG
  printf("SWIG_Squirrel_module_add_variable %s\n", name);
#endif

  install_variable_functions(v, name, getter, setter);
}

/* adding a function module */
SWIGINTERN void  SWIG_Squirrel_module_add_function(HSQUIRRELVM v, const char *name, SQFUNCTION fn)
{
  add_new_function(v, name, fn);
}

/* -----------------------------------------------------------------------------
 * global variable support code: classes
 * ----------------------------------------------------------------------------- */

/* the class.get method used for getting linked data */
SWIGINTERN SQInteger SWIG_Squirrel_class_get(HSQUIRRELVM v)
{
  const SQChar *name;
  sq_getstring(v, -1, &name);

#ifdef SWIGRUNTIME_DEBUG
  printf("SWIG_Squirrel_class_get %s\n", name);
#endif

  /* get .get table */
  assert(is_instance(v, 1));
  sq_getclass(v, 1); /* get class info */

  get_object_by_name(v, ".get");
  sq_remove(v, -2);  /* remove class info */

  if (is_table(v, -1))
  {
    /* push key */
    sq_push(v, 2);
    if (SQ_SUCCEEDED(sq_rawget(v, -2)))
    {
      /* remove .get */
      sq_remove(v, 3);

      /* found it so call the fn & return its value */
      if (is_cfunction(v, -1))
      {
        /* param 1: push instance */
        sq_push(v, 1);
        sq_call(v, 1, 1, SQTrue);
        return 1;
      }
    }
    else
    {
      /* remove key */
      sq_pop(v, 1);
    }
  }

  /* remove .get */
  sq_pop(v, 1);

  return print_error(v, "the index '%s' does not exist", name);
}

/* the class.set method used for setting linked data */
SWIGINTERN SQInteger SWIG_Squirrel_class_set(HSQUIRRELVM v)
{
  const SQChar *name;
  sq_getstring(v, -2, &name);

#ifdef SWIGRUNTIME_DEBUG
  printf("SWIG_Squirrel_class_set %s\n", name);
#endif

  /* get .set table */
  assert(is_instance(v, 1));
  sq_getclass(v, 1); /* get class info */

  get_object_by_name(v, ".set");
  sq_remove(v, -2);  /* remove class info */
  if (is_table(v, -1))
  {
    /* push key */
    sq_push(v, 2);
    sq_rawget(v, -2);

    /* remove .set */
    sq_remove(v, 4);

    /* found it so call the fn & return its value */
    if (is_cfunction(v, -1))
    {
      /* param 1: push instance */
      sq_push(v, 1);

      /* param 2: push value */
      sq_push(v, 3);

      sq_call(v, 2, 0, SQTrue);

      return 0;
    }
    /* remove top */
    sq_pop(v, 1);
  }
  /* remove .set */
  sq_pop(v, 1);

  return print_error(v, "the index '%s' does not exist", name);
}

/* Install Constants */
SWIGINTERN void
SWIG_Squirrel_InstallConstants(HSQUIRRELVM v, swig_squirrel_const_info constants[])
{
  assert(is_table(v, -1) || is_class(v, -1));

  int i;
  for (i = 0; constants[i].type; i++)
  {
#ifdef SWIGRUNTIME_DEBUG
    printf("SWIG_Squirrel_InstallConstants: add constant %s\n", constants[i].name);
#endif
    switch (constants[i].type)
    {
    case SWIG_SQUIRREL_INT:
      sq_pushstring(v, constants[i].name, -1);
      sq_pushinteger(v, (SQInteger)constants[i].lvalue);
      sq_newslot(v, -3, SQTrue);
      break;
    case SWIG_SQUIRREL_FLOAT:
      sq_pushstring(v, constants[i].name, -1);
      sq_pushfloat(v, (SQFloat)constants[i].dvalue);
      sq_newslot(v, -3, SQTrue);
      break;
    case SWIG_SQUIRREL_STRING:
      sq_pushstring(v, constants[i].name, -1);
      sq_pushstring(v, (char *) constants[i].pvalue, -1);
      sq_newslot(v, -3, SQTrue);
      break;
    default:
      break;
    }
  }
}

/* helper add a variable to a registered class */
SWIGINTERN void  SWIG_Squirrel_add_class_variable(HSQUIRRELVM v, const char *name, SQFUNCTION getter, SQFUNCTION setter)
{
#ifdef SWIGRUNTIME_DEBUG
  printf("SWIG_Squirrel_add_class_variable %s\n", name);
#endif

  install_variable_functions(v, name, getter, setter);
}

/* helper to recursively add class details (attributes & operations) */
SWIGINTERN void  SWIG_Squirrel_add_class_details(HSQUIRRELVM v, swig_squirrel_class *clss)
{
  int i;
  /* call all the base classes first: we can then override these later */
  for (i = 0; clss->bases[i]; i++)
  {
    SWIG_Squirrel_add_class_details(v, clss->bases[i]);
  }

  for (i = 0; clss->attributes[i].name; i++)
  {
    SWIG_Squirrel_add_class_variable(v, clss->attributes[i].name, clss->attributes[i].getmethod, clss->attributes[i].setmethod);
  }

  for (i = 0; clss->methods[i].name; i++)
  {
    add_new_function(v, clss->methods[i].name, clss->methods[i].method);
  }

  SWIG_Squirrel_InstallConstants(v, clss->constants);
}

/* performs the entire class registration process */
SWIGINTERN void  SWIG_Squirrel_class_register(HSQUIRRELVM v, swig_squirrel_class *clss)
{
#ifdef SWIGRUNTIME_DEBUG
  printf("SWIG_Squirrel_class_register %s\n", clss->name);
#endif

  // Create class
  sq_pushstring(v, clss->name, -1);
  sq_newclass(v, SQFalse);

  // Add constructor
  if (clss->constructor)
  {
    add_new_function(v, "constructor", clss->constructor);
  }

  /* add meta table */
  add_meta_table(v, SWIG_Squirrel_class_get, SWIG_Squirrel_class_set, 0);

  /* Add class details */
  SWIG_Squirrel_add_class_details(v, clss);

  /* Register new class */
  sq_newslot(v, -3, SQFalse);
}

/* -----------------------------------------------------------------------------
 * Class/structure conversion fns
 * ----------------------------------------------------------------------------- */

/* pushes a new object into the squirrel stack */
SWIGRUNTIME void SWIG_Squirrel_NewPointerObj(HSQUIRRELVM v, void *ptr, swig_type_info *type, int own)
{
  swig_squirrel_userdata *usr;
  if (!ptr)
  {
    sq_pushnull(v);
    return;
  }
  usr = (swig_squirrel_userdata *)sq_newuserdata(v, sizeof(swig_squirrel_userdata));
  usr->ptr = ptr;
  usr->type = type;
  usr->own = own;
}

/* takes a object from the squirrel stack & converts it into an object of the correct type (if possible) */
SWIGRUNTIME int SWIG_Squirrel_ConvertPtr(HSQUIRRELVM v, int index, void **ptr, swig_type_info *type, int flags)
{
  SQRESULT result;
  swig_squirrel_userdata *usr;
  swig_cast_info *cast;
  result = sq_getuserdata(v, index, (SQUserPointer *) &usr, 0);
  if (SQ_SUCCEEDED(result))
  {
    cast = SWIG_TypeCheckStruct(usr->type, type);
    if (cast)
    {
      int newmemory = 0;
      *ptr = SWIG_TypeCast(cast, usr->ptr, &newmemory);
      assert(!newmemory); /* newmemory handling not yet implemented */
      return 0;
    }
  }
  return 1;
}

SWIGRUNTIME void *SWIG_Squirrel_MustGetPtr(HSQUIRRELVM v, int index, swig_type_info *type, int flags,
    int argnum, const char *func_name)
{
  void *result;

  if (SWIG_ConvertPtr(v, index, &result, type, flags))
  {

    print_error(v, "Error in %s, expected a %s at argument number %d\n",
                func_name, type->str ? type->str : "void*", argnum);
  }

  return result;
}

/* -----------------------------------------------------------------------------
 * global variable support code: class/struct typemap functions
 * ----------------------------------------------------------------------------- */

/* storing/access of swig_module_info */
SWIGRUNTIME swig_module_info *
SWIG_Squirrel_GetModule(HSQUIRRELVM v)
{
  swig_module_info *ret = 0;
  SQRESULT r;
  sq_pushregistrytable(v);
  sq_pushstring(v, "swig_runtime_data_type_pointer" SWIG_RUNTIME_VERSION SWIG_TYPE_TABLE_NAME, -1);
  r = sq_rawget(v, -2);
  if (SQ_FAILED(r))
  {
    sq_pop(v, 1);
    return 0;
  }
  if (is_userpointer(v, -1))
  {
    sq_getuserpointer(v, -1, (SQUserPointer *) &ret);
  }
  sq_pop(v, 1);
  sq_pop(v, 1);

  return ret;
}

SWIGRUNTIME void
SWIG_Squirrel_SetModule(HSQUIRRELVM v, swig_module_info *module)
{
  sq_pushregistrytable(v);

  /* add this all into the registry: */
  sq_pushstring(v, "swig_runtime_data_type_pointer" SWIG_RUNTIME_VERSION SWIG_TYPE_TABLE_NAME, -1);
  sq_pushuserpointer(v, (SQUserPointer)module);
  sq_rawset(v, -3);
  sq_pop(v, 1);

}

#ifdef __cplusplus
}
#endif