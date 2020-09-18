#include "api-gen/pythongen/include/mir-sources/utility.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
struct graph_Point *
graph_utility_Utility_multiply_points(struct graph_utility_Utility *self,
                                      struct graph_Point *point, double K) {
  graph_Point * ret = graph_Point_new_();
  graph_Point_t * point_data = graph_Point_data_(point);
  graph_Point_constructor(ret,point_data->x * K,point_data->y * K);
  return ret;
}

double graph_utility_Utility_divide(struct graph_utility_Utility *self,
                                    double num1, double num2) {
  return num1 / num2;
}

double graph_utility_Utility_multiply(struct graph_utility_Utility *self,
                                      double num1, double num2) {
  return num1 * num2;
}

char *graph_utility_Utility_concat_strings(struct graph_utility_Utility *self,
                                           char *s1, char *s2) {
  char *result = malloc(strlen(s1) + strlen(s2) + 1);
  strcpy(result, s1);
  strcat(result, s2);
  return result;
}

int32_t graph_utility_Utility_add1(struct graph_utility_Utility *self, int32_t a,
                                  int32_t b) {
  return a + b;
}

struct graph_Point *
graph_utility_Utility_pointSum(struct graph_utility_Utility *self,
                               struct graph_Point *aptr, struct graph_Point *bptr) {
  graph_Point * ret = graph_Point_new_();
  graph_Point_t * a = graph_Point_data_(aptr);
  graph_Point_t * b = graph_Point_data_(bptr);
  graph_Point_constructor(ret,a->x + b->x, a->y + b->y);                         
  return ret;
}

int32_t
graph_utility_Utility_execute_callable(struct graph_utility_Utility *self,
                                   struct graph_Point *point,
                                   r_int32_a_double_al_graph_Point callable) {
  printf("ref count %ld \n",callable.closure? mir_get_ref_cnt(callable.closure):0);
  int32_t ret = callable.func(1.0, point, callable.closure);
  printf("ref count %ld \n", callable.closure? mir_get_ref_cnt(callable.closure):0);
  return ret;
}

int32_t c_closure(double K, struct graph_Point *point) {
  return 3;
};
typedef int32_t (*c_callb)(double K, struct graph_Point *);
int32_t c_callback(double K, struct graph_Point *point, void *c) {
  return c_closure(K, point);
};


r_int32_a_double_al_graph_Point 
graph_utility_Utility_get_callable(struct graph_utility_Utility *self,
                                   struct graph_Point *point, int16_t int16) {
  printf("hello from graph_utility_Utility_get_callable\n");
  r_int32_a_double_al_graph_Point callback;
  callback.closure = NULL;
  callback.func = c_callback;
  return callback;
}

typedef int32_t (*c_a_callb)(double K);

int32_t c_a_closure(double K) {
  printf("c callback with params %f\n", K);
  return K;
};

int32_t c_a_callback(double K, void *c) { return c_a_closure(K); };

r_int32_a_double
graph_utility_Utility_get_another_callable(struct graph_utility_Utility *self) {
  printf("hello from c\n");
  r_int32_a_double callback;
  callback.closure = NULL;
  callback.func = c_a_callback;
  return callback;
}

typedef graph_Point *(*c_p_callb)(double K);

graph_Point *c_p_closure(double K) {
  printf("c callback with params %f\n", K);
  graph_Point *p = graph_Point_new_();
  graph_Point_constructor(p,3,4);

  return p;
};

graph_Point *c_p_callback(double K, void *c) { return c_p_closure(K); };

rl_graph_Point_a_double graph_utility_Utility_get_callable_with_ref(
    struct graph_utility_Utility *self) {
  printf("hello from c\n");
    rl_graph_Point_a_double callback;
  callback.closure = NULL;
  callback.func = c_p_callback;
  return callback;
}

int32_t graph_utility_Utility_add_callable2(
    struct graph_utility_Utility *self,
    r_none_a_double_al_graph_Point callableWithoutRet) {
  return 1;
}

