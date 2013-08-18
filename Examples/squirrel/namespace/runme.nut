// file: runme.nut

// ----- Object creation -----

print("Creating some objects:\n");
local c = example.graphics.Circle(10);
print("Created circle " + c + "\n");
local s = example.graphics.Square(10);
print("Created square " + s + "\n");

// ----- Access a static member -----
print("A total of " + example["graphics.Shape.nshapes"] + " shapes were created\n"); // access static member as properties of the module
print("A total of " + c.nshapes                         + " shapes were created\n"); // access static member as properties of the instance

// Following accessor would be ideal but this doesn't work because class object doesn't respond to "_get" and "_set" metamethods
// print("A total of " + example.graphics.Shape.nshapes + " shapes were created - this doesn't work.\n");

// ----- Member data access -----
// Set the location of the object.
// Note: methods in the base class Shape are used since
// x and y are defined there.

c.x = 20;
c.y = 30;
s.x = -10;
s.y = 5;

print("\nHere is their new position:\n");
print("Circle = (" + c.x + "," + c.y + ")\n");
print("Square = (" + s.x + "," + s.y + ")\n");

// Getting non-existent value should throw error
// print("Unknown member: " + c.UNKNOWN_MEMBER);
// print("Unknown variable:" + example.UNKNOWN_VARIABLE);

// Setting non-existent value should throw error
// c.UNKNOWN_MEMBER = 1;
// example.UNKNOWN_VARIABLE = 1;

// ----- Call some methods -----
print("\nHere are some properties of the shapes:\n");
print("Circle:\n");
print("area = " + c.area() + "\n");
print("perimeter = " + c.perimeter() + "\n");
print("\n");
print("Square:\n");
print("area = " + s.area() + "\n");
print("perimeter = " + s.perimeter() + "\n");

// ----- Delete everything -----
print("\nGuess I'll clean up now\n");

// Note: this invokes the virtual destructor
// Use "delete c;" if "c" is slot.
c = null;
s = null;

// Note: nshapes might be non-zero because instances are collected by GC later.
print (example["graphics.Shape.nshapes"] + " shapes remain\n");

print("Goodbye\n");
