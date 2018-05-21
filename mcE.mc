#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <math.h>
#include <setjmp.h>
#include <time.h>
#include <dlfcn.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/file.h>
#include <fcntl.h>
#include <string.h>
#include "mc.h"

expptr file_preamble;
expptr env_syms;

expptr decl_symbol(expptr decl);
expptr strip_body(expptr e);
int procedurep(expptr sym);
int arrayp(expptr sym);
int newp(expptr sym);
int installedp(expptr form);
expptr args_variables(expptr args);
expptr args_types(expptr args);

void install(expptr decl);
void write_new_definitions();
expptr hybernations();
voidptr compile_load_file(charptr fname);

void write_declarations();
expptr array_awakenings();

/** ========================================================================
Intuitively the REPL can perform the different actions of declaring data variables, defining procedures, and executing statements.

Each iteration of the REPL writes a C file, compiles the file into a DLL, loads the DLL and extracts
a main procedure and applies the main procedure to the array symbol_value.

However, in every invocation of REPL the expressions involved are macro expanded.  This means that every invocation must be treated as
performing a sequence of actions of any kind.  So the general case, which is equivalent to loading a file, is used in every invocation of the REPL.
This is done with the procedure load.
======================================================================== **/

/** ========================================================================
The REPL state includes C preprocessor #define statements, type definitions,
and an assignment of values to data variables and procedure names.

The #define statements and type definitions are both stored in a variable called file_preamble.  This is relatively straightforward
and will not be discussed futher in the documentation.

The set of procedure names and data variables is stored in the variable env_syms.

The value of each variable in env_syms is stored in the array symbol_value where we have
that symbol_value[symbol_index(x)] is the value of x.
======================================================================== **/


/** ========================================================================
The load function is given a list of fully macro-expanded expressions.  The types of expressions accepted by
load is defined in the install function.

Arrays are the only supported data variables at this time.  However, note that <type> X[1] is equivalent to <type> * X.
======================================================================== **/

void install(expptr form){ //only the following patterns are allowed.
  ucase{form;
    {typedef !def;}:{install_preamble(form);}
    {typedef !def1,!def2;}:{install_preamble(form);}
    {#define !def}:{install_preamble(form);}
    {#include < !file >}:{install_preamble(form);}
    {#include !x}:{install_preamble(form);}
    {!type ?X[?dim];}:{install_array(X,form);}
    {!type ?f(?args){!body}}:{install_proc(f,form);}}
}

void install_preamble(expptr e){
  if(!installedp(e)){
    file_preamble = append{file_preamble,(cons(e,NULL)));
    setprop(e,`{installed},`{true});}
}

void add_new_symbol(expptr x, expptr decl){
  push(x,env_syms);
  setprop(x,`{declaration},decl);
  setprop(x,`{new},`{true}};
}

void install_array(expptr X, expptr decl){
  expptr old_decl = getprop(X,`{declaration},NULL);
  if(old_decl == NULL){
    add_new_symbol(X,decl);
    return;}
  if(old_decl != decl){
    push_dbg_expression(decl);
    berror("attempt to change array declaration");}
}

void install_proc(expptr f, expptr decl){
  expptr old_decl = getprop(f,`{declaration},NULL);
  if(old_decl == NULL){
    add_new_symbol(X,decl);
    return;}
  ucase{decl;
    {?newtype ?g(!newargs1){!newbody}}:{
      ucase{old_decl;
	{?oldtype ?g(!oldargs){!oldbody}}:{
	  if(newtype != oldtype || newargs!= oldargs){
	    push_dgb_expression(decl);
	    berror("attempt to change procedure signature");}
	  setprop(f,`{declaration} decl);
	  setprop(f,`{new},`{true});}}}}
}

int symbol_count;

int symbol_index(expptr sym){
  int index = (int) getprop(sym, `{index}, (expptr) ((long int) -1));
  if(index == -1){
    if(symbol_count == SYMBOL_DIM){berror("Mc symbol table exhausted");}
    index = symbol_count++;
    setprop(sym,`{index}, (expptr) ((long int) index));
  }
  return index;
}

