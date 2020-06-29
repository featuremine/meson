#include "api-gen/pythongen/include/mir-sources/point.h"
#include <math.h>
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
