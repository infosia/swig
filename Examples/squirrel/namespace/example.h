/* File : example.h */
#include <stdio.h>

namespace graphics {

class Shape {
public:
  Shape() {
    nshapes++;
  }
  virtual ~Shape() {
    nshapes--;
  };
  double  x, y;   
  void    move(double dx, double dy);
  virtual double area(void) = 0;
  virtual double perimeter(void) = 0;
  static  int nshapes;
  enum speed { IMPULSE=10, WARP=20, LUDICROUS=30 };
};

class Circle : public Shape {
private:
  double radius;
public:
  Circle(double r) : radius(r) { };
  virtual ~Circle() {
    printf("~Circle destructor is called\n");
  };
  virtual double area(void);
  virtual double perimeter(void);
};

class Square : public Shape {
private:
  double width;
public:
  Square(double w) : width(w) { };
  virtual ~Square() {
    printf("~Square destructor is called\n");
  };
  virtual double area(void);
  virtual double perimeter(void);
};

} // end of namespace


  
