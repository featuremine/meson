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
#include <string.h>
#include "mir/pythongen/common_c.h"
#include "mir/pythongen/utils.h"


typedef struct {
  void *func;
  void *closure;
} mir_callable;


void mir_inc_ref(void *obj) {
    Py_XINCREF(obj);
}
void mir_dec_ref(void *obj) {
    Py_XDECREF(obj);
}
void mir_inc_ref_callable(void *obj) {
    if (obj)Py_XINCREF(((mir_callable*)obj)->closure);
}
void mir_dec_ref_callable(void *obj) {
    if (obj)Py_XDECREF(((mir_callable*)obj)->closure);
}

void mir_inc_ref_struct(void *obj) {}

void mir_dec_ref_struct(void *obj) {}
long mir_get_ref_cnt(void *obj) {
    return Py_REFCNT(obj);
}

PyObject *get_mir_error_type(mir_exception err) {
  switch (err) {
  case mir_exception_VALUE_ERROR:
    return PyExc_ValueError;
    break;
  case mir_exception_RuntimeError:
    return PyExc_RuntimeError;
    break;
  default:
    return PyExc_Exception;
  }
}

void mir_error_set(mir_exception err, const char *message) {
  PyErr_SetString(get_mir_error_type(err), message);
}
bool mir_error_occured() {
  if (PyErr_Occurred()) {
    return true;
  } else {
    return false;
  }
}

char *mir_str_clone(const char *s) {
    size_t len = strlen(s) + 1;
    size_t *n = malloc(len);
    memcpy(n, s, len);
    return (char *)n;
}
