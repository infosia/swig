#include "swigmod.h"

static const char *usage = (char *) "\
Squirrel Options (available with -squirrel)\n\
    -debug        Enable debug output \
\n";

static int debug_output = 0;

#define REPORT(T,D)   {if (debug_output) { Printf(stdout,T"\n");if(D)Swig_print_node(D); } }

class SQUIRREL: public Language
{
private:

  File *f_begin;
  File *f_runtime;
  File *f_header;
  File *f_wrappers;
  File *f_init;
  File *f_initbeforefunc;

  String *s_cmd_tab;          // table of command names
  String *s_var_tab;          // table of global variables
  String *s_const_tab;      // table of global constants
  String *s_methods_tab;  // table of class methods
  String *s_attr_tab;   // table of class attributes
  String *s_sattr_tab;  // table of class static attributes

  int have_constructor;
  int have_destructor;
  String *class_name;
  String *constructor_name;
  bool is_class_struct;

public:

  SQUIRREL() :
    f_begin(0),
    f_runtime(0),
    f_header(0),
    f_wrappers(0),
    f_init(0),
    f_initbeforefunc(0),
    s_cmd_tab(0),
    s_var_tab(0),
    s_const_tab(0),
    is_class_struct(false)
  {
  }

  /* ---------------------------------------------------------------------
  * main()
  *
  * Parse command line options and initializes variables.
  * --------------------------------------------------------------------- */
  virtual void main(int argc, char *argv[])
  {

    /* Set location of SWIG library */
    SWIG_library_directory("squirrel");

    /* Look for certain command line options */
    for (int i = 1; i < argc; i++)
    {
      if (argv[i])
      {
        if (strcmp(argv[i], "-help") == 0)      // usage flags
        {
          fputs(usage, stdout);
        }
        else if (strcmp(argv[i], "-debug") == 0)
        {
          debug_output = 1;
          Swig_mark_arg(i);
        }
      }
    }

    /* Add a symbol to the parser for conditional compilation */
    Preprocessor_define("SWIGSQUIRREL 1", 0);

    /* Set language-specific configuration file */
    SWIG_config_file("squirrel.swg");

    /* Set typemap language */
    SWIG_typemap_lang("squirrel");

    /* Enable overloaded methods support */
    allow_overloading();
  }

  virtual int top(Node *n)
  {
    /* Get the module name */
    String *module = Getattr(n, "name");

    /* Get the output file name */
    String *outfile = Getattr(n, "outfile");

    /* Open the output file */
    f_begin = NewFile(outfile, "w", SWIG_output_files());
    if (!f_begin)
    {
      FileErrorDisplay(outfile);
      SWIG_exit(EXIT_FAILURE);
    }

    f_runtime = NewString("");
    f_init = NewString("");
    f_header = NewString("");
    f_wrappers = NewString("");
    f_initbeforefunc = NewString("");

    /* Register file targets with the SWIG file handler */
    Swig_register_filebyname("header", f_header);
    Swig_register_filebyname("wrapper", f_wrappers);
    Swig_register_filebyname("begin", f_begin);
    Swig_register_filebyname("runtime", f_runtime);
    Swig_register_filebyname("init", f_init);
    Swig_register_filebyname("initbeforefunc", f_initbeforefunc);

    // Initialize some variables for the object interface
    s_cmd_tab = NewString("");
    s_var_tab = NewString("");
    s_const_tab = NewString("");

    /* Standard stuff for the SWIG runtime section */
    Swig_banner(f_begin);

    Printf(f_runtime, "\n");
    Printf(f_runtime, "#define SWIGSQUIRREL\n");
    Printf(f_runtime, "#define SWIG_MODULE_NAME \"%s\"\n",  module);

    if (debug_output)
    {
      Printf(f_runtime, "#define SWIGRUNTIME_DEBUG\n");
    }

    Printf(f_runtime, "\n");

    Printf(f_header, "#define SWIG_init      %s_init\n", module);

    Printf(s_cmd_tab,   "\nstatic const swig_squirrel_command_info swig_commands[] = {\n");
    Printf(s_var_tab,   "\nstatic const swig_squirrel_var_info swig_variables[] = {\n");
    Printf(s_const_tab, "\nstatic swig_squirrel_const_info swig_constants[] = {\n");

    Printf(f_wrappers, "#ifdef __cplusplus\nextern \"C\" {\n#endif\n");

    Language::top(n);

    /* %init code inclusion, effectively in the SWIG_init function */
    Printf(f_wrappers, "#ifdef __cplusplus\n}\n#endif\n");

    Printv(s_cmd_tab, tab4, "{0,0}\n", "};\n", NIL);
    Printv(s_var_tab, tab4, "{0,0,0}\n", "};\n", NIL);
    Printv(s_const_tab, tab4, "{0,0,0,0,0,0}\n", "};\n", NIL);

    Printv(f_wrappers, s_cmd_tab, s_var_tab, s_const_tab, NIL);
    SwigType_emit_type_table(f_runtime, f_wrappers);

    Dump(f_runtime, f_begin);
    Dump(f_header, f_begin);
    Dump(f_wrappers, f_begin);
    Dump(f_initbeforefunc, f_begin);

    Wrapper_pretty_print(f_init, f_begin);

    Delete(s_cmd_tab);
    Delete(s_var_tab);
    Delete(s_const_tab);
    Delete(f_header);
    Delete(f_wrappers);
    Delete(f_init);
    Delete(f_initbeforefunc);
    Delete(f_runtime);
    Delete(f_begin);

    return SWIG_OK;
  }

