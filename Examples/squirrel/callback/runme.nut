local a = 37;
local b = 42;

print("Trying some C functions");
print("\n    a        =" + a);
print("\n    b        =" + b);
print("\n    add(a,b) =" + example.add(a,b));
print("\n    sub(a,b) =" + example.sub(a,b));
print("\n    mul(a,b) =" + example.mul(a,b));

print("\nNow let us write our callback\n")

// Add 101 to resulting value
function add101(r) {
    return 101 + r;
}

// Call native function add(a,b) and then callback foo with resulting value
print("add(" + a + "," + b + ")+101=" + example.callback(a, b, example.ADD, add101) + "\n");
print("sub(" + a + "," + b + ")+101=" + example.callback(a, b, example.SUB, add101) + "\n");
print("mul(" + a + "," + b + ")+101=" + example.callback(a, b, example.MUL, add101) + "\n");
print("\n");