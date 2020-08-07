#include "api-gen/pythongen/include/mir-sources/point.h"
#include <math.h>
#include <stdio.h>
double graph_Point_dist(struct graph_Point *self, struct graph_Point *point) {
  graph_Point_t *data = graph_Point_data_(self);
  graph_Point_t *point_data = graph_Point_data_(point);
  return hypot(data->x - point_data->x, data->y - point_data->y);
}

double graph_Point_norm(struct graph_Point *self) {
  graph_Point_t *data = graph_Point_data_(self);
  return hypot(data->x, data->y);
}

// del
void graph_Point_destructor(graph_Point *self) {}
// new
void graph_Point_constructor(graph_Point *self, double x, double y) {
  graph_Point_t *data = graph_Point_data_(self);
  data->x = x;
  data->y = y;
}

graph_Point * get_mir_const_graph_ConstPoint(){
  graph_Point * pt =  graph_Point_get_descr()->new_();
  graph_Point_constructor(pt,1,2);
  return pt;
}

void graph_Point_operator_inplace_add (struct graph_Point* self, struct graph_Point *point){
  graph_Point_t *data = graph_Point_data_(self);
  data->x = data->x+data->x;
  data->y = data->y+data->y;
}

void graph_Point_operator_inplace_divide (struct graph_Point* self, int64_t val){
  graph_Point_t *data = graph_Point_data_(self);
  if (val==0){
    data->x = 0;
    data->y = 0;
    return;
  }
  data->x = data->x/val;
  data->y = data->y/val;
}
