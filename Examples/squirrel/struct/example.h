/* File: example.h */

typedef struct Foo {
  int index;
} Foo;

typedef struct Color {
  float  red;
  float  green;
  float  blue;
  Foo   *foo;
} Color;