  /* ---------------------------------------------------------------------
   * functionWrapper()
   *
   * Create a function declaration and register it with the interpreter.
   * --------------------------------------------------------------------- */
  virtual int functionWrapper(Node *n)
  {
    REPORT("functionWrapper", n);

    String *name = Getattr(n, "name");
    String *iname = Getattr(n, "sym:name");
    SwigType *d = Getattr(n, "type");
    ParmList *l = Getattr(n, "parms");

    bool is_constructor = GetFlag(n, "feature:new");
    bool is_classmember = checkAttribute(n, "ismember", "1") ;

    Parm *p;
    String *tm;
    int i;

    String *overname = 0;
    if (Getattr(n, "sym:overloaded"))
    {
      overname = Getattr(n, "sym:overname");
    }
    else
    {
      if (!addSymbol(iname, n))
      {
        Printf(stderr, "addSymbol(%s) failed\n", iname);
        return SWIG_ERROR;
      }
    }

    Wrapper *f = NewWrapper();

    String *wname = Swig_name_wrapper(iname);
    if (overname)
    {
      Append(wname, overname);
    }

    if (is_constructor && !is_class_struct) 
    {
      Printv(f->def, "static SQInteger ", Swig_name_wrapper(Swig_name_destroy(NSPACE_TODO, name)), "(SQUserPointer p, SQInteger size);\n", NIL);
    }

    Printv(f->def, "static SQInteger ", wname, "(HSQUIRRELVM v) {", NIL);

    /* Write code to extract function parameters. */
    emit_parameter_variables(l, f);

    /* Attach the standard typemaps */
    emit_attach_parmmaps(l, f);
    Setattr(n, "wrap:parms", l);

    /* Get number of required and total arguments */
    int num_arguments = emit_num_arguments(l);
    int num_required = emit_num_required(l);
    int varargs = emit_isvarargs(l);

    /* Generate code for argument marshalling */
    String *argument_check = NewString("");
    String *argument_parse = NewString("");
    String *checkfn = NULL;
    char source[64];

    /*
     * $input index for standard function starts from 2
     * because Squirrel's arg index starts from 1 and
     * it pushes root table or class instance for index 1
     */
    int input_base_index  = 0;
    /*
     * $input index for class member function starts from 1, otherwise 2
     * because Squirrel pushes class instance first for class members,
     * otherwise pushes root table for index 1
     */
    if (!is_constructor && is_classmember)
    {
      input_base_index = 1;
    }
    else
    {
      input_base_index = 2;
    }

    for (i = 0, p = l; i < num_arguments; i++)
    {

      while (checkAttribute(p, "tmap:in:numinputs", "0"))
      {
        p = Getattr(p, "tmap:in:next");
      }

      SwigType *pt = Getattr(p, "type");
      String *ln = Getattr(p, "lname");

      /* Look for an input typemap */
      sprintf(source, "%d", i + input_base_index);

      if ((tm = Getattr(p, "tmap:in")))
      {

        Replaceall(tm, "$source", source);
        Replaceall(tm, "$target", ln);
        Replaceall(tm, "$input", source);
        Setattr(p, "emit:input", source);

        if (Getattr(p, "wrap:disown") || (Getattr(p, "tmap:in:disown")))
        {
          Replaceall(tm, "$disown", "SWIG_POINTER_DISOWN");
        }
        else
        {
          Replaceall(tm, "$disown", "0");
        }

        /* first argument for class members needs special treatment (SQUserPointer) */
        if (i == 0 && !is_constructor && is_classmember)
        {
          Printf(argument_check, "if(!is_instance(v, 1)) ");
          Printf(argument_check, "SWIG_fail_arg(\"%s\",%s,\"%s\");\n", Swig_name_str(n), source, SwigType_str(pt, 0));
          Printf(argument_parse, "sq_getinstanceup(v, 1, (SQUserPointer*)&%s, 0);\n", ln);

          p = Getattr(p, "tmap:in:next");
          continue;
        }

        if ((checkfn = Getattr(p, "tmap:in:checkfn")))
        {
          if (i < num_required)
          {
            Printf(argument_check, "if(!%s(v,%s))", checkfn, source);
          }
          else
          {
            Printf(argument_check, "if(sq_gettop(v)>=%s && !%s(v,%s))", source, checkfn, source);
          }
          Printf(argument_check, " SWIG_fail_arg(\"%s\",%s,\"%s\");\n", Swig_name_str(n), source, SwigType_str(pt, 0));
        }
        if (i < num_required)
        {
          Printf(argument_parse, "%s\n", tm);
        }
        else
        {
          Printf(argument_parse, "if(sq_gettop(v)>=%s){%s}\n", source, tm);
        }
        p = Getattr(p, "tmap:in:next");
        continue;
      }
      else
      {
        Swig_warning(WARN_TYPEMAP_IN_UNDEF, input_file, line_number, "Unable to use type %s as a function argument.\n", SwigType_str(pt, 0));
        break;
      }
    }

    // add all argcheck code
    Printv(f->code, argument_check, argument_parse, NIL);

    /* Check for trailing varargs */
    if (varargs)
    {
      if (p && (tm = Getattr(p, "tmap:in")))
      {
        Replaceall(tm, "$input", "varargs");
        Printv(f->code, tm, "\n", NIL);

      }
    }

    /* Insert constraint checking code */
    for (p = l; p;)
    {
      if ((tm = Getattr(p, "tmap:check")))
      {
        Replaceall(tm, "$target", Getattr(p, "lname"));
        Printv(f->code, tm, "\n", NIL);
        p = Getattr(p, "tmap:check:next");
      }
      else
      {
        p = nextSibling(p);
      }
    }

    /* Insert cleanup code */
    String *cleanup = NewString("");
    for (p = l; p;)
    {
      if ((tm = Getattr(p, "tmap:freearg")))
      {
        Replaceall(tm, "$source", Getattr(p, "lname"));
        Printv(cleanup, tm, "\n", NIL);
        p = Getattr(p, "tmap:freearg:next");
      }
      else
      {
        p = nextSibling(p);
      }
    }

    /* Insert argument output code */
    String *outarg = NewString("");
    for (p = l; p;)
    {
      if ((tm = Getattr(p, "tmap:argout")))
      {
        Replaceall(tm, "$source", Getattr(p, "lname"));
        Replaceall(tm, "$target", Swig_cresult_name());
        Replaceall(tm, "$arg", Getattr(p, "emit:input"));
        Replaceall(tm, "$input", Getattr(p, "emit:input"));
        Printv(outarg, tm, "\n", NIL);
        p = Getattr(p, "tmap:argout:next");
      }
      else
      {
        p = nextSibling(p);
      }
    }

    Setattr(n, "wrap:name", wname);

    /* Emit the function call */
    String *actioncode = emit_action(n);

    // Return value if necessary
    if ((tm = Swig_typemap_lookup_out("out", n, Swig_cresult_name(), f, actioncode)) && !is_constructor)
    {
      Replaceall(tm, "$source", Swig_cresult_name());
      Replaceall(tm, "$owner", "0");

      Printf(f->code, "%s\n", tm);
    }
    else
    {
      Swig_warning(WARN_TYPEMAP_OUT_UNDEF, input_file, line_number, "Unable to use return type %s in function %s.\n", SwigType_str(d, 0), name);
    }
    emit_return_variable(n, d, f);

    /* Output argument output code */
    Printv(f->code, outarg, NIL);

    /* Output cleanup code */
    Printv(f->code, cleanup, NIL);

    /* Look to see if there is any newfree cleanup code */
    if (is_constructor)
    {
      if ((tm = Swig_typemap_lookup("newfree", n, Swig_cresult_name(), 0)))
      {
        Replaceall(tm, "$source", Swig_cresult_name());
        Printf(f->code, "%s\n", tm);
      }
    }

    /* See if there is any return cleanup code */
    if ((tm = Swig_typemap_lookup("ret", n, Swig_cresult_name(), 0)))
    {
      Replaceall(tm, "$source", Swig_cresult_name());
      Printf(f->code, "%s\n", tm);
    }

    /* Create new class */
    if (is_constructor)
    {
      Printf(f->code, "  sq_setinstanceup(v, 1, result);\n");
      Printf(f->code, "  sq_setreleasehook(v, 1, %s);\n", Swig_name_wrapper(Swig_name_destroy(getNSpace(), class_name)));
    }

    /* Close the function */
    if (is_constructor)
    {
      Printf(f->code, "return %d;\n", 0);
    }
    else
    {
      Printf(f->code, "return %d;\n", SwigType_isvoid(d) ? 0 : 1);
    }

    // add the failure cleanup code:
    Printv(f->code, "\nfail:\n", NIL);
    Printv(f->code, "$cleanup",
           "print_error(v, \"error at %s:%d, %s\",__FILE__, __LINE__, get_last_error(v)); ", NIL);

    Printv(f->code, "return SQ_ERROR;\n", NIL);
    Printf(f->code, "}\n");

    /* Substitute the cleanup code */
    Replaceall(f->code, "$cleanup", cleanup);

    /* Substitute the function name */
    Replaceall(f->code, "$symname", iname);
    Replaceall(f->code, "$result", Swig_cresult_name());

    /* Dump the function out */
    Wrapper_print(f, f_wrappers);

    /* Now register the function with the interpreter. */
    if (!Getattr(n, "sym:overloaded"))
    {
      if (!checkAttribute(n, "kind", "variable") && !checkAttribute(n, "ismember", "1"))
      {
        Printv(s_cmd_tab, tab4, "{ \"", iname, "\", ", Swig_name_wrapper(iname), "},\n", NIL);
      }
    }
    else
    {
      if (!Getattr(n, "sym:nextSibling"))
      {
        dispatchFunction(n);
      }
    }

    Delete(argument_check);
    Delete(argument_parse);

    Delete(cleanup);
    Delete(outarg);
    Delete(wname);
    DelWrapper(f);

    return SWIG_OK;
  }

