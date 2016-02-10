= yaml =
title: VDL Specification
toc: true
= yaml =

This is a reference manual for VDL, the Vanadium Definition Language.  The intended audience is both end-users writing VDL files, as well as core developers implementing VDL.

VDL is an interface definition language for describing Vanadium components.  It is designed to enable interoperability between implementations executing in heterogeneous environments.  E.g. it enables an Android application running on a phone to communicate with a backend written in Go running on a server.  VDL is compiled into an intermediate representation that is used to generate code in each target environment.

Communication in Vanadium is based on remote procedure calls.  The main concepts in VDL map closely to concepts in general-purpose languages used to specify interfaces and communication protocols.

# Goals
There are three main goals for VDL.  These goals form the core of what a VDL user is trying to accomplish, and also inform tradeoffs in language design and features.  VDL tries to make accomplishing these goals simple.

## Specify the wire format
The main reason to write VDL is to define the wire format between different components.  This is a prerequisite for interoperability; in order to implement a server that may be called by any client in any language, the wire format between the components needs to be defined.

VDL defines its own type and value system, with well-defined semantics.  The VOM (Vanadium Object Marshalling) protocol defines mappings from values of every VDL type to a wire format.  The combination of VDL and VOM enables a simple yet powerful mechanism to specify wire protocols.

## Specify the API
Once a common wire format has been established between components, we need an API to access the functionality in our desired programming environment.  E.g. an Android Java frontend that needs to invoke methods on a Go backend needs a standard way to access that functionality.

APIs are specified by compiling VDL to your target environment.  The VDL compiler converts VDL concepts into idiomatic native constructs in your target environment.

## Usage is optional
The last goal is to ensure the usage of VDL is optional.  Users have a choice to forgo VDL if it doesn't adequately benefit their usage scenario.  E.g. two Android Java components may choose to communicate directly as full-fledged Vanadium components, without using VDL at all.

# Syntax
The VDL syntax is based on the Go language, which has a compact and regular grammar.

## Comments
There are two forms of comments:
1. Line comments start with the character sequence `//` and stop at the end of the line.  A line comment acts like a newline.
2. General comments start with the character sequence `/*` and continue through the character sequence `*/`.  A general comment containing one or more newlines acts like a newline, otherwise it acts like a space.

Comments do not nest.

## Semicolons
The grammar uses semicolons `;` as terminators in many productions.  Idiomatic VDL omits most of these semicolons using the following two rules:
1. When the input is broken into tokens, a semicolon is automatically inserted into the token stream at the end of a non-blank line if the line's final token is an identifier, literal (string_lit, integer_lit, rational_lit, or imaginary_lit), or closing fence (`)`, `]`, `}` or `>`).
2. A semicolon may be omitted before a closing `)` or `}`.

## Identifiers
Identifiers name entities such as types and methods.  An identifier is a sequence of one or more ASCII letters and digits.  The first character of an identifier must be a letter.  We intentionally restrict to ASCII to more naturally support common generated languages.
```
identifier = [A-Za-z][A-Za-z0-9_]*
```
Examples of valid identifiers:
```
a
this_is_an_identifier_
AsIsThis
```
Identifiers may either be exported or unexported.  Exported identifiers may be used by other packages; unexported identifiers may not.  An identifier is exported if the first character is uppercase `[A-Z]`.  Most identifiers are required to be exported in VDL; exceptions to this rule are noted.
```
notExported
alsoNotExported
ThisIsExported
```

Here is a complete list of VDL keywords.  Keywords may not be used as identifiers.
```
const enum error import interface map package
set stream struct type typeobject union
```

## Built-in identifiers
The following identifiers are built-in, and used to bootstrap the language to make it useful.  All built-in identifiers are available for use within other packages.
```
// Built-in types
any bool byte error string typeobject
complex64 complex128
float32 float64
int16 int32 int64
uint16 uint32 uint64

// Built-in constants
false true nil
```

