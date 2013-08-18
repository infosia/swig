// First create some objects using the pointer library.
print("Testing the pointer library");
local a = example.new_intp();
local b = example.new_intp();
local c = example.new_intp();

example.intp_assign(a, 37);
example.intp_assign(b, 42);

print("\na = " + example.intp_value(a));
print("\nb = " + example.intp_value(b));
print("\nc = " + example.intp_value(c));

// Call the add() function with some pointers
example.add(a,b,c);

// Now get the result
print("\na + b = " + example.intp_value(c) + "\n");

local r = example.divide(42, 37, c);
print("\n42 / 37 = " + r + " remainder=" + example.intp_value(c) + "\n");

// Clean up the pointers
// since this is C-style pointers you must clean it up
example.delete_intp(a);
example.delete_intp(b);
example.delete_intp(c);