  int SwigType_isvoid(const SwigType *t)
  {
    char *c = Char(t);
    if (!t)
      return 0;
    if (strcmp(c, "void") == 0)
    {
      return 1;
    }
    return 0;
  }

  /* ------------------------------------------------------------
   * dispatchFunction()
   *
   * Emit overloading dispatch function
   * ------------------------------------------------------------ */
  void dispatchFunction(Node *n)
  {
    /* Last node in overloaded chain */

    int maxargs;
    String *tmp = NewString("");
    String *dispatch = Swig_overload_dispatch(n, "return %s(v);", &maxargs);

    /* Generate a dispatch wrapper for all overloaded functions */

    Wrapper *f       = NewWrapper();
    String  *symname = Getattr(n, "sym:name");
    String  *wname   = Swig_name_wrapper(symname);

    Printv(f->def,
           "static SQInteger ", wname, "(HSQUIRRELVM v) {",
           NIL);
    Wrapper_add_local(f, "argc", "int argc");
    Printf(tmp, "int argv[%d]={1", maxargs + 1);
    for (int i = 1; i <= maxargs; i++)
    {
      Printf(tmp, ",%d", i + 1);
    }
    Printf(tmp, "}");
    Wrapper_add_local(f, "argv", tmp);
    Printf(f->code, "argc = sq_gettop(v);\n");

    Replaceall(dispatch, "$args", "self,args");
    Printv(f->code, dispatch, "\n", NIL);
    Printf(f->code, "print_error(v,\"No matching function for overloaded '%s'\");\n", symname);
    Printf(f->code, "return SQ_ERROR;\n");
    Printv(f->code, "}\n", NIL);
    Wrapper_print(f, f_wrappers);
    Printv(s_cmd_tab, tab4, "{ \"", symname, "\",", wname, "},\n", NIL);

    DelWrapper(f);
    Delete(dispatch);
    Delete(tmp);
    Delete(wname);
  }

