---
layout: draft
title: Monads explained in C#
date: 2016-01-13
tags: [""]
teaser: TODO
---

It looks like there is a mandatory post that every blogger who learns functional programming should write:
what a Monad is. Monads have the reputation of being something very abstract and very confusing for every
developer who is not a hipster haskell programmer. They say that once you understand what a monad is, you 
loose the ability to explain it in simple language. Doug Crockford was the first lay this rule down, but
it becomes kind of obvious once you read 3 or 5 "explanations" on the web. Here is my attempt.

Monads are container types
--------------------------

Monads are containers which encapsulate some kind of functionality. It's that simple. The goals of monads
are similar to generic goals of any encapsulation in software development practices: hide the implementation
details from the client, but provide a proper way to use the hidden You functionality. It's not because we 
want to be able to change the implementation, it's because we want to make the client as simple as possible
and to enforce the best way of code structure.

Monads are flexible, so in C# they should be represented as a generic type:

``` cs
public class Monad<T>
{
}
```

Monad instances can be created
------------------------------

Quite an obvious statement, isn't it. Having a class `Monad<T>`, there should be a way to create an object
of this class out of an instance of type `T`. In functional world this operation is known as `return` 
function. In C# it can be as simple as a constructor:

``` cs
public class Monad<T>
{
    public Monad(T instance)
    {
    }
}
```

Usually it also makes sense to define an extension method to enable fluent syntax of monad creation:

``` cs
public static class MonadExtensions
{
    public static Monad<T> Return<T>(this T instance) => new Monad<T>(instance);
}
```

Monads can be chained to create new monads
------------------------------------------

This is the property which makes monads so useful, but also a bit confusing. In functional world this
operation is known as functional composition and is expressed with `bind` function (or `>>=` operator).
Here is the signature of `Bind` method in C#:

``` cs
public class Monad<T>
{
   public Monad<TO> Bind<TO>(Func<T, Monad<TO>> func)
   {
   }
}
```

As you can see, the `func` argument is a complicated thing. It accepts an argument of type `T` (not
a monad) and returns an instance of `Monad<TO>` where `TO` is another type. Now, our first instance
of `Monad<T>` knows how to bind itself to this function to produce another instance of monad of the
new type. The full power of monads comes when we compose several of them in one chain:

``` cs
initialValue
    .Return()
    .Bind(v1 => produceV2OutOfV1(v1))
    .Bind(v2 => produceV3OutOfV2(v2))
    .Bind(v3 => produceV4OutOfV3(v3))
    //...
```

And that's about it. Let's have a look at some classic monadic types.

Maybe (Option)
--------------