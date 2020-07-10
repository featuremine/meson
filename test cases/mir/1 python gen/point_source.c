#include "api-gen/pythongen/include/mir-sources/point.h"
#include <math.h>
#include <stdio.h>
double graph_Point_dist(struct graph_Point *self, struct graph_Point *point) {
  return hypot(self->x - point->x, self->y - point->y);
}

double graph_Point_norm(struct graph_Point *self) {
  return hypot(self->x, self->y);
}

// del
void graph_Point_destructor(graph_Point *self) {}
// new
void graph_Point_constructor(graph_Point *self, double x, double y) {
  self->x = x;
  self->y = y;
}

graph_Point * get_mir_const_graph_ConstPoint(){
  graph_Point * pt =  graph_Point_get_descr()->new_();
  graph_Point_constructor(pt,1,2);
  return pt;
}

struct graph_Point* graph_Point_numerical_add (struct graph_Point* self, struct graph_Point *point){
  graph_Point*  pt = graph_Point_get_descr()->new_();
  graph_Point_constructor(pt,self->x+point->x, self->y+point->y);
  return pt;
}
struct graph_Point* graph_Point_numerical_divide (struct graph_Point* self, int64_t val){
  if (val==0) return NULL;
  graph_Point*  pt = graph_Point_get_descr()->new_();
  graph_Point_constructor(pt,self->x/val, self->y/val);
  return pt;
}