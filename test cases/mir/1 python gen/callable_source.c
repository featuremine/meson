#include "api-gen/pythongen/include/mir-sources/callable.h"
#include "mir/pythongen/utils.h"
#include <math.h>
#include <stdio.h>


CALLABLE(void) callable_Test_double_callable (struct callable_Test* self, CALLABLE_ARG(callable,int32_t,double d)){
    printf("hello\n");

    void * a = NULL;
    void * b = NULL;
    get_data(NULL,a,b);

    return (CALLABLE(void)){0};
}
