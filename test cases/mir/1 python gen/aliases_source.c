#include "api-gen/pythongen/include/mir-sources/aliases.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

double graph_aliases_AliasClass_dist(struct graph_aliases_AliasClass *self,
                                     graph_aliases_Vector2d point) {
  return hypot(self->obj.x - point.x, self->obj.y - point.y);
}

typedef graph_aliases_Vector2d *(*c_pr_callb)(graph_aliases_Vector2d *point);

graph_Point *c_pr_closure(graph_aliases_Vector2d *point) { return point; };

graph_aliases_Vector2d *c_pr_callback(graph_aliases_Vector2d *point, void *c) {
  return ((c_pr_callb)c)(point);
}

graph_aliases_Vector2d *graph_aliases_AliasClass_setCallable(
    struct graph_aliases_AliasClass *self,
    rl_graph_aliases_Vector2d_al_graph_aliases_Vector2d *callable) {
  graph_aliases_Vector2d *point =  graph_Point_get_descr()->new_();
  graph_aliases_Vector2d *ret = callable->func(point, callable->closure);
  return ret;
};

graph_aliases_VectorCallable *graph_aliases_AliasClass_setAliasCallable(
    struct graph_aliases_AliasClass *self,
    graph_aliases_VectorCallable *aCallable) {
  self->aliasCallable = aCallable;
  rl_graph_aliases_VectorCallable_al_graph_aliases_VectorCallable_get_descr()->inc_ref_(aCallable);
  return aCallable;
};

// del
void graph_aliases_ClassWithRef_destructor(graph_aliases_ClassWithRef *self) {}
// new
void graph_aliases_ClassWithRef_constructor(graph_aliases_ClassWithRef *self,
                                            graph_Point *ref, graph_Point obj) {
  self->ref = ref;
  graph_Point_get_descr()->inc_ref_(ref);
  self->obj = obj;
  graph_Point_get_descr()->inc_ref_(&obj);
}
// del
void graph_aliases_AliasClass_destructor(graph_aliases_AliasClass *self) {}
// new
void graph_aliases_AliasClass_constructor(graph_aliases_AliasClass *self,
                                          graph_aliases_Vector2d obj) {
  self->obj = obj;
  graph_Point_get_descr()->inc_ref_(&obj);
}

graph_aliases_Vector2d * get_mir_const_graph_aliases_ConstVector(){
  graph_Point * pt =  graph_Point_get_descr()->new_();
  graph_Point_constructor(pt,1,2);
  return pt;
}