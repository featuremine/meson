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
 * @file /tools/mir/pythongen/utils.h
 * @author Vitaut Tryputsin
 * @date 02 Jun 2020
 */

#ifndef H_MIR_PYTHONGEN_UTILS_H
#define H_MIR_PYTHONGEN_UTILS_H
#ifdef __cplusplus
extern "C"
{
#endif
#include <Python.h>
       void free_closure(void *closure);
       typedef struct
       {
              void *_owner_;
              void *func;
              void *closure;
              void (*free)(void *);
       } mir_callable_struct;
       void mir_inc_ref_struct(void *obj);
       void mir_dec_ref_struct(void *obj);
       void mir_inc_ref_python(void *obj);
       void mir_dec_ref_python(void *obj);

       long mir_get_ref_cnt(void *obj);

#ifdef __cplusplus
}
#endif
#endif // H_MIR_PYTHONGEN_UTILS_H