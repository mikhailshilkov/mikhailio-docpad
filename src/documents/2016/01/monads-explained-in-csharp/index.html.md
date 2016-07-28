---
layout: post
title: Monads explained in C#
date: 2016-01-25
tags: ["functional programming", "monads", "maybe", "LINQ"]
teaser: It looks like there is a mandatory post that every blogger who learns functional programming should write: what a Monad is. Monads have the reputation of being something very abstract and very confusing for every developer who is not a hipster Haskell programmer. They say that once you understand what a monad is, you loose the ability to explain it in simple language. Doug Crockford was the first one to lay this rule down, but it becomes kind of obvious once you read 3 or 5 "explanations" on the web. Here is my attempt.
---

It looks like there is a mandatory post that every blogger who learns functional programming should write:
what a Monad is. Monads have the reputation of being something very abstract and very confusing for every
developer who is not a hipster Haskell programmer. They say that once you understand what a monad is, you 
loose the ability to explain it in simple language. Doug Crockford was the first one to lay this rule down, but
it becomes kind of obvious once you read 3 or 5 "explanations" on the web. Here is my attempt.

Monads are container types
--------------------------

Monads are containers which encapsulate some kind of functionality. It's that simple. The goals of monads
are similar to generic goals of any encapsulation in software development practices: hide the implementation
details from the client, but provide a proper way to use the hidden functionality. It's not because we 
want to be able to change the implementation, it's because we want to make the client as simple as possible
and to enforce the best way of code structure. Quite often monads provide the way to avoid imperative code
in favor of functional style.

Monads are flexible, so in C# they should be represented as generic types:

``` cs
public class Monad<T>
{
}
```

Monad instances can be created
------------------------------

Quite an obvious statement, isn't it. Having a class `Monad<T>`, there should be a way to create an object
of this class out of an instance of type `T`. In functional world this operation is known as `Return` 
function. In C# it can be as simple as a constructor:

``` cs
public class Monad<T>
{
    public Monad(T instance)
    {
    }
}
```

But usually it makes sense to define an extension method to enable fluent syntax of monad creation:

``` cs
public static class MonadExtensions
{
    public static Monad<T> Return<T>(this T instance) => new Monad<T>(instance);
}
```
Monads can be chained to create new monads
------------------------------------------

This is the property which makes monads so useful, but also a bit confusing. In functional world this
operation is known as functional composition and is expressed with the `Bind` function (or `>>=` operator).
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

And that's about it. Let's have a look at some examples.

<a name="maybe"></a>
Example: Maybe (Option) type
----------------------------
`Maybe` is the 101 monad which is used everywhere. `Maybe` is another approach to dealing
with 'no value' value which is alternative to the concept `null`. Basically your object should
never be null, but it can either have `Some` value or be `None`. F# has a maybe implementation
built into the language: it's called `option` type. Here is a sample implementation in C#:

``` cs
public class Maybe<T> where T : class
{
    private T value;

    public Maybe(T someValue)
    {
        if (someValue == null)
            throw new AgrumentNullException(nameof(someValue));
        this.value = someValue;
    }

    private Maybe()
    {
    }

    public Maybe<TO> Bind<TO>(Func<T, Maybe<TO>> func)
    {
        return value != null ? new Maybe<TO>(func(value)) : Maybe<TO>.None();
    }

    public static Maybe<T> None() => new Maybe<T>();
}
```

``` cs
public static class MaybeExtensions
{
    public static Maybe<T> NullToMaybe<T>(T value)
    {
        return value != null ? new Maybe<T>(value) : Maybe<T>.None();
    }
}
```

Return function is implemented with a combination of a public constructor which accepts `Some` value
(notice that `null` is not allowed) and a static `None` method returning an object of 'no value'.
`NullToMaybe` combines both of them in one call. 

`Bind` function is implemented explicitly. 

Let's have a look at a use case. Imagine we have repositories which load the data from an external
storage (I'll put them to a single class for the sake of brevity):

``` cs
public class Repository
{
    public Maybe<Customer> GetCustomer(int id)
    {
        var row = ReadRowFromDb(id); // returns null if not found
        return row.NullToMaybe().Bind(r => ConvertRowToCustomer(r));
    }

    public Maybe<Address> GetAddress(int id) => ... // similar implementation

    public Maybe<Order> GetOrder(int id) => ... // similar implementation
}
```

The repository reads a row from the database and then converts its value or null to a `Maybe<DataRow>`.
Then it's immediately bound to a function which converts the row to a domain object (I'll omit this
function's implementation but remember that it can also return a `Maybe<Customer>` if that's warranted
by requirements).

Now here is a more sophisticated example of `Bind` method composition:

``` cs
Maybe<Shipper> shipperOfLastOrderOnCurrentAddress =
    repo.GetCustomer(customerId)
        .Bind(c => repo.GetAddress(c.Address.Id))
        .Bind(a => repo.GetOrder(a.LastOrder.Id))
        .Bind(o => o.Shipper);
```

If you think that the syntax looks very much like a LINQ query with a bunch of `Select` statements, you are
not the only one ;) One of the common implementations of `Maybe` implements `IEnumerable` interface
which allows a more C#-idiomatic binding composition. Actually:

IEnumerable + SelectMany is a monad 
-----------------------------------

`IEnumerable` is an interface for enumerable containers.

Enumerable containers can be created - thus the `Return` monadic operation.

The `Bind` operation is defined by the standard LINQ extension method, here is
its signature:

``` cs
public static IEnumerable<B> SelectMany<A, B>(
    this IEnumerable<A> first, 
    Func<A, IEnumerable<B>> selector)
```

And here is an example of composition:

``` cs
IEnumerable<Shipper> someWeirdListOfShippers =
    customers
        .SelectMany(c => c.Addresses)
        .SelectMany(a => a.Orders)
        .SelectMany(o => o.Shippers);
```

The query has no idea about how the collections are stored (encapsulated in
containers). We use functions `A -> IEnumerable<B>` to produce new enumerables
(`Bind` operation).

Conclusion
----------

You should not be afraid of the "M-word" just because you are the C# programmer. C# does not have
a notion of monads as predefined language constructs, but it doesn't mean we can't borrow some
ideas from the functional world. Having said that, it's also true that C# is lacking some powerful
ways to combine and generalize monads which are possible in Haskell and other functional languages.