  /* ------------------------------------------------------------
   * variableWrapper()
   * ------------------------------------------------------------ */
  virtual int variableWrapper(Node *n)
  {
    REPORT("variableWrapper", n);

    String *iname = Getattr(n, "sym:name");
    // let SWIG generate the wrappers
    int result = Language::variableWrapper(n);
    // normally SWIG will generate 2 wrappers, a get and a set
    // but in certain scenarios (immutable, or if its arrays), it will not
    String *getName = Swig_name_wrapper(Swig_name_get(getNSpace(), iname));
    String *setName = 0;
    // checking whether it can be set to or not appears to be a very error prone issue
    // I referred to the Language::variableWrapper() to find this out
    bool assignable = is_assignable(n) ? true : false;
    SwigType *type = Getattr(n, "type");
    String *tm = Swig_typemap_lookup("globalin", n, iname, 0);
    if (!tm && SwigType_isarray(type))
      assignable = false;
    Delete(tm);

    if (assignable)
    {
      setName = Swig_name_wrapper(Swig_name_set(getNSpace(), iname));
    }
    else
    {
      setName = NewString("0");
    }

    // register the variable
    if (checkAttribute(n, "ismember", "1"))
    {
      String *name = Getattr(n, "name");
      String *membername = Getattr(n, "staticmembervariableHandler:sym:name");

      Replaceall(name, "::", ".");

      if (membername && name)
      {
        Printf(s_attr_tab, "%s{ \"%s\", %s, %s },\n", tab4, membername, getName, setName);
        Printf(s_var_tab,  "%s{ \"%s\", %s, %s },\n", tab4, name, getName, setName);
      }
    }
    else
    {
      Printf(s_var_tab, "%s{ \"%s\", %s, %s },\n", tab4, iname, getName, setName);
    }

    Delete(getName);
    Delete(setName);
    return result;
  }

