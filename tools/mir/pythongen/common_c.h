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
    void mir_inc_ref(void *obj);
    void mir_dec_ref(void *obj);
    typedef struct
    {
        void *(*copy_new_)(void *);
        size_t (*size_)();
        void (*copy_implace_)(void *dest, void *obj);
        void (*del_)(void *);
        void *(*new_)();
        void (*inc_ref_)(void *);
        void (*dec_ref_)(void *);
    } mir_type_descr;
#ifdef __cplusplus
}
#endif
#endif //_C_COMMON_H_