## Example
Here is a simplified example of two single-file VDL packages that showcase most of the main concepts.
```
// File: example/bignum/bignum.vdl

// All vdl files must start with a package clause.
package bignum

// Named types may be created based on any other type.
type Int string // arbitrary-precision integer

// Constants are unchanging values of any type.
const (
  MaxInt8 = Int("127")
  MinInt8 = Int("-128")
)
```
<!--separate code blocks-->
```
// File: example/arith/arith.vdl

package arith

import (
  "time"           // time is a standard package
  "example/bignum" // bignum is the package above
)

// Status is a conjunction of many fields.
type Status struct {
  Wall, Cpu time.Duration
  Alg       Algorithm
}

// Enum types have no mapping to numeric values.
type Algorithm enum {Sieve;Elliptic}

// Constants of any type may be expressed.
const UnknownStatus = Status{Wall: -1, Cpu: -1, Alg: Sieve}

// Interfaces define a set of methods, along with a name.
type Arith interface {
  // Add returns x + y.
  Add(x, y bignum.Int) (bignum.Int | error)

  // Div returns x / y, or the DivByZero error.
  Div(x, y bignum.Int) (bignum.Int | error)
}

// Interfaces may embed other interfaces.
type Advanced interface {
  // Arith is embedded in the Advanced interface;
  // Advanced contains the methods Add, Div, Factor.
  Arith
  // Factor demonstrates output streaming; 0 or more Status
  // values are returned before the factors.
  Factor(x bignum.Int) stream<_,Status> ([]bignum.Int | error)
}

// Errors may be defined for use across languages.
error DivByZero() {"en": "divide by zero"}
```

# Packages
VDL is organized into packages, where a package is a collection of one or more source files.  The files in a package collectively define the types, constants, interfaces and errors belonging to the package.  Those elements may in turn be used in another package.

Each source file consists of a package clause, followed by a (possibly empty) set of imports, followed by a (possibly empty) set of definitions.
```
SourceFile = PackageClause ";" {Import ";"} {Def ";"}
Def        = TypeDef | ConstDef | InterfaceDef | ErrorDef

PackageClause = "package" PackageName
PackageName   = identifier
```
A package clause begins each source file, and defines the package to which the file belongs.  A set of files in the same directory sharing the same PackageName form the definition of a package.  By convention the PackageName is the basename of the directory containing the source files.
```
package bignum
```

# Standard packages