graph_Point *
graph_utility_Utility_get_point_ref(struct graph_utility_Utility *self) {
  graph_Point *p = graph_Point_new_();
  graph_Point_constructor(p,3,4);
  return p;
};

int8_t graph_utility_foo = 3;

int8_t graph_utility_Checker_check_int8(struct graph_utility_Checker *self,
                                        int8_t a) {
  return a;
}

int16_t graph_utility_Checker_check_int16(struct graph_utility_Checker *self,
                                          int16_t a) {
  return a;
}
int32_t graph_utility_Checker_check_int32(struct graph_utility_Checker *self,
                                          int32_t a) {
  return a;
}
int64_t graph_utility_Checker_check_int64(struct graph_utility_Checker *self,
                                          int64_t a) {
  return a;
}
uint8_t graph_utility_Checker_check_uint8(struct graph_utility_Checker *self,
                                          uint8_t a) {
  return a;
}
uint16_t graph_utility_Checker_check_uint16(struct graph_utility_Checker *self,
                                            uint16_t a) {
  return a;
}
uint32_t graph_utility_Checker_check_uint32(struct graph_utility_Checker *self,
                                            uint32_t a) {
  return a;
}
uint64_t graph_utility_Checker_check_uint64(struct graph_utility_Checker *self,
                                            uint64_t a) {
  return a;
}
double graph_utility_Checker_check_double(struct graph_utility_Checker *self,
                                          double a) {
  return a;
}
bool graph_utility_Checker_check_bool(struct graph_utility_Checker *self,
                                      bool a) {
  return a;
}
char graph_utility_Checker_check_char(struct graph_utility_Checker *self,
                                      char a) {
  return a;
}
char *graph_utility_Checker_check_string(struct graph_utility_Checker *self,
                                         char *a) {

  char *result = malloc(strlen(a)+1);
  strcpy(result, a);
  return result;
}

// del
void graph_utility_Utility_destructor(graph_utility_Utility *self) {
    printf("Utility destructor\n");
}
// new
void graph_utility_Utility_constructor(graph_utility_Utility *self) {
  graph_utility_Utility_t* data = graph_utility_Utility_data_(self);
  data->calwithoutret.closure=NULL;
}
// del
void graph_utility_EmptyClass_destructor(graph_utility_EmptyClass *self) {}
// new
void graph_utility_EmptyClass_constructor(graph_utility_EmptyClass *self) {}
// del
void graph_utility_Point_destructor(graph_utility_Point *self) {}
// new
void graph_utility_Point_constructor(graph_utility_Point *self) {}
// del
void graph_utility_Checker_destructor(graph_utility_Checker *self) {}
// new
void graph_utility_Checker_constructor(graph_utility_Checker *self) {}

void graph_utility_pointerHolder_constructor(
    graph_utility_pointerHolder *self) {
  graph_utility_pointerHolder_t * data = graph_utility_pointerHolder_data_(self);    
  data->array = malloc(sizeof(int));
  int val = 11;
  memcpy(data->array, &val, sizeof(int));
}

void graph_utility_pointerHolder_destructor(graph_utility_pointerHolder *self) {
  graph_utility_pointerHolder_t * data = graph_utility_pointerHolder_data_(self);  
  free(data->array);
}
int32_t
graph_utility_pointerHolder_get_int(struct graph_utility_pointerHolder *self) {
  graph_utility_pointerHolder_t * data = graph_utility_pointerHolder_data_(self);  
  int32_t *val = (int32_t *)data->array;
  return *val;
}

void graph_utility_NoneTester_destructor(graph_utility_NoneTester *self) {}

void graph_utility_NoneTester_constructor(graph_utility_NoneTester *self) {}

struct graph_Point *
graph_utility_NoneTester_get_none(struct graph_utility_NoneTester *self) {
  return NULL;
}



void graph_utility_EnumClass_destructor(graph_utility_EnumClass *self){

}

void graph_utility_EnumClass_constructor(graph_utility_EnumClass* self){

}

