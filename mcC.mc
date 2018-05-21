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
#include "mc.h"

void add_init_form(expptr form){
  expptr form2 = macroexpand(form);
  init_forms = append(init_forms,cons(form,NULL));
}

expptr init_form_macro(expptr e){
  ucase{e; {init_form(!form)}:{add_init_form(form); return NULL;}}
  return NULL;
}

expptr umacro_macro(expptr e){
  ucase{e;
	 {umacro{!pattern}{!body}}:{
	   expptr name = top_symbol(pattern);
	   if(name == NULL)berror("illegal pattern in umacro");
	   expptr fname = gensym(name);
	   add_init_form(`{set_macro(`{${name}},${fname});});
	   return `{expptr ${fname}(expptr e){ucase{e;{${pattern}}:{${macroexpand(body)}}} return NULL;}}}}
  return NULL;
}

expptr init_fun_macro(expptr e){
  ucase{e; {init_fun(!fname)}:{
      return `{void ${fname}(){${init_forms}}};}}
  return NULL;}

void mcC_init(){
  init_forms = NULL;
  set_macro(`{umacro},umacro_macro);
  set_macro(`{init_form}, init_form_macro);
  set_macro(`{init_fun}, init_fun_macro);
}



 

  