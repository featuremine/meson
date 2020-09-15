#include "api-gen/pythongen/include/mir-sources/callable.h"
#include "mir/pythongen/utils.h"
#include <math.h>
#include <stdio.h>


 callable_Test_double_callable_ret callable_Test_double_callable (struct callable_Test* self, CALLABLE_ARG(callable,callable_Test_double_callable_arg_callable_ret,double d)){
    printf("hello\n");


    return (callable_Test_double_callable_ret){0};
}