int newp(expptr sym){
  return getprop(sym,`{new},NULL) == `{true};
}

int installedp(expptr sym){
  return getprop(sym,`{installed},NULL) == `{true};
}

/** ========================================================================
load
======================================================================== **/

int compilecount;

void pprint_out(expptr exp){
  pprint(exp,fileout,0);
}

void load(expptr forms){
  
  mapc(install,forms);

  char * s = sformat("TEMP%d.c",compilecount++);
  fprintf(stdout,"compiling and loading %s\n", s);
  open_output_file(s);
  
  dolist{form,file_preamble}{print_line(form,fileout,0);}
  mapc(pprint_out,declarations());
  mapc(pprint_out,new_proc_defs());
  pprint(`{
      void _mc_doload(voidptr * symbol_value){
	internal_symbol_value = symbol_value;
	${value_extractions()}
	${value_insertions()}
	${statements()}
	return `{no value};}}
    fileout,0);
  fclose(fileout);
  
  void * header = compile_load_file(sformat("TEMP%d",compilecount));
  expptr (* _mc_doload)(voidptr *);
  doload = dlsym(header,"_MC_doproc");
  (*doload)(symbol_value);
  
  dolist{sym, env_syms}{setprop(sym,`{new},`{false});};
}

expptr declarations(){  //this generates both old and new declarations
  expptr result = NULL;
   dolist{sym, env_syms}{
    expptr decl = getprop(sym,`{declaration},NULL);
    ucase{decl;
      {?type ?f(!args){!body}}:{push(`{${type} ${f}(${args})},result);}
      {?type ?var[?dimension];}:{
	if(!newp(var)){push(`{${type} * ${var}},result);}
	else{push(decl,result);}}}}
  return result;
}

expptr new_proc_defs(){
  expptr result = NULL;
  expptr g = gensym(`{f});
  dolist{sym, env_syms}{
    expptr decl = getprop(sym,`{declaration},NULL);
    ucase{decl;
      {?type ?f(!args){!body}}:{
	if(newp(f)){push(`{${type} ${f}(${args}){${body}}},result);}}}}
  return result;
}

expptr value_extractions(){
  expptr result = NULL;
  expptr g = gensym(`{f});
  dolist{sym, env_syms}{
    if(!newp(sym)){
      ucase{getprop(sym,`{declaration},NULL);
	{?type ?var[?dimension];}:{
	  push(`{${sym} = (${type} *) symbol_value_copy[${int_exp(symbol_index(sym))}];}, result);}
	{?type ?f(!args){!body}}:{
	  push(`{
	      ${type} ${f}(${args}){
		${type} (* ${g})(${args});
		${g} = symbol_value_copy[${int_exp(symbol_index(f))}];
		${type == `{void} ? `{return} : NULL} (* ${g})(${args_variables(args)});}},
	    result);}}}}
  return result;
}

expptr value_insertions(){
  expptr result = NULL;
  dolist{sym, env_syms}{
    if(newp(sym)){
      push(`{symbol_value[${int_exp(symbol_index(sym))}] = (voidptr) ${sym};},
	   result);}}
  return result;
  }

expptr statements(forms){
  expptr result = NULL;
  dolist{form, forms}{
    ucase{form;
      {{!statement}}:{push(statement,result);}}}
  return result;
}

  
/** ========================================================================

The macro set_base_values() is used for initializing the base environment.  This
includes a base preamble and base array  to a hybernation.  It is called from main
in REPL to initialize the environment.

======================================================================== **/

umacro{insert_base_values()}{return value_insertions();}

/** ========================================================================
writing the file.
========================================================================**/

void write_new_definitions(){
  dolist{sym, env_syms}{
      if(!assignedp(sym))pprint(getprop(sym,`{declaration},NULL),fileout,0);}
}

/** ========================================================================
utilities
========================================================================**/

voidptr compile_load_file(charptr fstring){
  int flg;
  char * s1 = sformat("cc -g -fPIC -Wall -c %s.c -o %s.o",fstring,fstring);
  flg = system(s1);
  if(flg != 0)throw_error();
  char * s2 = sformat("cc -g -fPIC -shared -Wl -lm %s.o -o %s.so",fstring,fstring);
  flg = system(s2);
  if(flg != 0)throw_error();
  char * s3 = sformat("%s.so",fstring);
  voidptr header = dlopen(s3, RTLD_LAZY|RTLD_GLOBAL);
  if(header == NULL)throw_error();
  return header;
}

expptr strip_body(expptr e){
  ucase{e;
    {?type ?f(!x){!body}}:{return `{${type} ${f}(${x});};}
    {!x}:{}}
  return e;
}

int procedurep(expptr sym){
  ucase{getprop(sym,`{declaration},NULL);
    {?type ?f(!args);}:{return 1;}
    {?type ?f(!args){!body}}:{return 1;}
    {!x}:{return 0;}}
}

int arrayp(expptr sym){
  ucase{getprop(sym,`{declaration},NULL);
    {!type !A[!dim];}:{return 1;}
    {!x}:{return 0;}}
}


initfun(mcE_init1)

void mcE_init2(){
  env_syms = NULL;
  file_preamble = NULL;
  compilecount = 0;
  symbol_count = 0;
}