  /* ------------------------------------------------------------
   * constantWrapper()
   * ------------------------------------------------------------ */
  virtual int constantWrapper(Node *n)
  {
    REPORT("constantWrapper", n);

    String *name = Getattr(n, "name");
    String *iname = Getattr(n, "sym:name");
    String *nsname = Copy(iname);
    SwigType *type = Getattr(n, "type");
    String *value = Getattr(n, "value");
    String *tm;

    if (!addSymbol(iname, n))
      return SWIG_ERROR;

    /* Special hook for member pointer */
    if (SwigType_type(type) == T_MPOINTER)
    {
      String *wname = Swig_name_wrapper(iname);
      Printf(f_wrappers, "static %s = %s;\n", SwigType_str(type, wname), value);
      value = Char(wname);
    }

    if ((tm = Swig_typemap_lookup("consttab", n, name, 0)))
    {
      Replaceall(tm, "$source", value);
      Replaceall(tm, "$target", name);
      Replaceall(tm, "$value", value);
      Replaceall(tm, "$nsname", nsname);

      if (checkAttribute(n, "ismember", "1")) {
        Replaceall(tm, "$constname", Getattr(n, "memberconstantHandler:sym:name"));
        Printf(s_sattr_tab, "  %s,\n", tm);
      } else {
        Replaceall(tm, "$constname", iname);
        Printf(s_const_tab, "  %s,\n", tm);
      }
    }
    else if ((tm = Swig_typemap_lookup("constcode", n, name, 0)))
    {
      Replaceall(tm, "$source", value);
      Replaceall(tm, "$target", name);
      Replaceall(tm, "$value", value);
      Replaceall(tm, "$nsname", nsname);
      Replaceall(tm, "$constname", iname);
      Printf(f_init, "%s\n", tm);
    }
    else
    {
      Delete(nsname);
      Swig_warning(WARN_TYPEMAP_CONST_UNDEF, input_file, line_number, "Unsupported constant value.\n");
      return SWIG_NOWRAP;
    }
    Delete(nsname);
    return SWIG_OK;
  }


