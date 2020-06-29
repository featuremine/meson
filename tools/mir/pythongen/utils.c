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

#include "mir/pythongen/utils.h"
#include "mir/pythongen/common_c.h"
void free_closure(void *closure) { Py_DECREF(closure); }

void mir_inc_ref(void *obj) {
  if (obj != NULL && obj != Py_None)
    Py_INCREF(obj);
}
void mir_dec_ref(void *obj) {
  if (obj != NULL && obj != Py_None)
    Py_DECREF(obj);
}
