/* File : example.c */

#include <iostream>
#include "example.h"

void colorFree(Color *p) {
  printf("Custom destructor for Color is called!\n");
  free(p);
}