VDL comes with a collection of standard packages, which define common types and
interfaces that may be used by all applications. E.g. the [time
package](https://github.com/vanadium/go.v23/blob/master/vdlroot/time/time.vdl)
defines a standard representation of time, to promote compatibility across
different computing environments.

The current set of [standard
packages](https://github.com/vanadium/go.v23/blob/master/vdlroot) is small, and
will grow over time to provide more standardized representations of core
concepts.

# Imports
An import states that the source file containing the import depends on the imported package, and enables access to the exported identifiers of that package.  Cyclic dependencies are not allowed.  The PackageName is used as the first component of a QualifiedName, and is used to access identifiers of that package within the importing source file.  If the PackageName is omitted, it defaults to the identifier specified in the PackageClause of the imported package.
```
Import = "import" ImportSpec
       | "import" "(" [ ImportSpec {";" ImportSpec} [";"] ] ")"

ImportSpec    = [PackageName] ImportPath
ImportPath    = string_lit
QualifiedName = PackageName "." identifier
NameRef       = QualifiedName | identifier
```
Examples of imports:
```
import "time"
import big "example/bignum"
```

# Types
A type specifies a set of valid values.  The set of valid types is partitioned into different kinds, where each kind of type specifies its own rules determining the valid set of values.
```
// Built-in scalar type kinds
bool            // boolean true / false
string          // sequence of UTF8 runes
byte            // unsigned byte (8 bits)
uint{16,32,64}  // unsigned integer
int{16,32,64}   // signed integer
float{32,64}    // IEEE 754 floating point
complex{64,128} // complex number, both parts floating point
typeobject      // type represented as a value

// User-defined scalar and composite type kinds
enum   // one of a set of labels
array  // fixed-length ordered sequence of elems
list   // variable-length ordered sequence of elems
set    // unordered collection of distinct keys
map    // unordered mapping between distinct keys and elems
struct // conjunction of ordered sequence of fields
union  // disjunction of ordered sequence of fields

// Variant type kinds
any             // value can be of any type
optional        // value might not exist
```

Types may be named or unnamed.  All built-in types are named with the name of their kind.  Types defined using the `type` keyword are named by the user.  The `any` and `typeobject` type kinds *cannot* be named by the user; all other kinds *can* be named by the user, and the `enum`, `struct` and `union` type kinds *must* be named by the user.  These naming rules strike a balance between expressibility in the VDL and practical limitations for generated code.

`bool` represents boolean true and false values.

`string` represents a human-readable sequence of UTF8 runes.  Arbitrary binary data should not be represented using strings, instead use an `array` or `list` of bytes.

`byte` represents a single unsigned 8-bit byte.

`uint` represents unsigned integers of 16, 32 or 64 bits.

`int` represents signed integers of 16, 32 or 64 bits.

`float` represents IEEE 754 floating point numbers of 32 or 64 bits.

`complex` represents complex numbers, where both the real and imaginary parts are floating point numbers.  Complex64 is composed of two 32 bit floats, while complex 128 is composed of two 64 bit floats.

`typeobject` represents a type as a value; types are also first-class values.  This is used to represent method signatures, and pass type information between components.

`enum` represents a choice between a finite set of labels.  There is no concept of a corresponding numeric value; the label determines the choice.

`array` represents a fixed-length ordered sequence of elements, all of the same type.

`list` represents a variable-length ordered sequence of elements, all of the same type.

`set` represents an unordered collection of distinct keys, all of the same type.

`map` represents an unordered association between distinct keys and elements, where all keys are of the same type, and all elements are of the same type.

`struct` represents a conjunction of an ordered sequence of fields, where each field is a (name,type) pair.

`union` represents a disjunction of an ordered sequence of fields, where each field is a (name,type) pair.
```
TypeDef   = "type" TypeSpec
          | "type" "(" [ TypeSpec {";" TypeSpec} [";"] ] ")"
TypeSpec  = TypeName TypeExpr
TypeName  = identifier
TypeExpr  = NameRef
          | "error"
          | "enum" "{" Label {";" Label} [";"] "}"
          | "[" integer_lit "]" TypeExpr
          | "[" "]" TypeExpr
          | "set" "[" TypeExpr "]"
          | "map" "[" TypeExpr "]" TypeExpr
          | "struct" "{" [ Field {";" Field} [";"] ] "}"
          | "union" "{" [ Field {";" Field} [";"] ] "}"
          | "?" TypeExpr
Label     = identifier
Field     = FieldName {"," FieldName} TypeExpr
```
Examples of type definitions:
```
type Int string
type Algorithm enum {Sieve;Elliptic}
type Status struct {
  Wall, Cpu time.Duration
  Alg       Algorithm
}
```

# Constants
A constant represents an immutable value.  Constants may be typed or untyped.  There are six categories of constants, representing various typed and untyped combinations.  Typed constants may represent any valid value for their kind of type.  Untyped integer, rational and complex constants are collectively called numerics, and have "infinite" precision; they do not overflow or underflow.

```
category  untyped constant  type kind
--------  ----------------  ---------
boolean   untyped boolean   bool
string    untyped string    string, []byte
integer   untyped integer   byte, {u,}int{16,32,64}
rational  untyped rational  float{32,64}
complex   untyped complex   complex{64,128}
misc                        enum, typeobject, array, list,
                            set, map, struct, union
```

The following constants are built-in:
```
false: Untyped boolean constant
true:  Untyped boolean constant
nil:   Represents non-existent optional value
```

# Literals
There are four categories of scalar literals: string, integer, rational and imaginary.  Each literal represents its respective untyped constant, where the imaginary literal represents an untyped complex constant with real part zero.
```
string_lit    = /* e.g. "abc" `def` */
integer_lit   = /* e.g. 0 123 0644 0xDeadBeef */
rational_lit  = /* e.g. 0. .25 42.3 1e6 .123e+3 */
imaginary_lit = /* e.g. 0i 0.i 123i .25i 1e6i .12e+3i */
```

Composite literals are also supported, and represent arrays, lists, sets, maps, structs and unions.  The type of every composite literal needs to be known in order for it to be compiled.  The full syntax is in the grammar; informally it looks like:
```
TypeExpr{key0:elem0, key1:elem1, ...}
```

The TypeExpr may be explicitly provided, or as a convenience, the TypeExpr may be elided for composite literals within a parent composite literal where the type may be implied.

Array and list literals have optional keys and required elems, and each elem is assigned to list[index].  If a key is provided, the index is set to the key converted to a uint64; otherwise the index is set to one more than the previous index, or 0 if key0 isn't provided.

Set literals have required keys and may not specify elems.  Map literals have required keys and elems.

Struct literals must either have all keys provided, or no keys provided.  If keys are provided they are identifiers that must match field names of the struct, and the matching field is set to elem.  If keys are not provided, the fields of the struct are set in order, and the number of elems must exactly match the number of fields in the struct.

Union literals must specify a single `key:elem` pair, where the key must match a single field name of the union.

Enum constants are specified using the selector syntax.
```
type Mode enum {Fast;Slow}

// Enum constant
const MyMode = Mode.Fast
```

Typeobject constants are specified using syntax similar to explicit type conversions.
```
type Foo struct {A int32;B string}

// Typeobject constants
const (
  MyFooType     = typeobject(Foo)
  MyFooListType = typeobject([]Foo)
)
```

# Operators
Logical, bitwise, comparison and arithmetic operators are supported.  Not all operators support all constants.  The following table shows the operators and the supported constant categories.
```
// Unary operator (boolean)
!          // logical not

// Unary operator (integer)
^          // bitwise not

// Unary operator (integer, rational, complex)
+ -        // no-op | negate

// Binary operator (all)
== !=      // equal, not equal

// Binary operator (boolean)
&& ||      // logical {and,or}

// Binary operator (integer)
%          // mod
& | ^      // bitwise {and,or,xor}
<< >>      // shift {left,right}

// Binary operator (integer, rational, string)
< <= > >=  // less{,equal} greater{,equal}

// Binary operator (integer, rational, complex)
+          // add
- * /      // sub, mul, div
```

Binary operators are of the form `x op y`.  If x and y are both typed constants, their types must be identical.  If either x or y (or both) are untyped constants, the values are implicitly converted to a common type before performing the operation.

# Conversions
Implicit conversions of untyped constants obey the following rules:
```
implicit conversion                   details
-------------------                   -------
untyped integer  -> untyped rational  Allowed
untyped rational -> untyped complex   Allowed
untyped complex  -> untyped rational  Only if 0 imaginary
untyped rational -> untyped integer   Only if 0 fractional
untyped integer  -> {byte,uint,int}*  Only if no overflow
untyped rational -> float*            Only if no overflow,
                                      may lose precision
untyped complex  -> complex*          Only if no overflow,
                                      may lose precision
```

Explicit conversions of scalars add the following rules:
```
explicit scalar conversion            details
--------------------------            -------
same kind -> same kind                Allowed
string    -> []byte                   Allowed
[]byte    -> string                   Only if bytes are UTF8
enum      -> {string,[]byte}          Allowed, uses label
{string,[]byte}  -> enum              Only if label is valid
{byte,uint,int}* -> {byte,uint,int}*  Only if no overflow
{byte,uint,int}* -> float*            Only if no loss
                                      of precision
float*   -> {float,complex}*          Allowed,
                                      may lose precision
complex* -> complex*                  Allowed,
                                      may lose precision
complex* -> float*                    Only if 0 imaginary,
                                      may lose precision
float*   -> {byte,uint,int}*          Only if 0 fractional,
                                      and if no overflow
```

Explicit conversions of composites add the following rules:
```
     explicit
composite conversion   details
--------------------   -------
{array,list} -> array  Only if elems are convertible,
                       and if src len <= dst array len
{array,list} -> list   Only if elems are convertible
set -> set             Only if keys are convertible
set -> map             Only if keys are convertible,
                       result type map[key]bool
map -> set             Only if keys are convertible,
                       and if map elem is bool or struct{}
map -> map             Only if keys and elems
                       are convertible
struct -> map          Only if field names and elems
                       are convertible
struct -> struct       Only if fields with matching names
                       are convertible
					   [unknown fields ignored]
map -> struct          Only if fields with matching keys
                       are convertible
					   [unknown fields ignored]
```

# Evaluation and definition
Named constants are defined using the const keyword.  Named consts and method tags are fully evaluated to a final value.  Intermediate results of const expressions may remain untyped, but final const values must be typed.  This restriction ensures const expression evaluation always occurs within the VDL compiler, and all generated code uses identical const values.  Otherwise we'd be at the mercy of the compilers / interpreters for the generated languages, which has a wide variance in expression evaluation semantics.
```
ConstDef  = "const" ConstSpec
          | "const" "(" [ ConstSpec {";" ConstSpec} [";"] ] ")"
ConstSpec = ConstName "=" ConstExpr
ConstName = identifier
ConstExpr = UnaryExpr | ConstExpr binary_op ConstExpr
UnaryExpr = PrimaryExpr | unary_op UnaryExpr
PrimaryExpr = NameRef
            | NameRef "(" ConstExpr ")"
            | "(" ConstExpr ")"
            | PrimaryExpr "." identifier
            | "typeobject" "(" TypeExpr ")"
            | string_lit | integer_lit | rational_lit | imaginary_lit | CompLit
binary_op  = "||" | "&&" | "==" | "!=" | "<" | "<=" | ">" | ">=" |
             "+"  | "-"  | "*"  | "/"  | "%" | "|"  | "&" | "^"  | "<<" | ">>"
unary_op   = "!"  | "+"  | "-"  | "^"
CompLit   = [TypeExpr] "{" [ KVLit {"," KVLit} [","] ] "}"
KVLit     = [KLit ":"] VLit
KLit      = ConstExpr
VLit      = ConstExpr | CompLit
```
Examples of const definitions:
```
const (
  MaxInt8       = Int("127")
  MinInt8       = Int("-128")
  Five          = int32(2 + 3)
  UnknownStatus = Status{Wall: -1, CPU: -1}
)
```

# Interfaces
An interface represents a set of methods.  Every interface has an InterfaceName.  Interfaces can embed other interfaces by referring to their InterfaceName.  This adds all methods of the embedded interface to the set of methods in the embedding interface.  Duplicate names are allowed, but only if the method signatures are identical.  Code generation for some languages may add additional semantics; e.g. object-oriented languages may use embedding as a signal for an inheritance relationship.

Every method is named and contains optional InArgs, InStream and OutStream types, OutArgs and Tags.  The InArgs and OutArgs are positional, and arg names idiomatically start with a lowercase letter.  A single underscore "_" may be used as the InStream or OutStream type, which means there is no respective in or out stream type.  Idiomatic usage only uses the underscore if there is no InStream, but there is an OutStream type.

The general flow for a method call is as follows:
* MethodName and InArgs are dispatched to the receiver.
* A sequence of InStream and OutStream values may be sent and received, respectively.  The exact protocol depends on the semantics of the method.
* OutArgs are returned to the caller.

Tags are only used as metadata, and are not sent to the receiver during the actual method call.  Each tag const expression is evaluated to a final result by the compiler, and the generated code provides a mechanism to retrieve the tags.  Tags are typically used as method annotations; e.g. each method might be annotated with a security permissions specifying access control.  Idiomatic usage uses the type of each tag to determine the appropriate behavior.
```
InterfaceDef  = "type" InterfaceSpec
              | "type" "(" [ InterfaceSpec {";" InterfaceSpec} [";"] ] ")"
InterfaceSpec = InterfaceName "interface" "{" [ MethodOrEmbed {";" MethodOrEmbed} [";"] ] "}"
InterfaceName = identifier
MethodOrEmbed = Method | NameRef
Method        = MethodName "(" [InArgs] ")" [StreamTypes] [OutArgs] [Tags]
MethodName    = identifier
Args          = Field {"," Field} [","]
              | TypeExpr {"," TypeExpr} [","]
InArgs        = Args
OutArgs       = "error"
              | "(" Args "|" "error" ")"
StreamTypes   = "stream" "<" [ InStream [ "," OutStream ] ] ">"
InStream      = TypeExpr
OutStream     = TypeExpr
Tags          = "{" [ ConstExpr {"," ConstExpr} [","] ] "}"
```
Examples of interface definitions:
```
type Arith interface {
  Add(x, y bignum.Int) (bignum.Int | error)
  Div(x, y bignum.Int) (bignum.Int | error) {"tag"}
}
type Advanced interface {
  Arith
  Factor(x bignum.Int) stream<_,Status> ([]bignum.Int | error)
}
```

# Errors
An error represents an exceptional condition.  VDL defines a built-in `error` type which enables interoperability of error creation and checking across computing environments.  E.g. VDL errors are generated as error values in Go, while they're generated as exceptions in Java.  The core libraries allow you to check for occurrences of specific errors, even if the error was generated in a different process, or a different programming language.

The wire format of the VDL `error` looks like this:
```
type RetryCode enum {
  NoRetry         // Do not retry.
  RetryConnection // Retry high-level connection/context.
  RetryRefetch    // Refectch and retry (e.g., out of date version).
  RetryBackoff    // Backoff and retry a finite number of times.
}

type error struct {
  Id        string    // Identity of the error.
  Msg       string    // Error message, generated based on Id and ParamList.
  RetryCode RetryCode // Suggested retry behavior upon receiving this error.
  ParamList []any     // Variadic parameters associated with the error.
}
```

Specific error instances may be defined in VDL.  This generates code in each native language, to make it easy to create and check errors.  Each error includes a unique identifier, which is automatically created with the form `PackagePath.ErrorName`.  E.g. an error definition with name `Foo` in package path `"a/b/c"` results in error id `"a/b/c.Foo"`.
```
ErrorDef     = "error" ErrorSpec
             | "error" "(" [ ErrorSpec {";" ErrorSpec} [";"] ] ")"
ErrorSpec    = ErrorName "(" [InArgs] ")" ErrorDetails
ErrorName    = identifier
ErrorDetails = "{" ErrorDetail {"," ErrorDetail} [","] "}"
ErrorDetail  = ErrorAction
             | ErrorLang ":" ErrorFmt
ErrorAction  = identifier
ErrorLang    = string_lit
ErrorFmt     = string_lit
```
Examples of error definitions:
```
error (
  NoParams1() {"en":"en msg"}
  NoParams2() {RetryRefetch, "en":"en msg"}
  WithParams1(x string, y int32) {"en":"en x={x} y={y}"}
  WithParams2(x string, y int32) {
    RetryRefetch,
    "en":"en x={x} y={y}",
    "fr":"fr y={y} x={x}",
  }
)
```

# Config files
Config files are a mechanism to specify configuration information to a program.  E.g. a command line program may need to be configured with directory paths for input or output.  Since VDL already has syntax to represent types and constants, it is natural to use the same syntax to represent configuration information.

A config file exports a single constant, and may contain one or more imports and constants.  All constants representable in regular VDL are representable in config files, using the same syntax.

Each config file consists of a config clause, followed by a (possibly empty) set of imports, followed by a (possibly empty) set of const definitions.  The config clause defines the exported constant via a ConstExpr.  As with regular constant expressions, the config clause definition may be an inline definition, or may simply name a const defined elsewhere in the file.
```
ConfigFile = ConfigClause ";" {Import ";"} {ConstDef ";"}
ConfigClause = "config" "=" ConstExpr
```
Examples of config files:
```
// File: 0.config - inline definition
// (implicit type arith.Status)
config = {0, 0, arith.Algorithm.Sieve}
```
<!--separate code blocks-->
```
// File: 1.config - using imports
config = foo

import "example/arith"

const (
  foo = arith.Status{0, 0, arith.Algorithm.Sieve}
  bar = arith.Status{1, 1, arith.Algorithm.Elliptic}
)
```

Config files only contain constant definitions; types, interfaces and errors may not be specified within config files.  It is idiomatic to define a struct type specifying the format of the config file in a package, and export a constant of that type from the config file.

Config files that use more than the built-in types need to import the packages defining the necessary types.  As a commonly-used exception to this rule, an implicit type may be provided to the config file compiler.  The implicit type is used to specify the type of the exported constant, if it is a composite literal that don't have an explicit type.  This allows the succinct inline definition syntax to be used, without specifying any imports.

All valid config files must start with "config".  However "config" is not itself a keyword in the grammar; it may be used as a regular identifier.

## vdl.config

The vdl tool is an example of a command-line program that requires configuration; e.g. there are options for code generation in each native language.  Each vdl package directory may contain a special `vdl.config` file, representing the configuration for that vdl package.  The `vdl.config` file is written in the generic VDL config file syntax, exporting a constant with type [vdltool.Config](https://github.com/vanadium/go.v23/blob/master/vdlroot/vdltool/config.vdl).  An example is the [vdl.config file](https://github.com/vanadium/go.v23/blob/master/vdlroot/time/vdl.config) for the standard time package.
