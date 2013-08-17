// file: runme.nut

// ----- Object creation -----

// Print out the value of some enums
print("*** color ***");
print("\n    RED    =" + example.RED);
print("\n    BLUE   =" + example.BLUE);
print("\n    GREEN  =" + example.GREEN);

print("\n*** Foo::speed ***");
print("\n    Foo.IMPULSE   =" + example.Foo.IMPULSE);
print("\n    Foo.WARP      =" + example.Foo.WARP);
print("\n    Foo.LUDICROUS =" + example.Foo.LUDICROUS);

print("\nTesting use of enums with functions\n");

example.enum_test(example.RED,   example.Foo.IMPULSE);
example.enum_test(example.BLUE,  example.Foo.WARP);
example.enum_test(example.GREEN, example.Foo.LUDICROUS);

print("\nTesting use of enum with class method\n");
local f = example.Foo();

f.enum_test(example.Foo.IMPULSE);
f.enum_test(example.Foo.WARP);
f.enum_test(example.Foo.LUDICROUS);