  /* ------------------------------------------------------------
   * nativeWrapper()
   * ------------------------------------------------------------ */

  virtual int nativeWrapper(Node *n)
  {
    return Language::nativeWrapper(n);
  }

  /* ------------------------------------------------------------
   * enumDeclaration()
   * ------------------------------------------------------------ */

  virtual int enumDeclaration(Node *n)
  {
    return Language::enumDeclaration(n);
  }

  /* ------------------------------------------------------------
   * enumvalueDeclaration()
   * ------------------------------------------------------------ */

  virtual int enumvalueDeclaration(Node *n)
  {
    return Language::enumvalueDeclaration(n);
  }

  /* ------------------------------------------------------------
   * classDeclaration()
   * ------------------------------------------------------------ */

  virtual int classDeclaration(Node *n)
  {
    return Language::classDeclaration(n);
  }

  /* ------------------------------------------------------------
   * classHandler()
   * ------------------------------------------------------------ */

  virtual int classHandler(Node *n)
  {
    REPORT("classHandler", n);

    String *mangled_classname = 0;
    String *real_classname = 0;

    constructor_name = 0;
    have_constructor = 0;
    have_destructor = 0;

    is_class_struct = checkAttribute(n, "kind", "struct") ;

    class_name = Getattr(n, "sym:name");
    if (!addSymbol(class_name, n))
      return SWIG_ERROR;

    real_classname = Getattr(n, "name");
    mangled_classname = Swig_name_mangle(real_classname);

    static Hash *emitted = NewHash();
    if (Getattr(emitted, mangled_classname))
      return SWIG_NOWRAP;
    Setattr(emitted, mangled_classname, "1");

    s_attr_tab = NewString("");
    Printf(s_attr_tab, "static swig_squirrel_attribute swig_");
    Printv(s_attr_tab, mangled_classname, "_attributes[] = {\n", NIL);

    s_methods_tab = NewString("");
    Printf(s_methods_tab, "static swig_squirrel_method swig_");
    Printv(s_methods_tab, mangled_classname, "_methods[] = {\n", NIL);

    s_sattr_tab = NewString("");
    Printf(s_sattr_tab, "static swig_squirrel_const_info swig_");
    Printv(s_sattr_tab, mangled_classname, "_constants[] = {\n", NIL);

    // Generate normal wrappers
    Language::classHandler(n);

    SwigType *t = Copy(Getattr(n, "name"));
    SwigType_add_pointer(t);

    // Catch all: eg. a class with only static functions and/or variables will not have 'remembered'
    String *wrap_class = NewStringf("&_wrap_class_%s", mangled_classname);
    SwigType_remember_clientdata(t, wrap_class);

    String *rt = Copy(getClassType());
    SwigType_add_pointer(rt);

    Printf(s_methods_tab, "    {0,0}\n};\n");
    Printv(f_wrappers, s_methods_tab, NIL);

    Printf(s_attr_tab, "    {0,0,0}\n};\n");
    Printv(f_wrappers, s_attr_tab, NIL);

    Printf(s_sattr_tab, "    {0,0,0,0,0,0}\n};\n");
    Printv(f_wrappers, s_sattr_tab, NIL);

    Delete(s_methods_tab);
    Delete(s_attr_tab);
    Delete(s_sattr_tab);

    String *base_class = NewString("");
    String *base_class_names = NewString("");

    List *baselist = Getattr(n, "bases");
    if (baselist && Len(baselist))
    {
      Iterator b;
      int index = 0;
      b = First(baselist);
      while (b.item)
      {
        String *bname = Getattr(b.item, "name");
        if ((!bname) || GetFlag(b.item, "feature:ignore") || (!Getattr(b.item, "module")))
        {
          b = Next(b);
          continue;
        }
        Printf(base_class, "&_wrap_class_%s,", Swig_name_mangle(bname));
        Printf(base_class_names, "\"%s *\",", SwigType_namestr(bname));

        b = Next(b);
        index++;
      }
    }

    Printv(f_wrappers, "static swig_squirrel_class *swig_", mangled_classname, "_bases[] = {", base_class, "0};\n", NIL);
    Delete(base_class);
    Printv(f_wrappers, "static const char *swig_", mangled_classname, "_base_names[] = {", base_class_names, "0};\n", NIL);
    Delete(base_class_names);

    // name space
    String *nspace_names = NewString("");
    String *nspace = Getattr(n, "sym:nspace");

    if (nspace) {
      Replaceall(nspace, ".", "::");
      String *nspace_first;
      String *nspace_suffix = Copy(nspace);
      while((nspace_first = Swig_scopename_first(nspace_suffix))) {

        Printf(nspace_names, "\"%s\",", nspace_first);
        Delete(nspace_first);

        String *nspace_token = Swig_scopename_suffix(nspace_suffix);
        Delete(nspace_suffix);

        nspace_suffix = Copy(nspace_token);
      }
      Printf(nspace_names, "\"%s\",", nspace_suffix);
      Delete(nspace_suffix);
    }

    Printv(f_wrappers, "static const char *swig_", mangled_classname, "_nspace[] = {", nspace_names, "0};\n", NIL);
    Delete(nspace_names);

    /* swig_squirrel_class start */
    Printv(f_wrappers, "static swig_squirrel_class _wrap_class_", mangled_classname, " = { \"", class_name, "\", &SWIGTYPE", SwigType_manglestr(t), ", ", NIL);

    if (have_constructor)
    {
      Printf(f_wrappers, "%s", Swig_name_wrapper(Swig_name_construct(getNSpace(), constructor_name)));
      Delete(constructor_name);
      constructor_name = 0;
    }
    else
    {
      Printf(f_wrappers, "0");
    }

    if (have_destructor)
    {
      Printv(f_wrappers, ", ", Swig_name_wrapper(Swig_name_destroy(getNSpace(), class_name)));
    }
    else
    {
      Printf(f_wrappers, ", 0");
    }

    Printf(f_wrappers, ", swig_%s_methods, swig_%s_attributes, swig_%s_bases, swig_%s_base_names, swig_%s_constants, swig_%s_nspace };\n\n",
           mangled_classname, mangled_classname, mangled_classname, mangled_classname, mangled_classname, mangled_classname);
    /* swig_squirrel_class end */

    Delete(t);
    Delete(mangled_classname);
    return SWIG_OK;
  }

