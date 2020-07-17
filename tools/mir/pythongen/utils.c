/******************************************************************************

       COPYRIGHT (c) 2017 by FeatureMine LLC.
       This software has been provided pursuant to a License Agreement
       containing restrictions on its use.  This software contains
       valuable trade secrets and proprietary information of
       FeatureMine LLC and is protected by law.  It may not be
       copied or distributed in any form or medium, disclosed to third
       parties, reverse engineered or used in any manner not provided
       for in said License Agreement except with the prior written
       authorization from FeatureMine LLC.

*****************************************************************************/

/**
 * @file /tools/mir/pythongen/utils.c
 * @author Vitaut Tryputsin
 * @date 02 Jun 2020
 */

#include "mir/pythongen/common_c.h"
#include "mir/pythongen/utils.h"
void free_closure(void *closure) { 
  Py_DECREF(closure); 
  }

typedef struct{
  void * _owner_; 
}mir_object;

void mir_inc_ref(void *obj) {
  if ((mir_object*)obj != NULL && ((mir_object*)obj)->_owner_  != NULL && ((mir_object*)obj)->_owner_  != Py_None)
    Py_INCREF(((mir_object*)obj)->_owner_);
}
void mir_dec_ref(void *obj) {
  if ((mir_object*)obj != NULL && ((mir_object*)obj)->_owner_  != NULL && ((mir_object*)obj)->_owner_  != Py_None){
    Py_DECREF(((mir_object*)obj)->_owner_);
  }
}

void mir_inc_ref_struct(void *obj) {}

void mir_dec_ref_struct(void *obj) {}
long mir_get_ref_cnt(void *obj){
   if ((mir_object*)obj != NULL && ((mir_object*)obj)->_owner_  != NULL && ((mir_object*)obj)->_owner_  != Py_None)
  return Py_REFCNT(((mir_object*)obj)->_owner_);
  else return 0;
}

void mir_inc_ref_python(void *obj){
  Py_DECREF(obj);
}
void mir_dec_ref_python(void *obj){
  Py_INCREF(obj);
}

// void mir_callable_del_(mir_callable_struct *obj) {
//   obj->free(obj->closure);
//   free(obj);
// }

// mir_callable_struct *mir_callable_new_() {
//   mir_callable_struct *_obj = malloc(sizeof(mir_callable_struct));
//   return _obj;
// }

// void mir_callable_copy_inplace_(mir_callable_struct *dest,
//                                 mir_callable_struct *src) {

//   memcpy(dest, src, sizeof(mir_callable_struct));
//   dest->_owner_ = NULL;
// }

// mir_callable_struct *mir_callable_copy_new_(mir_callable_struct *obj) {
//   mir_callable_struct *copy = malloc(sizeof(mir_callable_struct));
//   mir_callable_copy_inplace_(copy, obj);
//   return copy;
// }

// size_t mir_callable_size_() { return sizeof(mir_callable_struct); }