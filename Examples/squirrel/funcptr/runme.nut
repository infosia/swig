local a = 37;
local b = 42;

// Now call our C function with a bunch of callbacks

print("Trying some C functions");
print("\n    a        =" + a);
print("\n    b        =" + b);
print("\n    add(a,b) =" + example.add(a,b));
print("\n    sub(a,b) =" + example.sub(a,b));
print("\n    mul(a,b) =" + example.mul(a,b));

print("\nCalling them using function pointer");

print("\n    add(a,b) =" + example.callback(a,b,example.ADD));
print("\n    sub(a,b) =" + example.callback(a,b,example.SUB));
print("\n    mul(a,b) =" + example.callback(a,b,example.MUL));

print("\n");
