# Pattern Matching

- Document number: ?
- Date: 2017-06-14
- Reply-to: David Sankel &lt;dsankel@bloomberg.net&gt;, Michael Park &lt;mcypark@gmail.com&gt;
- Audience: Evolution

## Abstract
Pattern matching improves code readability and fills a hole in C++, the
convenient deconstruction of types based on inheritance. This paper proposes a
syntax that extends C++ with an `inspect` keyword that can be used for various
pattern-matching use-cases. This is one of the three key pieces of of the
language-variant/pattern-matching design paper
([P0095](http://wg21.link/p0095)): language variant, pattern matching, and
related extension mechanisms.

<!-- TODO: insert a nice example here -->

## Before/After Comparisons

<figure>
<figcaption>Figure ?: Switching an enum.</figcaption>
<table border="1">
<tr>
  <th>before</th>
  <th>after</th>
</tr>
<tr>
<td colspan="2">
```c++
enum color { red, yellow, green, blue };
```
</td>
</tr>
<td valign="top">
```c++
const Vec3 opengl_color = [&c] {
  switch(c) {
    case red:
      return Vec3(1.0, 0.0, 0.0);
      break;
    case yellow:
      return Vec3(1.0, 1.0, 0.0);
      break;
    case green:
      return Vec3(0.0, 1.0, 0.0);
      break;
    case blue:
      return Vec3(0.0, 0.0, 1.0);
      break;
    default:
      std::abort();
  }();
```
</td>
<td valign="top">
```c++
const Vec3 opengl_color =
  inspect(c) {
    red    => Vec3(1.0, 0.0, 0.0)
    yellow => Vec3(1.0, 1.0, 0.0)
    green  => Vec3(0.0, 1.0, 0.0)
    blue   => Vec3(0.0, 0.0, 1.0)
  };
```
</td>
</tr>
</table>
</figure>

<figure>
<figcaption>Figure ?: `struct` inspection</figcaption>
<table border="1">
<tr>
  <th>before</th>
  <th>after</th>
</tr>
<tr>
<td colspan="2">
```c++
struct player {
  std::string name;
  int hitpoints;
  int lives;
};
```
</td>
</tr>
<td valign="top">
```c++
void takeDamage(player &p) {
  if(p.hitpoints == 0 && p.lives == 0)
    gameOver();
  else if(p.hitpoints == 0) {
    p.hitpoints = 10;
    p.lives--;
  }
  else if(p.hitpoints <= 3) {
    p.hitpoints--;
    messageAlmostDead();
  }
  else {
    p.hitpoints--;
  }
}
```
</td>
<td valign="top">
```c++
void takeDamage(player &p) {
  inspect(p) {
    {hitpoints:   0, lives:0}   => gameOver();
    {hitpoints:hp@0, lives:l}   => hp=10, l--;
    {hitpoints:hp} if (hp <= 3) => { hp--; messageAlmostDead(); }
    {hitpoints:hp} => hp--;
  }
}
```
</td>
</tr>
</table>
</figure>

## Introduction

<!-- TODO -->

## Pattern Matching With `inspect`

Pattern matching goes far beyond `lvariant`s. This section overviews the
proposed pattern matching syntax and how it applies to all types.

Lets define some useful terms for discussing pattern matching and variants in
C++. We use the word "piece" to denote a field in a `struct`. The word
"alternative" is used for `lvariant` fields.  The programming language theory
savvy will also recognize `lvariant`s to be
[sum types](https://en.wikipedia.org/wiki/Tagged_union) and simple `struct`s to
be [product types](https://en.wikipedia.org/wiki/Product_type), although we
won't use that jargon here.

### Pattern matching integrals and enums
The most basic pattern matching is that of integral (ie. `int`, `long`, `char`,
etc.) and `enum` types, and that is the subject of this section. Before we get
there, however, we need to distinguish between the two places pattern matching
can occur. The first is in the statement context. This context is most useful
when the intent of the pattern is to produce some kind of action. The `if`
statement, for example, is used in this way. The second place pattern matching
can occur is is in an expression context. Here the intent of the pattern is to
produce a value of some sort. The trinary operator `?:`, for example, is used
in this context. Upcoming examples will help clarify the distinction.

The context is distinguished by whether or not the cases consist of a statement
(ends in a semicolon or is wrapped in curly braces) or an expression.

In the following example, we're using `inspect` as a statement to check for
certain values of an int `i`:

```c++
inspect(i) {
  0 =>
    std::cout << "I can't say I'm positive or negative on this syntax."
              << std::endl;
  6 =>
    std::cout << "Perfect!" << std::endl;
  _ =>
    std::cout << "I don't know what to do with this." << std::endl;
}
```

The `_` character is the pattern which always succeeds. It represents a
wildcard or fallthrough. The above code is equivalent to the following `switch`
statement.

```c++
switch(i) {
  case 0:
    std::cout << "I can't say I'm positive or negative on this syntax."
              << std::endl;
    break;
  case 6:
    std::cout << "Perfect!" << std::endl;
    break;
  default:
    std::cout << "I don't know what to do with this." << std::endl;
}
```

`inspect` can be used to pattern match within expression contexts as in the
following example. `c` is an instance of the `color` `enum`:

```c++
enum color { red, yellow, green, blue };

// elsewhere...

const Vec3 opengl_color = inspect(c) {
                            red    => Vec3(1.0, 0.0, 0.0)
                            yellow => Vec3(1.0, 1.0, 0.0)
                            green  => Vec3(0.0, 1.0, 0.0)
                            blue   => Vec3(0.0, 0.0, 1.0)
                          };
```

Note that the cases do not end in a semicolon.

It is also important to note that if an `inspect` expression does not have a
matching pattern, an `std::no_match` exception is thrown. This differs from
`inspect` statements which simply move on to the next statement if no pattern
matches.

All we've seen so far is a condensed and safer `switch` syntax which can also
be used in expressions. Pattern matching's real power comes when we use more
complex patterns. We'll see some of that below.

### Pattern matching structs

Pattern matching `struct`s in isolation isn't all that interesting: they merely
bind new identifiers to each of the fields.

```c++
struct player {
  std::string name;
  int hitpoints;
  int coins;
};
```

```c++
void log_player( const player & p ) {
  inspect(p) {
    {n,h,c}
      => std::cout << n << " has " << h << " hitpoints and " << c << " coins.";
  }
}
```

`n`, `h`, and `c` are "bound" to their underlying values in a similar way to
structured bindings. See
[P0217R1](http://open-std.org/JTC1/SC22/WG21/docs/papers/2016/p0217r1.html) for
more information on what it means to bind a value.

`struct` patterns aren't limited to binding new identifiers though. We can
instead use a nested pattern as in the following example.

```c++
void get_hint( const player & p ) {
  inspect( p ) {
    {_, 1, _} => std::cout << "You're almost destroyed. Give up!" << std::endl;
    {_,10,10} => std::cout << "I need the hints from you!" << std::endl;
    {_, _,10} => std::cout << "Get more hitpoints!" << std::endl;
    {_,10, _} => std::cout << "Get more ammo!" << std::endl;
    {n, _, _} => if( n != "The Bruce Dickenson" )
                   std::cout << "Get more hitpoints and ammo!" << std::endl;
                 else
                   std::cout << "More cowbell!" << std::endl;
  }
}
```

While the above code is certainly condensed, it lacks clarity. It is tedious to
remember the ordering of a `struct`'s fields. Not all is lost, though;
Alternatively we can match using field names.

```c++
void get_hint( const player & p ) {
  inspect(p) {

    {hitpoints:1}
      => std::cout << "You're almost destroyed. Give up!" << std::endl;

    {hitpoints:10, coins:10}
      => std::cout << "I need the hints from you!" << std::endl;

    {coins:10}
      => std::cout << "Get more hitpoints!" << std::endl;

    {hitpoints:10}
      => std::cout << "Get more ammo!" << std::endl;

    {name:n}
      => if( n != "The Bruce Dickenson" )
           std::cout << "Get more hitpoints and ammo!" << std::endl;
         else
           std::cout << "More cowbell!" << std::endl;
  }
}
```

Finally, our patterns can incorporate guards through use if an if clause. The
last pattern in the above function can be replaced with the following two
patterns:

```c++
{name:n} if( n == "The Bruce Dickenson" ) => std::cout << "More cowbell!" << std::endl;
_ => std::cout << "Get more hitpoints and ammo!" << std::endl;
```

### Pattern matching `lvariant`s

Pattern matching is the easiest way to work with `lvariant`s. Consider the
following binary tree with `int` leaves.

```c++
lvariant tree {
  int leaf;
  std::pair< std::unique_ptr<tree>, std::unique_ptr<tree> > branch;
}
```

Say we need to write a function which returns the sum of a `tree` object's leaf
values. Variant patterns are just what we need. A pattern which matches an
alternative consists of the alternative's name followed by a pattern for its
associated value.

```c++
int sum_of_leaves( const tree & t ) {
  return inspect( t ) {
           leaf i => i
           branch b => sum_of_leaves(*b.first) + sum_of_leaves(*b.second)
         };
}
```

Assuming we can pattern match on the `std::pair` type, which we'll discuss later,
this could be rewritten as follows.

```c++
int sum_of_leaves( const tree & t ) {
  return inspect( t ) {
           leaf i => i
           branch {left, right} => sum_of_leaves(*left) + sum_of_leaves(*right)
         };
}
```

### More complex datatypes

Pattern matching can make difficult code more readable and maintainable. This
is especially true with complex patterns. Consider the following arithmetic
expression datatype:

```c++
// An lvariant (forward) declaration.
lvariant expression;

struct sum_expression {
  std::unique_ptr<expression> left_hand_side;
  std::unique_ptr<expression> right_hand_side;
};

lvariant expression {
  sum_expression sum;
  int literal;
  std::string var;
};
```

We'd like to write a function which simplifies expressions by exploiting `exp +
0 = 0` and `0 + exp = 0` identities. Here is how that function can be written
with pattern matching.

```c++
// The behavior is undefined unless `exp` has no null pointers.
expression simplify( const expression & exp ) {
  return inspect( exp ) {
           sum {*(literal 0),         *rhs} => simplify(rhs)
           sum {*lhs        , *(literal 0)} => simplify(lhs)
           _ => exp
         };
}
```

Here we've introduced a new `*` keyword into our patterns. `*<pattern>`
matches against types which have a valid dereferencing operator and uses
`<pattern>` on the value pointed to (as opposed to matching on the pointer
itself). A special dereferencing pattern syntax may seem strange for folks
coming from a functional language. However, when we take into account that C++
uses pointers for all recursive structures it makes a lot of sense. Without it,
the above pattern would be much more complicated.

## Wording Skeleton

What follows is an incomplete wording for inspection presented for the sake of
discussion.

### Inspect Statement

*inspect-statement*:<br>
&emsp;`inspect` `(` *expression* `)` `{` *inspect-statement-cases<sub>opt</sub>* `}`

*inspect-statement-cases*:<br>
&emsp;*inspect-statement-case* *inspect-statement-cases<sub>opt</sub>*

*inspect-statement-case*:<br>
&emsp;*guarded-inspect-pattern* `=>` *statement*

The identifiers in *inspect-pattern* are available in *statement*.

In the case that none of the patterns match the value, execution continues.

### Inspect Expression

*inspect-expression*:<br>
&emsp;`inspect` `(` *expression* `)` `{` *inspect-expression-cases<sub>opt</sub>* `}`

*inspect-expression-cases*:<br>
&emsp;*inspect-expression-case* *inspect-expression-cases<sub>opt</sub>*

*inspect-expression-case*:<br>
&emsp;*guarded-inspect-pattern* `=>` *expression*

The identifiers in *inspect-pattern* are available in *expression*.

In the case that none of the patterns match the value, a `std::no_match`
exception is thrown.

### Inspect Pattern

*guarded-inspect-pattern*:<br>
&emsp;*inspect-pattern* *guard<sub>opt</sub>*

*guard*:<br>
&emsp;`if` `(` *condition* `)`

*inspect-pattern*:<br>
&emsp;`_`<br>
&emsp;`nullptr`<br>
&emsp;`*` *inspect-pattern* <br>
&emsp;`(` *inspect-pattern* `)`<br>
&emsp;*identifier* ( `@` `(` *inspect-pattern* `)` )<sub>opt</sub><br>
&emsp;*alternative-selector* *inspect-pattern*
&emsp;*constant-expression*
&emsp;`{` *tuple-like-patterns<sub>opt</sub>* `}`

#### Wildcard pattern
*inspect-pattern*:<br>
&emsp;`_`<br>

The wildcard pattern matches any value and always succeeds.

#### `nullptr` pattern
*inspect-pattern*:<br>
&emsp;`nullptr`<br>

The `nullptr` pattern matches values `v` where `v == nullptr`.

#### Dereference pattern
*inspect-pattern*:<br>
&emsp;`*` *inspect-pattern* <br>

The dereferencing pattern matches values `v` where `v != nullptr` and where `*v`
matches the nested pattern.

#### Parenthesis pattern
*inspect-pattern*:<br>
&emsp;`(` *inspect-pattern* `)`<br>

The dereferencing pattern matches *inspect-pattern* and exists for disambiguation.

#### Binding pattern
*inspect-pattern*:<br>
&emsp;*identifier* ( `@` `(` *inspect-pattern* `)` )<sub>opt</sub><br>

If `@` is not used, the binding pattern matches all values and binds the
specified identifier to the value being matched. If `@` is used, the pattern is
matched only if the nested pattern matches the value being matched.

#### Alternative pattern

*inspect-pattern*:<br>
&emsp;*alternative-selector* *inspect-pattern*

*alternative-selector*:<br>
&emsp;*constant-expression*<br>
&emsp;*identifier*<br>

The alternative pattern matches against `lvariant` values and objects which
overload the `discriminator` and `alternative` operators. The pattern matches
if the value has the appropriate discriminator value and the nested pattern
matches the selected alternative.

The *constant-expression* shall be a converted constant expression (5.20) of
the type of the inspect condition's discriminator. The *identifier* will
correspond to a field name if inspect's condition is an `lvariant` or an
identifier that is within scope of the class definition opting into the
alternative pattern.

#### Integral-enum pattern
*inspect-pattern*:<br>
&emsp;*constant-expression*

The integral-enum pattern matches against integral and enum types. The pattern
is valid if the matched type is the same as the *constant-expression* type. The
pattern matches if the matched value is the same as the *constant-expression*
value.

#### Tuple-like patterns
*inspect-pattern*:<br>
&emsp;`{` *tuple-like-patterns<sub>opt</sub>* `}`

*tuple-like-patterns*:<br>
&emsp;*sequenced-patterns*<br>
&emsp;*field-patterns*

*sequenced-patterns*:<br>
&emsp;*inspect-pattern* (`,` *sequenced-patterns*)<sub>opt</sub>

*field-patterns*:<br>
&emsp;*field-pattern* (`,` *field-patterns*)<sub>opt</sub>

*field-pattern*:<br>
&emsp;*piece-selector* `:` *inspect-pattern*

*piece-selector*:<br>
&emsp;*constant-expression*<br>
&emsp;*identifier*

Tuple-like patterns come in two varieties: a sequence of patterns and field
patterns.

A sequenced pattern is valid if the following conditions are true:

1. The matched type is either a `class` with all public member variables or has
   a valid extract operator. Say the number of variables or arguments to
   extract is `n`.
2. There are exactly `n` patterns in the sequence.
3. Each of the sequenced patterns is valid for the corresponding piece in
   the matched value.


A field pattern is valid if the following conditions are true:
1. The matched type is either a `class` with all public member variables or has
   a valid extract operator.
2. *piece-selector*s, if they are *constant-expression*, must have the same
   type as the extract operator's `std::tuple_piece`s second template argument.
3. *piece-selector*s, if they are *identifier*s, must correspond to field names
   in the `class` with all public member variables.
4. Each of the field patterns is valid for the the corresponding piece in
   the matched value.

Both patterns match if the pattern for each piece matches its corresponding
piece.

The *constant-expression* shall be a converted constant expression (5.20) of
the type of the inspect condition's extract piece discriminator. The
*identifier* will correspond to a field name if inspect's condition is an
class or an identifier that is within scope of the class definition opting
into the tuple-like pattern.

## Design Choices

### `inspect` as a statement and an expression
If `inspect` were a statement-only, it could be used in expressions via. a
lambda function. For example:

```c++
const Vec3 opengl_color = [&c]{
  inspect(c) {
    red    => return Vec3(1.0, 0.0, 0.0)
    yellow => return Vec3(1.0, 1.0, 0.0)
    green  => return Vec3(0.0, 1.0, 0.0)
    blue   => return Vec3(0.0, 0.0, 1.0)
  } }();
```

Because we expect that `inspect` expressions will be the most common use case,
we feel the syntactic overhead and tie-in to another complex feature (lambdas)
too much to ask from users.

### `inspect` with multiple arguments
It is a straightforward extension of the above syntax to allow for inspecting
multiple values at the same time.

```c++
lvariant tree {
  int leaf;
  std::pair< std::unique_ptr<tree>, std::unique_ptr<tree> > branch;
}

bool sameStructure(const tree& lhs, const tree& rhs) {
  return inspect(lhs, rhs) {
           {leaf _, leaf _} => true
           {branch {*lhs_left, *lhs_right}, branch {*rhs_left, *rhs_right}}
             =>    sameStructure(lhs_left , rhs_left)
                && samestructure(lhs_right, rhs_right)
           _ => false
         };
}
```

It is our intent that the final wording will allow for such constructions.

### Special operator extension mechanism

The committee has discussed several mechanisms that enable user-defined
tuple-like types to opt-in to language features. This is discussed at length in
P0326R0 and P0327R0. We present the `extract`, `discriminator`, and
`alternative` operators as one such option, but we fully expect that only one
mechanism should be ultimately available in the standard.

### [] or {} for tuple-like access

We use curly braces to extract pieces from tuple-like objects because it
closely resembles curly brace initialization of tuple-like objects. There has
been some discussion as to whether square brackets are a more appropriate
choice for structured binding due to ambiguity issues.

Although our preference is curly braces, we believe that whatever is ultimately
decided for structured binding should be mimicked here for consistency.

## Conclusion

We conclude that types-as-tags are for astronauts, but variants are for
everyone. None of the library implementations thus far proposed are easy enough
to be used by beginners; a language feature is necessary. In the author's
opinion a library-based variant should complement a language-based variant, but
not replace it. And with language-based variants comes pattern matching,
another highly desirable feature in the language.

## Acknowledgements

Thanks to Vicente Botet Escrib&aacute;, John Skaller, Dave Abrahams, Bjarne
Stroustrup, Bengt Gustafsson, and the C++ committee as a whole for productive
design discussions.  Also, Yuriy Solodkyy, Gabriel Dos Reis, and Bjarne
Stroustrup's prior research into generalized pattern matching as a C++ library
has been very helpful.

## References

* V. Botet Escrib&aacute;. Product types access. P0327R0. WG21
* V. Botet Escrib&aacute;. Structured binding: customization points issues. P0326R0. WG21
* A. Naumann. Variant: a type-safe union for C++17 (v7). [P088R2](http://open-std.org/JTC1/SC22/WG21/docs/papers/2016/p0088r2.html). WG21.
* D. Sankel. [C++ Langauge Support for Pattern Matching and Variants](http://davidsankel.com/uncategorized/c-language-support-for-pattern-matching-and-variants/). davidsankel.com.
* Y. Solodkyy, G. Dos Reis, B. Stroustrup. [Open Pattern Matching for C++](http://www.stroustrup.com/OpenPatternMatching.pdf). GPCE 2013.
* H. Sutter, B. Stroustrup, G. Dos Reis. Structured bindings. [P0144R2](http://open-std.org/JTC1/SC22/WG21/docs/papers/2016/p0144r2.pdf). WG21.

[^jacksonville_variant]: Variant: a type-safe union for C++17 (v7). [P0088R2](http://www.open-std.org/JTC1/SC22/WG21/docs/papers/2016/p0088r2.html)
