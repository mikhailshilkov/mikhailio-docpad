---
layout: draft
title: TDD: the bad parts
date: 2016-02-04
tags: []
teaser: 
---

About a year ago we (the host team) agreed to use TDD for the new code that we develop.
Since then, we have a constant debate between TDD adopters (Bjorn still being
the only consistent adopter) and everyone else, who use TDD from "sometimes" to
"never". Nobody benefits from this status-quo, so I want to discuss it one
more time. Here is my point of view.

What and why 
------------

TDD is Test-Driven Development - a technique when a developers starts with
tests before writing any line of code.

Here are the three reasons why I voted for TDD adoption:
- To create the automated test suit which would work to prevent the regression
bugs in existing code base when changes are introduced
- To improve the design of the codebase - to force the SOLID principles,
small classes and methods, etc
- To provide a rapid feedback during development (as opposed to debugger driven
development)

These goals are still totally valid to me, and TDD is **one of the tools to achieve that**.
But 
a) There might be other ways to achieve these goals in some cases
b) If in some cases, TDD does not help with these goals, it should not be used

Our TDD
-------

Now, TDD in general does not immediately say a lot about the exact way to
execute it; there are several ways to do that. Similarly, there several flavours
of the code that we write, and they have different properties. 

At the same time, in our team some TDD rules are very specific and prescriptive:
- We only write unit tests (we acknoledge the theoratical benefit of integration
tests, but usually we don't write them regularly)
- Unit test should only touch one class, all dependencies should be mocked out
- DI is also part of TDD, so all the dependencies are accepted as constructor 
arguments; nothing else can be a constructor argument; there can be just one 
constuctor
- Static methods are not acceptable
- These rules apply to all the code that we write

I have some problems with this setup (each problem maps to a goal mentioned above):

- For some code unit tests won't help testing that code works
- Some design decisions needed for our flavour of TDD induce damage to code
design
- TDD is not always the most natural way to develop code

Let's start with the last one.

TDD is not always a pleasant and productive flow
------------------------------------------------

This is subjective to large extend, but there are objective issues too. 
Sometimes, you need to work in exploration mode, creating and erasing the code
several times before you arrive to something decent. You will be creating
and erasing the tests too. Sometimes you start with existing code from somewhere
and need to try it to evaluate. Sometimes too much effort is needed to create
a "pure" unit test.

By itself, this argument is usually related to lack of professionalism which
is IMO an oversimplification.

Not all unit tests are equally useful
-------------------------------------

The most useful unit tests can be formulated in terms of requirements, not
implementation. For some code it's not always easy or possible. Some examples:

- Code which calls external services, e.g. sends messages to the queue. We
can mock up all the queue classes and check the calls one by one, but does
it guarantee that sending to the queue will work? Nope.

- Configuration code of different kind has same problem. Making sure that
unit test repeats all the steps from the implementation doesn't prove the
configuration is correctly wired up.

Integration tests could be better in these scenarios.

Test-induced design damage
--------------------------