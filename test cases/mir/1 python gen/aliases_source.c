#include "api-gen/pythongen/include/mir-sources/aliases.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

double graph_aliases_AliasClass_dist(struct graph_aliases_AliasClass *pSelf,
                                     graph_aliases_Vector2d *pPoint) {
  graph_aliases_AliasClass_t * self = graph_aliases_AliasClass_data_(pSelf);
  graph_Point_t * obj = graph_Point_data_(self->obj);
  graph_Point_t * point = graph_Point_data_(pPoint);
  return hypot(obj->x - point->x, obj->y - point->y);
}

typedef graph_aliases_Vector2d *(*c_pr_callb)(graph_aliases_Vector2d *point);

graph_Point *c_pr_closure(graph_aliases_Vector2d *point) { return point; };

graph_aliases_Vector2d *c_pr_callback(graph_aliases_Vector2d *point, void *c) {
  return ((c_pr_callb)c)(point);
}

graph_aliases_Vector2d* graph_aliases_AliasClass_setCallable (struct graph_aliases_AliasClass* self, CALLABLE_ARG(callable,graph_aliases_Vector2d*,graph_aliases_Vector2d *point)) {
  graph_aliases_Vector2d *point =  graph_Point_new_();
  graph_aliases_Vector2d *ret = callable_func( callable_closure,point);
  return ret;
};

 graph_aliases_AliasClass_setAliasCallable_ret graph_aliases_AliasClass_setAliasCallable (struct graph_aliases_AliasClass* pSelf, CALLABLE_ARG(aCallable,graph_aliases_Vector2d*,graph_aliases_Vector2d *point)) {
  graph_aliases_AliasClass_t * self = graph_aliases_AliasClass_data_(pSelf);
  self->aliasCallable_func = aCallable_func;
  self->aliasCallable_closure = aCallable_closure;
  mir_inc_ref(aCallable_closure);
  return (graph_aliases_AliasClass_setAliasCallable_ret){aCallable_func,aCallable_closure};
};

// del
void graph_aliases_ClassWithRef_destructor(graph_aliases_ClassWithRef *self) {}
// new
void graph_aliases_ClassWithRef_constructor(graph_aliases_ClassWithRef *pSelf,
                                            graph_Point *ref, graph_Point * obj) {
  graph_aliases_ClassWithRef_t * self = graph_aliases_ClassWithRef_data_(pSelf);                                           
  self->ref = ref;
  graph_Point_get_descr()->inc_ref_(ref);
  self->obj = obj;
  graph_Point_get_descr()->inc_ref_(obj);
}
// del
void graph_aliases_AliasClass_destructor(graph_aliases_AliasClass *pSelf) {
 graph_aliases_AliasClass_t * self = graph_aliases_AliasClass_data_(pSelf);    
 graph_Point_get_descr()->inc_ref_(self->obj);
}
// new
void graph_aliases_AliasClass_constructor(graph_aliases_AliasClass *pSelf,
                                          graph_aliases_Vector2d *obj) {
  graph_aliases_AliasClass_t * self = graph_aliases_AliasClass_data_(pSelf);        
  self->obj = obj;
  graph_Point_get_descr()->inc_ref_(obj);
}

graph_aliases_Vector2d * get_mir_const_graph_aliases_ConstVector(){
  graph_Point * pt =  graph_Point_get_descr()->new_();
  graph_Point_constructor(pt,1,2);
  return pt;
}