  /* ------------------------------------------------------------
   * memberfunctionHandler()
   * ------------------------------------------------------------ */

  virtual int memberfunctionHandler(Node *n)
  {
    REPORT("memberfunctionHandler", n);

    String *name = Getattr(n, "name");
    String *iname = GetChar(n, "sym:name");

    if (Cmp(Getattr(n, "sym:name"), "__unm") == 0)
    {
      SetInt(n, "squirrel:ignore_args", 1);
    }

    String *realname, *rname;

    Language::memberfunctionHandler(n);

    realname = iname ? iname : name;
    rname = Swig_name_wrapper(Swig_name_member(getNSpace(), class_name, realname));
    if (!Getattr(n, "sym:nextSibling"))
    {
      Printv(s_methods_tab, tab4, "{\"", realname, "\", ", rname, "}, \n", NIL);
    }
    Delete(rname);
    return SWIG_OK;
  }

  /* ------------------------------------------------------------
   * membervariableHandler()
   * ------------------------------------------------------------ */

  virtual int membervariableHandler(Node *n)
  {
    REPORT("membervariableHandler", n);
    String *symname = Getattr(n, "sym:name");
    String *gname, *sname;

    Language::membervariableHandler(n);

    gname = Swig_name_wrapper(Swig_name_get(getNSpace(), Swig_name_member(NSPACE_TODO, class_name, symname)));
    if (!GetFlag(n, "feature:immutable"))
    {
      sname = Swig_name_wrapper(Swig_name_set(getNSpace(), Swig_name_member(NSPACE_TODO, class_name, symname)));
    }
    else
    {
      sname = NewString("0");
    }
    Printf(s_attr_tab, "%s{ \"%s\", %s, %s},\n", tab4, symname, gname, sname);
    Delete(gname);
    Delete(sname);
    return SWIG_OK;
  }

