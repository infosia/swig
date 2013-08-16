/* file: runme.nut */

/* Call our gcd() function */

local x = 42;
local y = 105;
local g = example.gcd(x,y);
print("GCD of x and y is=" + g + "\n");

/* Manipulate the Foo global variable */

/* Output its current value */
print("Global variable Foo=" + example.Foo + "\n");

/* Change its value */
example.Foo = 3.1415926;

/* See if the change took effect */
print("Variable Foo changed to=" + example.Foo + "\n");
