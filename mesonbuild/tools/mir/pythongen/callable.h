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

#ifndef _MIR_CALLABLE_H_
#define _MIR_CALLABLE_H_
#ifdef __cplusplus
extern "C"
{
#endif
#include <stdlib.h>
       typedef struct
       {
              void *func;
              void *closure;
       } mir_callable;
#ifdef __cplusplus
}
#endif
#endif //_MIR_CALLABLE_H_
