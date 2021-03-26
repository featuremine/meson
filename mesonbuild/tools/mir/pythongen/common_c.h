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

#ifndef _C_COMMON_H_
#define _C_COMMON_H_
#ifdef __cplusplus
extern "C"
{
#endif
#include <stdlib.h>
#define CALLABLE(ret, ...)                                     \
    struct                                                     \
    {                                                          \
        ret (*func)(void *closure, ##__VA_ARGS__);             \
        void *closure;                                         \
    }

#define CALLABLE_ARG(name, ret, ...) \
    ret (*name##_func)(void * c, ##__VA_ARGS__), void * name##_closure

#define CALLABLE_STRUCT_ARG(name, ret, ...) \
    ret (*name##_func)(void * c, ##__VA_ARGS__); void * name##_closure

#ifdef _MSC_VER
#define MIR_EXPORT __declspec(dllexport)
#else
#define MIR_EXPORT __attribute__((visibility("default")))
#endif

#define AUTO_DECLARE(X, Y) typeof(Y) X = Y
    void mir_inc_ref(void *obj);
    void mir_dec_ref(void *obj);
    void mir_inc_ref_callable(void *obj);
    void mir_dec_ref_callable(void *obj);
    typedef struct
    {
        void *(*copy_new_)(void *);
        size_t (*size_)();
        void (*copy_inplace_)(void *dest, void *obj);
        void *(*new_)();
        void (*inc_ref_)(void *);
        void (*dec_ref_)(void *);
    } mir_type_descr;
#ifdef __cplusplus
}
#endif
#endif //_C_COMMON_H_
