---
layout: draft
title: Comparing Scala and F#
date: 2016-05-27
tags: ["F#", "Scala", "Functional programming"]
---

F# and Scala are quite similar languages from 10.000 feet view. Both are
functional-first languages developed for the virtual machines where imperative
languages dominate. C# for .NET and Java for JVM are still the most popular
languages, but alternatives are getting stronger.

My background is in .NET ecosystem, so F# was the first of the two that I started
learning. At the same time, Scala seems to have more traction, langely due to
successful products and frameworks like Spark, Akka and Play. That's why I decided
to broaden my skillset and pick up some Scala knowledge. I've started with 
[Functional Programming in Scala Specialization](https://www.coursera.org/specializations/scala) at Coursera.
While following the coursera, I'm doing some notes about which language features
in Scala I find interesting, or vice versa - missing compared to F#.

In no particular order, I want to share my notes in this blog post.

Implicit Parameters
-------------------

A function parameter can be marked as implicit

``` scala
def p(implicit i:Int) = print(i)
```

and that means you can call the function without specifying the value for this parameter
and the compiler will try to figure out the value of parameter for you (according to
the extensive set of rules), e.g.

``` scala
implicit val v = 2;
// ... somewhere below
p // prints '2'
```

I'm not aware of this feature in any other language that I know, so I'm pretty sure
I don't understand it well enough yet :) At the same time, I think implicits are
very characteristic for Scala: they are a powerful tool, which can be used in many
valid scenarios, or can be abused to shoot in your feet.

Underscore In Lambdas
---------------------

Underscores can be used to represent the parameters in lambda expressions
without explicitly naming them:

``` scala
employees.sortBy(_.dateOfBirth)
```

I think that's brilliant - very short and readable. Tuple values are represented
by `_1` and `_2`, so we can sort an array of tuples like

``` scala
profitByYear.sortBy(_._1)
```

This looks a bit hairy and should probably be used only when the meaning is obvious
(in the example above I'm not sure if we sort by year or by profit...).

In F# underscore is used in a different sense - as "something to ignore". That makes
sense, but I would love to have a shorter way to write lambda in

``` fs
empoyees |> List.sort (fun e -> e.dateOfBirth)
```

Any hint how?

Pattern Matching Anonymous Functions
------------------------------------

That's a very similar feature: a way to reduce the boilerplace while writing
lambda functions. Instead of naming parameters and typing ` => x match` you
can just start matching immediately

``` scala
val b = List(1, 2)
b map({case 1 => "one"
       case 2 => "two"})
```

Kudos!

Tail-Recursion Mark
-------------------

Any recursive function in Scala can be marked with `@tailrec` annotation,
which would result in compilation error if the function is not tail-recursive.
This guarantees that you won't get a nasty stack overflow exception. This feature
sounds very reasonable, although I must admit that I have never needed it in *my* 
F# code yet.

Lack of Type Inference
----------------------

Slowly moving towards language design flavours, I'll start with Type Inference.
Well, unfortunetely Scala barely has any type inference. Yes, you don't have to
explicitly define the types of local values or (most of the time) function return
types, but that's about it.

You have to specify the types of all input parameters, and that's quite a bummer
for people who are used to short type-less code of F# (or Haskell, OCaml etc, for
that matter).

Functional vs Object-Oriented Style
-----------------------------------

Both F# and Scala are running on top of managed object-oriented virtual machines,
and at the same time both languages enable developers to write functional code.
Functional programming means operating immutable data strtuctures in pure, free of
side effects, operations. Without questioning all this, I find functional pure
Scala code to be written in much more object-oriented *style* compared to F#:

Classes and objects are ubiquitous in Scala: they are in each example given 
in Martin Odersky's courses. Most F# examples refrain from classes unless needed.
F# official guidance is to never expose non-abstract classes from F# API!

Scala is really heavy about inheritance. They even introduced multiple inheritance,
traits, `Seq` inherits from `List`, and `Nothing` is a subtype of every other type, 
to be used for some covariance tricks.

Operations are usually defined as class methods instead of separate functions. For
example the following Scala code

``` scala
word filter (c => c.isLetter)
```

would filter a string to letters only. Why is `isLetter` defined as a method of 
`Char`? I don't think it's essential for the type itself...

operator use

partial application

object vs object expression

single-direction dependency