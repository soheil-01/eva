# Eva

Eva is a simple, interpreted programming language designed for educational purposes. It is implemented in Zig and aims to provide a clear and understandable syntax for beginners learning about programming concepts.

## Run

```bash
zig build run -- example/basic.eva
```

## Examples

### Math Operations

```
1 + 2 * 3 - 4 / 2; // Result: 5
```

### Variables

```
let x = 1;
x; // Result: 1

{
  let y = x + 2;
  y; // Result: 3
}

x = 2;
x; // Result: 2
```

### Relational Operators

```
3 > 2; // Result: true
1 < 2; // Result: true
2 > 4; // Result: false
2 >= 2; // Result: true
1 <= 1; // Result: true
```

### Equality Operators

```
2 + 1 == 3; // Result: true
2 + 3 != 1 + 4; // Result: false
```

## IF Statement

```
let x = 1;
if (x < 2) {
  x = x + 2;
}
// Result: x is now 3

x = 2;
if (x < 2) {
  // do nothing
} else {
  x = 10;
}
// Result: x is now 10
```

### While Loop

```
let i = 0;
while (i < 10) {
  i = i + 1;
}
i; // Result: 10
```

### Do While Loop

```
i = 0;
do {
  i = i + 1;
} while (i < 1);
// Result: i is 1
```

### For Loop

```
let x = 0;
for (let i = 0; i < 10; i = i + 1) {
  x = x + 1;
}
// Result: x is 10
```

### Unary Operators

```
!(2 > 1); // Result: false
6 / -2; // Result: -3
```

### Functions

```
let value = 100;
def calc(x, y){
  let z = x + y;
  def inner(foo){
    return foo + z + value;
  }
  return inner;
}
let fn = calc(10, 20);
fn(30); // Result: 160
```

### Lambda Functions

```
def onClick(callback) {
  let x = 10;
  let y = 20;
  return callback(x+y);
}
onClick(lambda (data) data * 10); // Result: 300

(lambda (x) x * 2)(2); // Result: 4

let square = lambda (x) x * x;
square(4); // Result: 16
```

### Recursive Functions

```
def fact(num) {
  if(num == 1) { return 1; }
  return num * fact(num - 1);
}
fact(5); // Result: 120
```

### Switch Statement

```
let x = 10;
let answer = "";
switch(x){
case 10 {
  answer = "x is 10";
}
case 20 {
  answer = "x is 20";
}
default {
  answer = "x is neither 10 nor 20";
}
}
answer; // Result: "x is 10"
```

### Classes

```
class Point {
  def constructor(self, x, y){
    self.x = x;
    self.y = y;
  }
  def calc(self){
    return self.x + self.y;
  }
}
let p = new Point(10,20);
p.calc(p); // Result: 30

class Point3D extends Point {
  def constructor(self, x, y, z){
    super(Point3D).constructor(self, x, y);
    self.z = z;
  }
  def calc(self){
    return super(Point3D).calc(self) + self.z;
  }
}
let p = new Point3D(10, 20, 30);
p.calc(p); // Result: 60
```

### Logical Operators

```
5 > 3 && 4 < 3 || 5 > 2; // Result: true
```

### Imports

```
let Math = import("math");
Math.abs(-10); // Result: 10
```
