---
layout: draft
title: Functional Thinking for C# devs: The Basics
date: 2015-12-18
tags: []
teaser: TODO
---

Introduction
------------

C# was released 15 years ago. That was the world of object oriented software.
During these years, C# got a lot of features from functional languages. 
F# was also released.
Functional becomes more popular, more people understand the benefits.

Functional programming is not only about the language constructs, but also
about the way people think of their code and structure it.

There are good books about that (links), and I recommend them. But I want
to show my take on the topic and how simple and powerful these concepts
can be.

We will speak about strongly typed functions, just because it's more 
applicable to .NET and easier to illustrate.

I will use a lot of pictures because it's the easiest way to read and understand
the information. I won't use UML because it sucks.

I'll start with really basic things, bear with me if you find them too
easy - I just need these basics for more advanced topics later.

Data types
----------

Functional programming is all about data and data types. We will define the
data item as a container for related data properties. Data types don't have
any significant behaviour (we'll look at some behaviour later, e.g. equals and
tostring). In C# we model them as anemic struct or classes. Here are some
examples:

(Picture of a number 3)

This is a simple data type - integer.

(Picture of a string "hello world")

This is another simple data type - string.

(Picture of an object with 3 properties)

This is an object with 3 properties.

Here are some desired properties of any data type that we want to use:

- Immutability. This way we make sure that functions don't modify input data,
which makes reasoning about them much easier, as we will see later.

- Always internally consistent. Invalid states are not representable and 
lead to compile time (preffered) or runtime errors if someone tries to set
it to invalid state. This way we are sure that when we get a data item, it's
always valid. Not much to encapsulate in data type, but validation rules should
be encapsulated whenever possible.

- Explicit. No primitive type obsession. (example) No nulls - null is not explicit enough:
is it null because something does not exist yet? Is it null because of error.
More importantly on the usage side: can it be null or not?

Collection is a special data type which plays a big role. It represents
multiple items of the same time. 

(Picture of collection)

There are several types of collections, we will use a sequence which is similar 
to IEnumerable in .NET.

Function
--------

Function has an input data type and output data type. It accepts a data item
as input and converts it to an output item.

(Picture of function)

The notion of pure functions.