graph_utility_TestEnum graph_utility_EnumClass_set_enum (struct graph_utility_EnumClass* self, graph_utility_TestEnum testEnum){
  graph_utility_EnumClass_t * data = graph_utility_EnumClass_data_(self);  
  data->testEnum = testEnum;
  return testEnum;
}
struct graph_utility_EnumClass* graph_utility_EnumClass_getHimSelf (struct graph_utility_EnumClass* self, struct graph_utility_EnumClass *data){
  
  graph_utility_EnumClass_get_descr()->inc_ref_(data);
  return data;
}


void graph_utility_Integer_destructor(graph_utility_Integer *self){}

void graph_utility_Integer_constructor(graph_utility_Integer* self, int64_t val){
  graph_utility_Integer_t * data = graph_utility_Integer_data_(self);  
  data->value = val;
}

bool graph_utility_Integer_operator_less (struct graph_utility_Integer* self, struct graph_utility_Integer *pVal){
  graph_utility_Integer_t * data = graph_utility_Integer_data_(self);  
    graph_utility_Integer_t * val = graph_utility_Integer_data_(pVal);  
  return   data->value < val->value;
}

bool graph_utility_Integer_operator_equal (struct graph_utility_Integer* self, struct graph_utility_Integer *pVal){
  graph_utility_Integer_t * data = graph_utility_Integer_data_(self);  
  graph_utility_Integer_t * val = graph_utility_Integer_data_(pVal);  
  return   data->value == val->value;
}

void graph_utility_PythonTestClass_destructor(graph_utility_PythonTestClass *self){
   graph_utility_PythonTestClass_t * data = graph_utility_PythonTestClass_data_(self);  
   Py_DECREF(data->test);
}

void graph_utility_PythonTestClass_constructor(graph_utility_PythonTestClass* self, PythonTest* val){
  graph_utility_PythonTestClass_t * data = graph_utility_PythonTestClass_data_(self);  
  data->test = val;
  Py_INCREF(data->test);
}

void test_mthd(graph_utility_PythonTestClass* self, PythonTest* test){
  Py_INCREF(test);
  graph_utility_PythonTestClass_set_test_(self, test);
}

PythonTest* graph_utility_PythonTestClass_test_mthd (struct graph_utility_PythonTestClass* self, PythonTest* test){
  Py_INCREF(test);
  return test;
}

graph_utility_PythonAliasCallable graph_utility_PythonTestClass_execute (struct graph_utility_PythonTestClass* self, PythonTest* test,graph_utility_PythonAliasCallable callable){
  callable.func(test, callable.closure);
  mir_inc_ref(callable.closure);
  return callable;
}

double graph_utility_Decimal_to_double (struct graph_utility_Decimal* self){
  return ((double)self->value)/1000000000.0;
}

struct graph_utility_Decimal graph_utility_Decimal_operator_add (struct graph_utility_Decimal* self, struct graph_utility_Decimal val){
  graph_utility_Decimal ret = {self->value+val.value};
  return ret;
}

bool graph_utility_Decimal_operator_less (struct graph_utility_Decimal* self, struct graph_utility_Decimal val){
  return self->value < val.value;
}

bool graph_utility_Decimal_operator_equal (struct graph_utility_Decimal* self, struct graph_utility_Decimal val){
  return self->value == val.value;
}


void graph_utility_TestSet_destructor(graph_utility_TestSet *pSelf){
  graph_utility_TestSet_t* self = graph_utility_TestSet_data_(pSelf);
  mir_dec_ref(self->py_type_);
  mir_dec_ref(self->class_);
  mir_dec_ref_callable(&self->callable_);
}
void graph_utility_TestSet_constructor(graph_utility_TestSet* pSelf, PythonTest* py_type_, graph_utility_Decimal struct_, PythonTest* class_, r_none callable_, int32_t int_type_, graph_utility_TestEnum enum_){
  graph_utility_TestSet_t* self = graph_utility_TestSet_data_(pSelf);
  mir_inc_ref(py_type_);
  self->py_type_ = py_type_;
  self->struct_ = struct_;
  mir_inc_ref(class_);
  self->class_=class_;
  mir_inc_ref_callable(&callable_);
  self->callable_=callable_;
  self->int_type_ = int_type_;
  self->enum_ = enum_;
}