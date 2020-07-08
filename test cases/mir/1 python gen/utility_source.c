#include "api-gen/pythongen/include/mir-sources/utility.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
struct graph_Point
graph_utility_Utility_multiply_points(struct graph_utility_Utility *self,
                                      struct graph_Point *point, double K) {
  return (struct graph_Point){NULL, point->x * K, point->y * K};
}

double graph_utility_Utility_divide1(struct graph_utility_Utility *self,
                                    double num1, double num2) {
  return num1 / num2;
}

double graph_utility_Utility_multiply1(struct graph_utility_Utility *self,
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

struct graph_Point
graph_utility_Utility_pointSum(struct graph_utility_Utility *self,
                               struct graph_Point *a, struct graph_Point *b) {
  return (struct graph_Point){NULL, a->x + b->x, a->y + b->y};
}

int32_t
graph_utility_Utility_add_callable(struct graph_utility_Utility *self,
                                   struct graph_Point *point,
                                   r_int32_a_double_al_graph_Point *callable) {
  printf("hello from c\n");
  int32_t ret = callable->func(1.0, point, callable->closure);
  callable->free(callable->closure);
  // free(callable);
  return ret;
}

int32_t c_closure(double K, struct graph_Point *point) {
  printf("c callback with params %f %f %f\n", K, point->x, point->y);
  return 3;
};
typedef int32_t (*c_callb)(double K, struct graph_Point *);
int32_t c_callback(double K, struct graph_Point *point, void *c) {
  return ((c_callb)c)(K, point);
};

void c_free(void *closure) {}

r_int32_a_double_al_graph_Point
graph_utility_Utility_get_callable(struct graph_utility_Utility *self,
                                   struct graph_Point *point, int16_t int16) {
  printf("hello from graph_utility_Utility_get_callable\n");
  r_int32_a_double_al_graph_Point callback;
  callback.closure = c_closure;
  callback.func = c_callback;
  callback.free = c_free;
  return callback;
}

typedef int32_t (*c_a_callb)(double K);

int32_t c_a_closure(double K) {
  printf("c callback with params %f\n", K);
  return K;
};

int32_t c_a_callback(double K, void *c) { return ((c_a_callb)c)(K); };

r_int32_a_double
graph_utility_Utility_get_another_callable(struct graph_utility_Utility *self) {
  printf("hello from c\n");
  r_int32_a_double callback;
  callback.closure = c_a_closure;
  callback.func = c_a_callback;
  callback.free = c_free;
  return callback;
}

typedef graph_Point *(*c_p_callb)(double K);

graph_Point *c_p_closure(double K) {
  printf("c callback with params %f\n", K);

  graph_Point *p = malloc(sizeof(graph_Point));
  p->x = 3;
  p->y = 4;
  p->_owner_ = NULL;
  return p;
};

graph_Point *c_p_callback(double K, void *c) { return ((c_p_callb)c)(K); };

rl_graph_Point_a_double *graph_utility_Utility_get_callable_with_ref(
    struct graph_utility_Utility *self) {
  printf("hello from c\n");
  rl_graph_Point_a_double *callback = malloc(sizeof(rl_graph_Point_a_double));
  callback->closure = c_p_closure;
  callback->func = c_p_callback;
  callback->free = c_free;
  return callback;
}

int32_t graph_utility_Utility_add_callable2(
    struct graph_utility_Utility *self,
    r_none_a_double_al_graph_Point *callableWithoutRet) {
  return 1;
}

graph_Point *
graph_utility_Utility_get_point_ref(struct graph_utility_Utility *self) {
  graph_Point *point = malloc(sizeof(graph_Point));
  point->x = 3;
  point->y = 4;
  point->_owner_ = NULL;
  return point;
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
  return a;
}

// del
void graph_utility_Utility_destructor(graph_utility_Utility *self) {}
// new
void graph_utility_Utility_constructor(graph_utility_Utility *self) {}
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

  self->array = malloc(sizeof(int));
  int val = 11;
  memcpy(self->array, &val, sizeof(int));
}

void graph_utility_pointerHolder_destructor(graph_utility_pointerHolder *self) {
  free(self->array);
}
int32_t
graph_utility_pointerHolder_get_int(struct graph_utility_pointerHolder *self) {
  int32_t *val = (int32_t *)self->array;
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
  self->testEnum = testEnum;
  return testEnum;
}
struct graph_utility_EnumClass graph_utility_EnumClass_getHimSelf (struct graph_utility_EnumClass* self, struct graph_utility_EnumClass data){
  return data;
}