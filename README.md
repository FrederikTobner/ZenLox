# ZenLox

[![Build ZenLox](https://github.com/FrederikTobner/ZenLox/actions/workflows/build.yaml/badge.svg)](https://github.com/FrederikTobner/ZenLox/actions/workflows/build.yaml)
[![Tests](https://github.com/FrederikTobner/ZenLox/actions/workflows/test.yaml/badge.svg)](https://github.com/FrederikTobner/ZenLox/actions/workflows/test.yaml)
[![Zig Version](https://img.shields.io/badge/zig-0.10.1-orange)](https://ziglang.org/)

[Lox](https://craftinginterpreters.com/the-lox-language.html), the beloved educational programming language, crafted in Zig, infused with an added touch of serenity and Zen.

Cellox is a dynamically typed, object oriented, high-level scripting language.

Zenlox is currently in an experimental state. Some of the language features that are currently included, might change or not be included in the upcoming versions of the interpreter.

## Values

In Zenlox values are grouped into four different types:

* booleans,
* numbers,
* undefiened (null)
* and [Zenlox objects](https://github.com/FrederikTobner/Zenlox#objects) (e.g. a string or a class instance)

## Objects

In Zenlox everything besides the three base data types is considered to be a zenlox object.
Even functions and classes are considered to be a cellox object.
This means that you can for example get the reference to a function and assign it to a variable.

### Functions

Functions in Zenlox are defined using the `fun` keyword. The following example shows how to define a function that takes two arguments and returns their sum.

```Zenlox
fun sum(a, b) {
    return a + b;
}
```

Because functions are first class citizens in Zenlox, you can assign them to variables and pass them as arguments to other functions.

```Zenlox
fun callBackFunction() {
    print "I am a callback function";
}

fun callFunctionWithCallback(callback) {
    print "Im about to call the callback function";
    callback();
}
```

### Strings

Strings in Zenlox are defined using double quotes.

```Zenlox
var name = "Zenlox";
```

Strings are immutable, which means that you can't change the value of a string after it has been created. However, you can concatenate two strings using the `+` operator.

```Zenlox
var firstName = "Zen";
var lastName = "Lox";
var fullName = firstName + lastName; // "ZenLox"
```

Strings are not null terminated, like in C, they are instead length prefixed.
