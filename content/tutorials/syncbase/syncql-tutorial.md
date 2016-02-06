= yaml =
title: SyncQL Tutorial
layout: tutorial
wherein: you learn about the Syncbase query language.
toc: true
= yaml =

# Overview

Syncbase is Vanadium's key/value store and provides persistent data with fine grained access and synchronization across Syncbase instances.

SyncQL is a SQL-like query language for Syncbase.

This tutorial walks one through the setup of a sample database and then dives into teaching syncQL by running command-line queries.

# How to Take this Tutorial

This tutorial assumes one has a working Vanadium development environment.

All of the steps are independent, so one can pick up anywhere he wishes.  Just perform the [setup](#setup) steps to start/restart and the [teardown](#teardown) steps to finish/take a break.

It's OK to cut and paste the [setup](#setup) and [teardown](#teardown) steps, but please consider typing the queries rather than cutting and pasting them.  Actually typing the queries (and making mistakes and correcting them) is a great way to learn.

# Setup

This set of step-by-step instructions assumes one has a working Vanadium development environment, which includes having the `JIRI_ROOT` environment variable set.

**[NOTE]** For the Vanadium and/or Syncbase literate, it's OK to skip and/or modify some of these steps.

1. Build and install the necessary executables (principal program, mount table daemon, Syncbase daemon, Syncbase command-line program):

        jiri go install v.io/x/ref/cmd/principal v.io/x/ref/services/mounttable/mounttabled v.io/x/ref/services/syncbase/syncbased v.io/x/ref/cmd/sb

2. Create a principal using a self-signed blessing:

        $JIRI_ROOT/release/go/bin/principal create /tmp/me $($JIRI_ROOT/release/go/bin/principal blessself)

3. Start the mounttable and Syncbase daemons (start in foreground to enter root password, then send to background):

        $JIRI_ROOT/release/go/bin/mounttabled -v23.tcp.address=:8101
        <ctrl-z>
        bg
        $JIRI_ROOT/release/go/bin/syncbased -name '/:8101/syncbase' -v23.credentials=/tmp/me -root-dir=/tmp/sbroot
        <ctrl-z>
        bg

4. Start `sb` (Syncbase command-line program):

        $JIRI_ROOT/release/go/bin/sb sh -create-missing -v23.credentials=/tmp/me demoapp demodb

5. Create a demo database:

        ? make-demo;

**[NOTE]** When you finish the tutorial (or want to take a break), execute the [teardown](#teardown) steps below to clean up!

# Executing Queries in "sb"

If one has performed the setup steps above, he will be sitting in `sb` at the '?' prompt.

To make sure everything is running properly, dump the database with the following command (be sure to include the semicolon):

    dump;

If a bunch of data prints to the screen, everything is properly setup.  If not, execute the [teardown](#teardown) steps below and then re-execute the steps above.

Don't try to understand all of the data that was printed with the dump command.  The tables in the demo database are overly complicated in order to demonstrate all of the features of syncQL.  We'll take things a step at a time and only explain the data as needed.

Note: The vdl objects stored in the demo database are described in the following file:

    $JIRI_ROOT/release/go/src/v.io/x/ref/cmd/sb/internal/demodb/db_objects.vdl

# SyncQL 101

## The Basics

SyncQL looks a lot like SQL.  Each table in a Syncbase database looks like a table with exactly two columns, k and v:

* `k`
    * the key portion of key/value pairs in the table
    * always of type string
* `v`
    * the value portion of key/value pairs in the table
    * always of type vdl.Value

### vdl

A vdl.Value can represent the following types:

<!-- TODO: Maybe use GFM tables here. -->
<table>
  <tr>
    <td>Any</td>
    <td>Array</td>
    <td>Bool</td>
    <td>Byte</td>
    <td>Complex64</td>
    <td>Complex128</td>
    <td>Enum</td>
  </tr>
  <tr>
    <td>Float32</td>
    <td>Float64</td>
    <td>Int16</td>
    <td>Int32</td>
    <td>Int64</td>
    <td>List</td>
    <td>Map</td>
  </tr>
  <tr>
    <td>Set</td>
    <td>String</td>
    <td>Struct</td>
    <td>Time</td>
    <td>TypeObject</td>
    <td>Union</td>
    <td>Uint16</td>
  </tr>
  <tr>
    <td>Uint32</td>
    <td>Uint64</td>
    <td>?&lt;type&gt;</td>
    <td></td>
    <td></td>
    <td></td>
    <td></td>
  </tr>
</table>

## A Simple Query

The Customers table stores values of type Customer and of type Invoice.

Let's select all of the keys in the Customer table.  Again, note the semicolon.  The semicolon is **not** part of the query, but `sb` uses it as a marker for end of statement.

    ? select k from Customers;
    +--------+
    |      k |
    +--------+
    | 001    |
    | 001001 |
    | 001002 |
    | 001003 |
    | 002    |
    | 002001 |
    | 002002 |
    | 002003 |
    | 002004 |
    +--------+

### Checker-time Errors

Let's do the above query, but use Customer as the table name (i.e., forget to type the 's' at the end):

    ? select k from Customer;
    Error:
    select k from Customer
                  ^
    15: Table Customer does not exist (or cannot be accessed): syncbased:"demoapp/demodb".Exec: Does not exist: $table:Customer.

The query can be fixed by up-arrowing and fixing it or by simply retyping it.

    ? select k from Customers;
    +--------+
    |      k |
    +--------+
    | 001    |
    | 001001 |
    | 001002 |
    | 001003 |
    | 002    |
    | 002001 |
    | 002002 |
    | 002003 |
    | 002004 |
    +--------+

SyncQL will catch and report the following types of errors before attempting to execute:

* malformed queries (e.g., forgetting the required from clause)
* mistyped table names
* wrong number of arguments to a function
* wrong type of literal (as an argument to a function or to a like expression)

Unfortunately, mistyping field names will **not** be caught.  This is because syncQL doesn't know the fields of the values in the database.  That's because Syncbase allows anything to be stored in values.

### Drilling Into the 'v' Column

The Customer type has a Name field.  Let's ask for it by using dot notation:

    ? select k, v.Name from Customers;
    +--------+---------------+
    |      k |        v.Name |
    +--------+---------------+
    | 001    | John Smith    |
    | 001001 |               |
    | 001002 |               |
    | 001003 |               |
    | 002    | Bat Masterson |
    | 002001 |               |
    | 002002 |               |
    | 002003 |               |
    | 002004 |               |
    +--------+---------------+

You will notice that only keys "001" and "002" have values for Name.  Let's see why that is.

### Discovering Type of Values

Let's find out the types of the values in the Customers table:

    ? select k, Type(v) from Customers;
    +--------+--------------------------------------------+
    |      k |                                       Type |
    +--------+--------------------------------------------+
    | 001    | v.io/x/ref/cmd/sb/internal/demodb.Customer |
    | 001001 | v.io/x/ref/cmd/sb/internal/demodb.Invoice  |
    | 001002 | v.io/x/ref/cmd/sb/internal/demodb.Invoice  |
    | 001003 | v.io/x/ref/cmd/sb/internal/demodb.Invoice  |
    | 002    | v.io/x/ref/cmd/sb/internal/demodb.Customer |
    | 002001 | v.io/x/ref/cmd/sb/internal/demodb.Invoice  |
    | 002002 | v.io/x/ref/cmd/sb/internal/demodb.Invoice  |
    | 002003 | v.io/x/ref/cmd/sb/internal/demodb.Invoice  |
    | 002004 | v.io/x/ref/cmd/sb/internal/demodb.Invoice  |
    +--------+--------------------------------------------+

We now have an explanation for why the Name column is missing on some rows.  The type is not Customer on these rows.  It is Invoice and-it just so happens-Invoice has no field with the name of "Name".  Unresolved fields in the select clause return nil.  `sb` represents nil as empty in output.

### Limiting Rows by Type

Let's print the name of only rows where the value type is Customer.

    ? select v.Name from Customers where Type(v) = "v.io/x/ref/cmd/sb/internal/demodb.Customer";
    +---------------+
    |        v.Name |
    +---------------+
    | John Smith    |
    | Bat Masterson |
    +---------------+

`Type()` is a function available in syncQL.  It returns a string representing a fully qualified type.  It can be used in a where clause to limit the rows (i.e., the k/v pairs) matching a query.

Having to specify a fully qualified type is rarely necessary.  Let's use the like operator to write a simpler query:

    ? select v.Name from Customers where Type(v) like "%Customer";
    +---------------+
    |        v.Name |
    +---------------+
    | John Smith    |
    | Bat Masterson |
    +---------------+

The like operator takes a string value on the right-hand-side.  In this value, `%` matches 0 or more of any character.  (Also, `_` matches any single character.)

### The Invoice Type

The Invoice type is defined as:

    type Invoice struct {
            CustId     int64
            InvoiceNum int64
            Amount     int64
            ShipTo     AddressInfo
    }

Let's print CustId, InvoiceNum and Amount for values of type Invoice:

    ? select v.CustId, v.InvoiceNum, v.Amount from Customers where Type(v) like "%Invoice";
    +----------+--------------+----------+
    | v.CustId | v.InvoiceNum | v.Amount |
    +----------+--------------+----------+
    |        1 |         1000 |       42 |
    |        1 |         1003 |        7 |
    |        1 |         1005 |       88 |
    |        2 |         1001 |      166 |
    |        2 |         1002 |      243 |
    |        2 |         1004 |      787 |
    |        2 |         1006 |       88 |
    +----------+--------------+----------+

The where clause can contain any number of comparison expressions joined with "and" or "or".  Parentheses are used to specify precedence.  For example, let's make a [nonsensical] query for all customer #1 invoices for an amount < 50 and all customer #2 invoices for an amount > 200:

    ? select v.CustId, v.InvoiceNum, v.Amount from Customers where Type(v) like "%Invoice" and ((v.CustId = 1 and v.Amount < 50) or (v.CustId = 2 and v.Amount > 200));
    +----------+--------------+----------+
    | v.CustId | v.InvoiceNum | v.Amount |
    +----------+--------------+----------+
    |        1 |         1000 |       42 |
    |        1 |         1003 |        7 |
    |        2 |         1002 |      243 |
    |        2 |         1004 |      787 |
    +----------+--------------+----------+

### Unresolved Fields in the Where Clause

We've already seen that unresolved fields in the select clause return nil.  Unresolved fields in expressions in the where clause result in the expression evaluating to false.

Let's see this in action:

The Customer type is defined as:

    type Customer struct {
            Name    string
            Id      int64
            Active  bool
            Address AddressInfo
            Credit  CreditReport
    }

Let's select Customers with `Id > 0`:

    ? select v.Name from Customers where v.Id > 0;
    +---------------+
    |        v.Name |
    +---------------+
    | John Smith    |
    | Bat Masterson |
    +---------------+

Since `v.Id` is not resolvable for Invoice records (which do not contain an Id field), the expression `v.Id > 0` returns false for Invoice rows.  As such, the query excludes invoices and returns only the Customer rows.

# SyncQL 201: A Closer Look

## Select Clause

Let's take a close look at what columns can be specified in the select clause.

A column may be of one of the following categories:

* k - the key column
* v - the value column
* field - a specific field in the value
* function - a function which takes zero or more arguments (k, v, field or function)

Let's select a column from each category above:

    ? select k, v, v.ShipTo.City, Lowercase(v.ShipTo.City) from Customers where Type(v) like "%Invoice";
    +--------+---------------------------------------------------------------------------------------------------------------------------+---------------+-----------+
    |      k |                                                                                                                         v | v.ShipTo.City | Lowercase |
    +--------+---------------------------------------------------------------------------------------------------------------------------+---------------+-----------+
    | 001001 | {CustId: 1, InvoiceNum: 1000, Amount: 42, ShipTo: {Street: "1 Main St.", City: "Palo Alto", State: "CA", Zip: "94303"}}   | Palo Alto     | palo alto |
    | 001002 | {CustId: 1, InvoiceNum: 1003, Amount: 7, ShipTo: {Street: "2 Main St.", City: "Palo Alto", State: "CA", Zip: "94303"}}    | Palo Alto     | palo alto |
    | 001003 | {CustId: 1, InvoiceNum: 1005, Amount: 88, ShipTo: {Street: "3 Main St.", City: "Palo Alto", State: "CA", Zip: "94303"}}   | Palo Alto     | palo alto |
    | 002001 | {CustId: 2, InvoiceNum: 1001, Amount: 166, ShipTo: {Street: "777 Any St.", City: "Collins", State: "IA", Zip: "50055"}}   | Collins       | collins   |
    | 002002 | {CustId: 2, InvoiceNum: 1002, Amount: 243, ShipTo: {Street: "888 Any St.", City: "Collins", State: "IA", Zip: "50055"}}   | Collins       | collins   |
    | 002003 | {CustId: 2, InvoiceNum: 1004, Amount: 787, ShipTo: {Street: "999 Any St.", City: "Collins", State: "IA", Zip: "50055"}}   | Collins       | collins   |
    | 002004 | {CustId: 2, InvoiceNum: 1006, Amount: 88, ShipTo: {Street: "101010 Any St.", City: "Collins", State: "IA", Zip: "50055"}} | Collins       | collins   |
    +--------+---------------------------------------------------------------------------------------------------------------------------+---------------+-----------+

Depending on how wide your window is, the above mayh be a mess to look at.  Selecting v in a program is often useful, but selecting such an aggregate from `sb` is less so.  Let's do that query again without selecting v as a whole:

    ? select k, v.ShipTo.City, Lowercase(v.ShipTo.City) from Customers where Type(v) like "%Invoice";
    +--------+---------------+-----------+
    |      k | v.ShipTo.City | Lowercase |
    +--------+---------------+-----------+
    | 001001 | Palo Alto     | palo alto |
    | 001002 | Palo Alto     | palo alto |
    | 001003 | Palo Alto     | palo alto |
    | 002001 | Collins       | collins   |
    | 002002 | Collins       | collins   |
    | 002003 | Collins       | collins   |
    | 002004 | Collins       | collins   |
    +--------+---------------+-----------+

v.ShipTo.City is interesting because it reaches into a nested struct.  In this case, ShipTo is a field in type Invoice.  ShipTo is of type AddressInfo, which is defined as:

    type AddressInfo struct {
            Street string
            City   string
            State  string
            Zip    string
    }

v.ShipTo resolves to an instance of AddressInfo.  v.ShipTo.City resolves to an instance of string since City is a string field in AddressInfo.

The Lowercase function takes a single string argument and simply returns a lowercase version of the argument.

### Details on Value Field Specifications

Up until now, we've used dot notation to specify fields within a struct (e.g., v.Name).  Let's look at the full picture.

As mentioned before, values in Syncbase are vdl.Values.  A vdl.Value can represent any of the following types:

<!-- TODO: Maybe use GFM tables here. -->
<table>
  <tr>
    <td>Any</td>
    <td>Array</td>
    <td>Bool</td>
    <td>Byte</td>
    <td>Complex64</td>
    <td>Complex128</td>
    <td>Enum</td>
  </tr>
  <tr>
    <td>Float32</td>
    <td>Float64</td>
    <td>Int16</td>
    <td>Int32</td>
    <td>Int64</td>
    <td>List</td>
    <td>Map</td>
  </tr>
  <tr>
    <td>Set</td>
    <td>String</td>
    <td>Struct</td>
    <td>Time</td>
    <td>TypeObject</td>
    <td>Union</td>
    <td>Uint16</td>
  </tr>
  <tr>
    <td>Uint32</td>
    <td>Uint64</td>
    <td>?&lt;type&gt;</td>
    <td></td>
    <td></td>
    <td></td>
    <td></td>
  </tr>
</table>

#### Primitives

The following vdl types are primitives and cannot be drilled into further:

* Bool
* Byte
* Complex64
* Complex128
* Enum
* Float32
* Float64
* Int16
* Int32
* Int64
* String
* Time (not a vdl primitive, but treated like primitives in syncQL)
* TypeObject
* Uint16
* Uint32
* Uint64

#### ?&lt;type&gt;

If missing, optional fields resolve to nil.

#### Composites

Any vdl composite type can be drilled into, and the result drilled into, until the result is a primitive data type.  Following are the rules for how to drill into composite types, presented as examples:

For the next few vdl.Value types, we'll be using the Composites table.  The values in the table are of type Composite, which is defined as:

    type Composite struct {
            Arr     Array2String
            ListInt []int32
            MySet   set[int32]
            Map     map[string]int32
    }

In this type:

* Arr is an array of length two and contains string elements.
* ListInt is a list of int32s.
* MySet is a set of int32s.
* Map contains string keys with int32 values.

Let's have a look at the single row in the Composites table:

    ? select k, v from Composites;
    +-----+----------------------------------------------------------------------------------+
    |   k |                                                                                v |
    +-----+----------------------------------------------------------------------------------+
    | uno | {Arr: ["foo", "bar"], ListInt: [1, 2], MySet: {1, 2}, Map: {"bar": 2, "foo": 1}} |
    +-----+----------------------------------------------------------------------------------+

#### Array and List

Array elements are specified with bracket syntax:

    ? select v.Arr[0], v.Arr[1], v.Arr[2] from Composites;
    +----------+----------+----------+
    | v.Arr[0] | v.Arr[1] | v.Arr[2] |
    +----------+----------+----------+
    | foo      | bar      |          |
    +----------+----------+----------+

The first two columns above return the elements in the array.  The third column can't be resolved as the array is of size 2.  As such, syncQL returns nil.

The index need not be a literal:

    ? select v.Arr[v.ListInt[0]] from Composites;
    +---------------------+
    | v.Arr[v.ListInt[0]] |
    +---------------------+
    | bar                 |
    +---------------------+

In the query above, the index is another field, the ListInt field.  The first element of the list contains the value 1 and v.Arr[1] contains "bar".  The index could be a function also.

As you can see, from v.ListInt[0] in the query above, lists are treated the same as arrays in syncQL - to address a single element, put the index in brackets.

By the way, syncQL will try to convert the value specified as the index into an int.  Such as in this case where a float is converted to an int.

    ? select v.ListInt[1.0] from Composites;
    +--------------+
    | v.ListInt[1] |
    +--------------+
    |            2 |
    +--------------+

If syncQL cannot convert the value to an int, nil is returned as the field cannot be resolved.  This is a hard and fast rule for fields in the select clause: if they can't be resolved, they are nil.

#### Map

Values in maps are specified by supplying a key with bracket syntax.  Note: The key need not be a literal; functions and fields work also.

    ? select v.Map["foo"] from Composites;
    +------------+
    | v.Map[foo] |
    +------------+
    |          1 |
    +------------+

#### Set

Brackets are also used for sets in syncQL.  For sets, if the value specified inside the brackets is present in the set, the field evaluates to true.  Otherwise, it evaluates to false.

Let's execute a query on MySet - an int32 set which contains the values 1 and 2:

    ? select v.MySet[-23], v.MySet[2], v.MySet[55], v.MySet["xyzzy"] from Composites;
    +--------------+------------+-------------+----------------+
    | v.MySet[-23] | v.MySet[2] | v.MySet[55] | v.MySet[xyzzy] |
    +--------------+------------+-------------+----------------+
    |        false |       true |       false |                |
    +--------------+------------+-------------+----------------+

The values -23 and 55 are not in the set; hence, the columns are false.  The value 2 is in the set; hence, true.  The value "xyzzy" cannot be converted to an int32; hence, nil is returned.

#### Struct

As we have seen earlier, structs are drilled into my specifying the name of the field in dot notation.

Let's revisit the Customer type:

    type Customer struct {
            Name    string
            Id      int64
            Active  bool
            Address AddressInfo
            Credit  CreditReport
    }

Now, let's print the `Id`, `Name` and `Active` status for Customer 1.

    ? select v.Id, v.Name, v.Active from Customers where v.Id = 1;
    +------+------------+----------+
    | v.Id |     v.Name | v.Active |
    +------+------------+----------+
    |    1 | John Smith |     true |
    +------+------------+----------+

#### Union

Dot notation is also used to drill into unions.  If a specific field in the union is specified, but is not present in the instance, nil is returned.

An example will help to explain this.  The Students table contains the Student type which contains a union:

    type ActOrSatScore union {
            ActScore uint16
            SatScore uint16
    }

    type Student struct {
            Name     string
            TestTime time.Time
            Score    ActOrSatScore
    }

Let's print the k, Name and Score columns in the Students table:

    ? select k, v.Name, v.Score from Students;
    +---+------------+----------------+
    | k |     v.Name |        v.Score |
    +---+------------+----------------+
    | 1 | John Smith | ActScore: 36   |
    | 2 | Mary Jones | SatScore: 1200 |
    +---+------------+----------------+

Student #1, John Smith has an ACT score.  Student #2, Mary Jones has an SAT score.  `sb` has pretty printed the ActOrSatScore union.

Let's print ActScore and SatScore:

    ? select k, v.Name, v.Score.ActScore, v.Score.SatScore from Students;
    +---+------------+------------------+------------------+
    | k |     v.Name | v.Score.ActScore | v.Score.SatScore |
    +---+------------+------------------+------------------+
    | 1 | John Smith |               36 |                  |
    | 2 | Mary Jones |                  | 1200             |
    +---+------------+------------------+------------------+

SatScore for John is nil.  ActScore for Mary is nil.

#### Any

Lastly, let's look at how type any is handled.  The AnythingGoes table contains the following type:

    type AnythingGoes struct {
            NameOfType string
            Anything   any
    }

The demo database contains two k/v pairs in this table.  A Customer instance and a Student instance.  Let's query for the key, the NameOfType field, the Name field (which is contained in both types), the Active field (contained in Customer) and the Score.ActScore (contained in Student's union field).

    ? select v.NameOfType, v.Anything.Name, v.Anything.Active, v.Anything.Score.ActScore from AnythingGoes;
    +--------------+-----------------+-------------------+---------------------------+
    | v.NameOfType | v.Anything.Name | v.Anything.Active | v.Anything.Score.ActScore |
    +--------------+-----------------+-------------------+---------------------------+
    | Student      | John Smith      |                   |                        36 |
    | Customer     | Bat Masterson   | true              |                           |
    +--------------+-----------------+-------------------+---------------------------+

Any fields resolve to the actual type and value for the particular instance (which could be nil).

### Functions in the Select Clause

Functions can be freely used in the select clause, including as arguments to other functions and between brackets to drill into maps, sets, arrays and lists.

#### List of Functions

##### Time Functions

* **Time(layout, value string) Time** - go's `time.Parse`, [doc](https://golang.org/pkg/time/#Parse)
* **Now() Time** - returns the current time
* **Year(time Time, Loc string) int** - Year of the time argument in location `Loc`.
* **Month(time Time, Loc string) int** - Month of the time argument in location `Loc`.
* **Day(time Time, Loc string) int** - Day of the time argument in location `Loc`.
* **Hour(time Time, Loc string) int** - Hour of the time argument in location `Loc`.
* **Minute(time Time, Loc string) int** - Minute of the time argument in location `Loc`.
* **Second(time Time, Loc string) int** - Second of the time argument in location `Loc`.
* **Nanosecond(time Time, Loc string) int** - Nanosecond of the time argument in location `Loc`.
* **Weekday(time Time, Loc string) int** - Day of the week of the time argument in location `Loc`.
* **YearDay(time Time, Loc string) int** - Day of the year of the time argument in location `Loc`.

##### String Functions

* **Atoi(s string) int** - converts `s` to an int
* **Atof(s string) int** - converts `s` to a float
* **HtmlEscape(s string) string** - go's `html.EscapeString`, [doc](https://golang.org/pkg/html/#EscapeString)
* **HtmlUnescape(s string) string** - go's `html.UnescapeString`, [doc](https://golang.org/pkg/html/#UnescapeString)
* **Lowercase(s string) string** - lowercase of `s`
* **Split(s, sep string) []string** - substrings between separator `sep`
* **Type(v vdl.Value) string** - the type of `v`
* **Uppercase(s string) string** - uppercase of `s`
* **RuneCount(s string) int** - the number of runes in `s`
* **Sprintf(fmt string, a ...vdl.Value) string** - go's `fmt.Sprintf`, [doc](https://golang.org/pkg/fmt/#Sprintf)
* **Str(v vdl.Value) string** - converts `v` to a string
* **StrCat(s ...string) string** - concatenation of `s` args
* **StrIndex(s, sep string) int** - index of `sep` in `s`, or -1 if `sep` is not present
* **StrRepeat(s string, count int) string** - `s` repeated count times
* **StrReplace(s, old, new string) string** - `s` with first instance of `old` replaced by `new`
* **StrLastIndex(s, sep string) int** - index of the last instance of `sep` in `s`, or -1
* **Trim(s string) string** - `s` with all leading and trailing whitespace removed (as defined by Unicode)
* **TrimLeft(s string) string** - `s` with all leading whitespace removed (as defined by Unicode)
* **TrimRight(s string) string** - `s` with trailing whitespace removed (as defined by Unicode)

##### Math Functions

* **Ceiling(x float) int** - least integer value greater than or equal to `x`
* **Complex(r, i float) complex** - complex value from `r` and `i`
* **Floor(x float) int** - greatest integer value less than or equal to `x`
* **IsInf(f float, sign int) bool** - true if `f` is an infinity, according to `sign`
* **IsNaN(f float) bool** - true if `f` is an IEEE 754 "not-a-number" value
* **Log(x float) float** - natural logarithm of `x`
* **Log10(x float) float** - decimal logarithm of `x`
* **Pow(x, y float) float** - `x**y`
* **Pow10(e int) float** - `10**e`
* **Mod(x, y float) float** - remainder of `x/y`
* **Real(c complex) float** - the real part of `c`
* **Truncate(x float) float** - integer value of `x`
* **Remainder(x, y float) float** - IEEE 754 floating-point remainder of `x/y`

##### Len Function

* **Len(v vdl.Value) int** - # entries in array/list/map/set, # bytes in string, 0 for nil, otherwise error

#### Function Examples

Let's use the Student table again.  Recall that it contains Student types defined as:

    type Student struct {
            Name     string
            TestTime time.Time
            Score    ActOrSatScore
    }

To print the day of the week (in PDT) that a student's tests were taken:

    ? select v.Name, Weekday(v.TestTime, "America/Los_Angeles") from Students;
    +------------+---------+
    |     v.Name | Weekday |
    +------------+---------+
    | John Smith |       3 |
    | Mary Jones |       5 |
    +------------+---------+

Three things to remember about using functions are:

1. If the function contains only literals (or other functions that can be evaluated before query execution), the function will be executed beforehand and, if an error is encountered, it will be returned to the user.
2. If any arguments are literals and the literal arguments can be checked before query execution, they are checked and an error returned to the user.
3. If the error can't be found before query execution-that is, if the error occurs when evaluating a specific k/v pair, the column evaluates to nil (the same as always for the select clause).

An example of case #1 above is the Now() function.

Examples of case #2 are the many functions that contain a location argument.  This argument is often a literal.  Here's an example of getting the location wrong and getting an error before query execution:

? select v.Name, Weekday(v.TestTime, "MyPlace") from Students;
    Error:
    select v.Name, Weekday(v.TestTime, "MyPlace") from Students
                                       ^
    36: Can't convert to location: cannot find MyPlace in zip file /usr/local/go/lib/time/zoneinfo.zip.

### As

There just one more thing to say about the select clause.  Sometimes you might want the column heading to be prettier than what is returned by default.  This can be accomplished by using As.  Let's try using it.

    ? select v.Name as Name from Customers where Type(v) like "%Customer";
    +---------------+
    |          Name |
    +---------------+
    | John Smith    |
    | Bat Masterson |
    +---------------+

Instead of a column header of v.Name, the column is labeled Name.

## From Clause

The from clause must follow the where clause.  There's not much to this clause.  Just pick the table.  If you get it wrong (or if you don't have access to the table), you will get an error before query execution.

    ? select k from Cust;
    Error:
    select k from Cust
                  ^
    15: Table Cust does not exist (or cannot be accessed): syncbased:"demoapp/demodb".Exec: Does not exist: $table:Cust.
    ? select k from Customers;
    +--------+
    |      k |
    +--------+
    | 001    |
    | 001001 |
    | 001002 |
    | 001003 |
    | 002    |
    | 002001 |
    | 002002 |
    | 002003 |
    | 002004 |
    +--------+

## Where Clause

The where clause is optional and is used to filter the k/v pairs in a table.  If the where clause evaluates to true for any given k/v pair, the pair is included in the results.

We've already seen the where clause in action to limit the pairs returned in the Customers table to just those of type Customer:

    ? select k, v.Name from Customers where Type(v) like "%Customer";
    +-----+---------------+
    |   k |        v.Name |
    +-----+---------------+
    | 001 | John Smith    |
    | 002 | Bat Masterson |
    +-----+---------------+

For the two k/v pairs in the Customers table that contain a value of type Customer, the where clause returns true.

In the query above, `Type(v) like "%Customer"` is a *comparison expression*.  The where clause may contain multiple comparison expressions separated by 'and' or 'or' to form logical expressions.  Furthermore, logical expressions may be grouped for precedence with parenthesis.

Let' try another query with a logical expression grouped with parenthesis:

    ? select v.InvoiceNum, v.Amount from Customers where Type(v) like "%Invoice" and (v.Amount = 7 or v.Amount = 787);
    +--------------+----------+
    | v.InvoiceNum | v.Amount |
    +--------------+----------+
    |         1003 |        7 |
    |         1004 |      787 |
    +--------------+----------+

### Comparison Expressions

Comparison expressions are of the form:

    <left-operand> <operator> <right-operand>

There's good news!  Everything (Note: OK, not everything.  Using 'As' doesn't make sense and can't be used in the where clause.) you've learned about what can be specified in the select clause can be specified as an operand in the where clause.

Having said that, there is one important difference regarding fields that cannot be resolved.  In the select clause, unresolved fields return nil.  **_In the where clause, unresolved fields cause the comparison expression to be false._**

To illustrate this point, let's do the following query:

    ? select v.InvoiceNum, v.Amount from Customers where v.Amount <> 787;
    +--------------+----------+
    | v.InvoiceNum | v.Amount |
    +--------------+----------+
    |         1000 |       42 |
    |         1003 |        7 |
    |         1005 |       88 |
    |         1001 |      166 |
    |         1002 |      243 |
    |         1006 |       88 |
    +--------------+----------+

The above query doesn't print invoice number 1004, which is for the amount 787; but it also doesn't print the Customer records (which would have nil for InvoiceNum and Amount) because the comparison expression evaluates to false.  It evaluates to false because v.Amount cannot be resolved for Customer types.

Let's try another query to bring home the point.  Let's match customer name with a wildcard expression that will match anything:

    ? select v.Name from Customers where v.Name like "%";
    +---------------+
    |        v.Name |
    +---------------+
    | John Smith    |
    | Bat Masterson |
    +---------------+

The above is a backhanded way limit the query to just Customer types.  Any name will do with the like "%" expression, but v.Name can't be resolved for values of type Invoice; thus, the comparision expression evaluates to false.

#### Operators

The following operators are available in syncQL:

<table>
  <tr>
    <td>=</td>
    <td>!=</td>
    <td>&lt;</td>
    <td>&lt;=</td>
    <td>&gt;</td>
  </tr>
  <tr>
    <td>&gt;=</td>
    <td>is</td>
    <td>is not</td>
    <td>like</td>
    <td>not like</td>
  </tr>
</table>

The `is` and `like` operators deserve explanations.

##### Is/Is Not

The `is` and `is not` operators are used to test against nil. They can be used to test for nil and are the exception to the otherwise hard and fast rule that operands that can't be resolved result in the comparison expression returning false.

A backhanded way to select only invoice values is to select values where v.Name is nil.  Invoice doesn't have a Name field, so Invoice values will be returned.

? select v.InvoiceNum from Customers where v.Name is nil;

    +--------------+
    | v.InvoiceNum |
    +--------------+
    |         1000 |
    |         1003 |
    |         1005 |
    |         1001 |
    |         1002 |
    |         1004 |
    |         1006 |
    +--------------+

One could also use the query:

    ? select v.InvoiceNum from Customers where v.InvoiceNum is not nil;
    +--------------+
    | v.InvoiceNum |
    +--------------+
    |         1000 |
    |         1003 |
    |         1005 |
    |         1001 |
    |         1002 |
    |         1004 |
    |         1006 |
    +--------------+

Important: Field Contains Nil vs. Field Cannot be Resolved

SyncQL makes no distinction between a field with a nil value vs. a field that cannot be resolved.  As such, the first "backhanded" query above wouldn't work if the Name field could be nil in values of type Customer.  Ditto for the second query-it wouldn't work if InvoiceNum could be nil in an Invoice.

##### Like/Not Like

Like and not like require the right-hand-side operand to evaluate to a string.  The rhs operand may contain zero or more of the following wildcard characters:

* % - A substitute for zero or more characters
* _ - A substitute for a single character

Let's find invoices where the ship to address is any house on Main St.

    ? select v.InvoiceNum, v.ShipTo.Street from Customers where Type(v) like "%Invoice" and v.ShipTo.Street like "%Main St.";
    +--------------+-----------------+
    | v.InvoiceNum | v.ShipTo.Street |
    +--------------+-----------------+
    |         1000 | 1 Main St.      |
    |         1003 | 2 Main St.      |
    |         1005 | 3 Main St.      |
    +--------------+-----------------+

Just one more thing. To escape a '%' or '_' wildcard character, the escape clause must be included in the query to specify an escape character to use.  For example, to find all customers whose name includes an underscore character, one can write the following (using the '^' character to escape the underscore).  Note: The backslash and space characters cannot be used as the escape character.

    ? select v.Id, v.Name from Customers where Type(v) like "%Customer" and v.Name like "%^_%" escape '^';
    +------+------------+
    | v.Id |     v.Name |
    +------+------------+
    +------+------------+

Alas, there are no customers with an underscore in their name.  We can cheat by using a literal on the left hand side of the like.
    ? select v.Id, v.Name from Customers where Type(v) like "%Customer" and "John_Doe" like "%^_%" escape '^';
    +------+---------------+
    | v.Id |        v.Name |
    +------+---------------+
    |    1 | John Smith    |
    |    2 | Bat Masterson |
    +------+---------------+
Since the like expression is now true for all customer rows, we see both of them.

Let's do the same thing to look for a percent.
    ? select v.Id, v.Name from Customers where Type(v) like "%Customer" and "John%Doe" like "%^%%" escape '^';
    +------+---------------+
    | v.Id |        v.Name |
    +------+---------------+
    |    1 | John Smith    |
    |    2 | Bat Masterson |
    +------+---------------+

#### Operand Value Coercion

SyncQL will try to convert operands on either side of comparison expression to like types in order to perform a comparison.

For example, let's find the customer with an `Id` of 1 (an int64 value); but use a float in the comparison.  SyncQL converts `v.Id` to a float and then compares it against the 1.0 float literal.

    ? select v.Id, v.Name from Customers where Type(v) like "%Customer" and v.Id = 1.0;
    +------+------------+
    | v.Id |     v.Name |
    +------+------------+
    |    1 | John Smith |
    +------+------------+

Congratulations, you are finished with the where clause (and nearing the end of the tutorial)!

## Offset and Limit Clauses

The limit clause can be used to fetch the first n results.  The limit clause together with the offset clause can be used to fetch query results in batches.

Let's print the first two keys in the Customers table:

    ? select k from Customers limit 2;
    +--------+
    |      k |
    +--------+
    | 001    |
    | 001001 |
    +--------+

Now, let's fetch the next two keys:

    ? select k from Customers limit 2 offset 2;
    +--------+
    |      k |
    +--------+
    | 001002 |
    | 001003 |
    +--------+

## Executing Delete Statements

In addition to select statements, syncql supports delete statements.  (Insert and Update statements are planned.)

The delete statement takes the form:

    delete from <table> [<where-clause>] [<limit-clause>]

The where and limit clauses for delete are identical to the where and limit caluses for select.

To delete all k/v pairs in a table, leave off the where and limit clauses:

    ? delete from Customers;
    +-------+
    | Count |
    +-------+
    |     9 |
    +-------+

Exactly one row with exactly one "Count" column is always returned from an execution of the delete statement.  The value of the column is the number of k/v paris deleted.  In this case, all nine k/v pairs in the Customers table have been deleted.  To verify this, select all entries in the Customers table:

    ? select k from Customers;
    +---+
    | k |
    +---+
    +---+

Let's restore the entries by executing make-demo again.
    ? make-demo;
    Demo tables created and populated.

Now, let's use the where clause to delete only invoice entries:
? delete from Customers where Type(v) like "%.Invoice";

    +-------+
    | Count |
    +-------+
    |     7 |
    +-------+

The seven invoice entries have been deleted.  A select reveals the delete indeed deleted what we expected.

    ? select k, Type(v) from Customers;
    +-----+--------------------------------------------+
    |   k |                                       Type |
    +-----+--------------------------------------------+
    | 001 | v.io/x/ref/cmd/sb/internal/demodb.Customer |
    | 002 | v.io/x/ref/cmd/sb/internal/demodb.Customer |
    +-----+--------------------------------------------+

Lastly, let's delete all Customers where the address is not Palo Alto:

    ? delete from Customers where v.Address.City <> "Palo Alto";
    +-------+
    | Count |
    +-------+
    |     1 |
    +-------+

Since customer 001, John Smith, is in Palo Alto, the delete statement did not delete him. A select reveals Bat Masteson, who resides in Collins, IA, was indeed deleted.

    ? select k from Customers;
    +-----+
    |   k |
    +-----+
    | 001 |
    +-----+

Let's restore the tables before we try the limit clause on a delete:

    ? make-demo;
    Demo tables created and populated.

Now, let's delete Invoice entries again, but put a limit of two on the statement:

    ? delete from Customers where Type(v) like "%.Invoice" limit 2;
    +-------+
    | Count |
    +-------+
    |     2 |
    +-------+

A select reveals only the first two invoices (in ascending key order) have been deleted ("001001" and "001002"):

    ? select k from Customers;
    +--------+
    |      k |
    +--------+
    | 001    |
    | 001003 |
    | 002    |
    | 002001 |
    | 002002 |
    | 002003 |
    | 002004 |
    +--------+

Congratulations!  You've finished the syncQL tutorial.  Don't forget to proceed to the [teardown](#teardown) steps to clean up!  Also, check out the brief introduction to executing syncQL queries from a Go program.

# Teardown

Exit `sb` with &lt;ctrl-d&gt;, kill the syncbased and mounttabled background jobs and delete the principal directory:

    <ctrl-d>
    sudo kill $(jobs -p)
    rm -rf /tmp/me

# Executing SyncQL from a Go Program

When using Syncbase's Get() and Put() functions, the programmer can often ignore the fact that keys and values are stored as type vdl.Value; but this is not true when making syncQL queries as returned columns are always of type vdl.Value.  For example, given the following query:

    select k, v.Id, v.Address.Zip from Customers where Type(v) like \"%Customer\"

a triple of vdl.Values will be returned for each k/v pair in the Customer table.  The caller could interrogate the vdl.Value as to the actual types stored inside, but usually the caller will know the types.  As such, the calling code will just need to call the String() functions for the first and third columns and the Int() function for the second column.

The following code snippet might help to clarify the above:

    q := "select k, v.Id, v.Address.Zip from Customers where Type(v) like \"%Customer\""
    h, rs, err := db.Exec(ctx, q)
    if err != nil {
      fmt.Printf("Error: %v\n", err)
    } else {
      // Print Headers
      fmt.Printf("%30.30s,%8.8s, %5.5s\n", h[0], h[1], h[2])
      for rs.Advance() {
        c := rs.Result()
        fmt.Printf("%s30.30 %8.8d %5.5s\n", c[0], c[1], c[2])
      }
      if rs.Error() {
        fmt.Printf("Error: %v\n", err)
      }
    }

One will need to take the Syncbase tutorial before attempting to execute syncQL queries in a Go program; but once you are comfortable with Syncbase, the Exec function is straightforward.  Exec can be performed on the database object or from a readonly or writable batch object.

Exec simply takes a context and the syncQL query (don't end it with a semicolon).  If successful, an array of column headers will be returned along with a stream of vdl.Value tuples.  Iteration over the stream will be familiar to Vanadium developers.