  /* ------------------------------------------------------------
   * constructorHandler()
   *
   * Method for adding C++ member constructor
   * ------------------------------------------------------------ */

  virtual int constructorHandler(Node *n)
  {
    REPORT("constructorHandler", n);
    Language::constructorHandler(n);
    constructor_name = NewString(Getattr(n, "sym:name"));
    have_constructor = 1;
    return SWIG_OK;
  }

  /* ------------------------------------------------------------
   * destructorHandler()
   * ------------------------------------------------------------ */

  virtual int destructorHandler(Node *n)
  {
    REPORT("destructorHandler", n);
    //Language::destructorHandler(n);
    have_destructor = 1;

    String *real_classname = Getattr(n, "sym:name");
    bool is_extend = checkAttribute(n, "feature:extend", "1");

    String *destructor_code = Getattr(n, "code");
    String *self = NewString("");

    Printf(self, "(%s *) p", real_classname);

    Replaceall(destructor_code, "$self", self);

    if (is_class_struct)
    {
      Printv(f_wrappers, "static SQInteger ", Swig_name_wrapper(Swig_name_destroy(NSPACE_TODO, real_classname)), "(SQUserPointer p, SQInteger size) {\n", NIL);
      if (is_extend) {
        Printv(f_wrappers, tab2, destructor_code, "\n", NIL);
      } else {
        Printv(f_wrappers, "  free(", self, ");\n", NIL);
      }
      Printf(f_wrappers, "}\n");
    }
    else
    {
      Printv(f_wrappers, "static SQInteger ", Swig_name_wrapper(Swig_name_destroy(NSPACE_TODO, real_classname)), "(SQUserPointer p, SQInteger size) {\n", NIL);
      if (is_extend) {
        Printv(f_wrappers, tab2, destructor_code, "\n", NIL);
      } else {
        Printv(f_wrappers, "#ifdef __cplusplus\n");
        Printv(f_wrappers, "  delete ", self, ";\n", NIL);
        Printv(f_wrappers, "#else\n");
        Printv(f_wrappers, "  free(", self, ");\n", NIL);
        Printv(f_wrappers, "#endif\n");
      }
      Printf(f_wrappers, "}\n");
    }

    Delete(self);

    return SWIG_OK;
  }

  /* -----------------------------------------------------------------------
   * staticmemberfunctionHandler()
   *
   * Wrap a static C++ function
   * ---------------------------------------------------------------------- */

  virtual int staticmemberfunctionHandler(Node *n)
  {
    return Language::staticmemberfunctionHandler(n);
  }

  /* ------------------------------------------------------------
   * memberconstantHandler()
   *
   * Create a C++ constant
   * ------------------------------------------------------------ */

  virtual int memberconstantHandler(Node *n)
  {
    return Language::memberconstantHandler(n);
  }

  /* ---------------------------------------------------------------------
   * staticmembervariableHandler()
   * --------------------------------------------------------------------- */

  virtual int staticmembervariableHandler(Node *n)
  {
    return Language::staticmembervariableHandler(n);
  }

};

extern "C" Language *swig_squirrel(void)
{
  return new SQUIRREL();
}
