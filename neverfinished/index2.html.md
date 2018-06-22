---
layout: post
title: Monads explained in C#
date: 2018-06-01
tags: ["Functional Programming", "Monads", "Maybe", "LINQ"]
---

I enjoy functional programming. I'm sure FP is a very useful tool in any software developer's toolbox.

But at the same time I do realize that learning FP might be challenging. It comes with a baggage of
unfamiliar vocabulary which can be daunting for somebody coming from an object-oriented language like C#.

[TODO image of terms]

The Fallacy of Monad Tutorials
------------------------------

Monads are probably the most infamous term. Monads have the reputation of being something very abstract
and very confusing. 

Numerous attempt were made to explain monads in simple definitions, and monad tutorials have become a
genre of its own. And yet, times and times again, they fail to enlighten the readers.

The shortest explanation of monads looks like this:

[TODO A Monad is just a monoid in the category of endofunctors]

It's both mathematically correct and totally useless to anybody learning functional programming. To
understand this statement, one has to know terms "monoid", "category" and "endofunctors" and be able
to mentally compose them into something meaningful.

The same problem is apparent in most monad tutorials. They assume some pre-existing knowledge in
heads of their readers, and if that assumption fails, the tutorial doesn't click.

Focusing too much on mechanics of monads instead of explaining why they are important at all is another
common problem. But motivation is probably more important than monadic laws...

Douglas Crockford grasped this fallacy very well:

> Monads are cursed - once you understand monads for yourself you lose the ability to explain them to others

[TODO quote]

The problem here is likely the following. Every person who understands monads had their own way to
this knowledge. It haven't come all at once, instead there was a series of steps, each giving an insight,
until the last final step which made monads "click".

But they don't remember the whole path anymore. They go online and blog about that very last step as
the key to understanding, joining the club of flawed explanations.

There is a whole scientific paper from Tomas Petricek which studies monad tutorials.

I read that paper and a dozen of monad tutorials out there. And of course, now I came up with my own.

I'm probably doomed to fail too, at least for some readers. Yet, I know that some people found the
previous verion of this article useful.

I based my explanation on examples from C# which should be familiar to most .NET developers.

Story of Composition
--------------------

The base element of each functional program is Function. In typed languages functions have types,
and each function is just a mapping between the type of its input parameter and output parameter.
Such type can be annotated as `func: TypeA -> TypeB`.

C# is object-oriented language, so we use methods to declare functions. There are two ways to
define a method comparable to `func` functions above: using static method or instance method:

```
// Static methods
static class Mapper 
{
  static ClassB func(ClassA a) { ... }
}

// Instance methods
class ClassA 
{
  ClassB func() { ... }
}
```

Static form looks more similar to the function annotation, but they are actually equivalent
for the purpose of our discussion. I will use instance methods in my examples, but all of
them could be written as static extension methods too.

How do we compose more complex workflows, programs and applications out of such simple
building blocks? A lot of patterns both in OOP and FP worlds revolve around this question.
And Monads are one of the answers.

My sample code is going to be about conferences and speakers. The method implementations 
aren't really important, just watch the types carefully. There are 4 classes (types) and 
3 methods (functions):

```
class Speaker 
{
  Talk NextTalk() { ... }
}

class Talk 
{
  Conference GetConference() { ... }
}

class Conference 
{
  City GetCity() { ... }
}

class City { ... }
```

These methods are currently very easy to compose into a workflow:

```
static City NextTalkCity(Speaker speaker) 
{
  Talk talk = speaker.NextTalk();
  Conference conf = talk.GetConference();
  City city = conf.GetCity();
  return city;
}
```

Because the return type of the previous step always matches the input type of the next step, we can
write it even shorter:

```
static City NextTalkCity(Speaker speaker) 
{
  return 
    speaker
      .NextTalk()
      .GetConference()
      .GetCity();
}
```

This code looks quite readable. It's concise and it flows from top to bottom, from left to right, 
similar to how we are used to read any text. There is no much noise too.

Such code doesn't happen that often in real codebases though, because there are multiple complication
along the happy composition path. Let's look at some of them.

NULLs
-----

Any class instance in C# can be `null`. So, in the example above I might get runtime errors if
one of the methods ever returns `null` back.

Typed functional programming always tries to be explicit about types, so I'll re-write the signatures
of my methods to annotate the return types as nullable with `?` symbol next to types:

```
class Speaker 
{
  Talk? NextTalk() { ... }
}

class Talk 
{
  Conference? GetConference() { ... }
}

class Conference 
{
  City? GetCity() { ... }
}

class City { ... }
```

This is actually not a valid syntax in current C# version, because `Nullable<T>` and its short form
`T?` is not applicable to reference types. This [might change in C# 8](https://blogs.msdn.microsoft.com/dotnet/2017/11/15/nullable-reference-types-in-csharp/)
though, so bear with me.

Now, when composing our workflow, we need to take care of `null` results:

```
static City? NextTalkCity(Speaker speaker) 
{
  Talk? talk = speaker.NextTalk();
  if (talk == null) return null;

  Conference? conf = talk.GetConference();
  if (conf == null) return null;

  City? city = conf.GetCity();
  return city;
}
```

It's still the same method, but it got more noise now. Even though I used short-circuit returns
and one-liners, it still got harder to read.

To fight that problem, smart language designed came up with Null Propagation Operator:

```
static City NextTalkCity(Speaker speaker) 
{
  return 
    speaker
      ?.NextTalk()
      ?.GetConference()
      ?.GetCity();
}
```

Now we are almost back to our original workflow code: it's clean and concise, we just got
3 extra `?` symbols around.

Let's take another leap.

Collections
-----------

Quite often a function returns a collection of items, not just a single item. To some extent,
that's a generalization of `null` case: with `Nullable<T>` we might get 0 or 1 results back,
while with a collection we can get `0` to any `N` results.

Our sample API could look like this:

```
class Speaker 
{
  List<Talk> GetTalks() { ... }
}

class Talk 
{
  List<Conference> GetConferences() { ... }
}

class Conference 
{
  List<City> GetCities() { ... }
}
```

I used `List<T>` but it could be any class or plain `IEnumerable<T>`.

Who would we combine the methods into one workflow? Traditional version would look like this:


```
static List<City> AllCitiesToVisit(Speaker speaker) 
{
  var result = new List<City>();

  foreach (Talk talk in speaker.GetTalks())
    foreach (Conference conf in talk.GetConferences())
      foreach (City city in conf.GetCities())
        result.Add(city);
        
  return result;
}
```

It reads ok-ish still. But the combination of nested loops and mutation with some conditionals sprinkled 
on them can get unreadable pretty soon. The exact workflow might be lost in the mechanics.

As an alternative, C# language designers invented LINQ extension methods. So, we can write code like this:

```
static List<City> AllCitiesToVisit(Speaker speaker) 
{
  return 
    speaker
    .GetTalks()
    .SelectMany(talk => talk.GetConferences())
    .SelectMany(conf => conf.GetCities())
    .ToList();
}
```

Let me do one further trick and format the same code in a weird way:

```
static List<City> AllCitiesToVisit(Speaker speaker) {
  return 
    speaker
    .GetTalks()           .SelectMany(x => x
    .GetConferences()    ).SelectMany(x => x
    .GetCities()         ).ToList();
}
```

Now you can see the code the same original way on the left, and got just a bit of technical repeatable
clutter on the right. Hold on, I'll show you where I'm going.

Let's take another possible complication.

Asynchronous Calls
------------------

What if our methods need to access some remote database or service to produce the results? This
should be shown in type signature, and C# has `Task<T>` for that:

```
class Speaker 
{
  Task<Talk> NextTalk() { ... }
}

class Talk 
{
  Task<Conference> GetConference() { ... }
}

class Conference 
{
  Task<City> GetCity() { ... }
}
```

This change breaks our nice workflow composition again.

We'll get back to async-await in a section below, but the original way to combine `Task`-based
methods was to use `ContinueWith` and `Unwrap` API:

```
static Task<City> NextTalkCity(Speaker speaker) 
{
  return 
    speaker
    .NextTalk()
    .ContinueWith(talk => talk.Result.GetConference())
    .Unwrap()
    .ContinueWith(conf => conf.Result.GetCity())
    .Unwrap();
}
```

Hard to read, but let me apply my formatting trick again:

```
static Task<City> NextTalkCity(Speaker speaker) 
{
  return 
    speaker
    .NextTalk()         .ContinueWith(x => x.Result
    .GetConference()   ).Unwrap().ContinueWith(x => x.Result
    .GetCity()         ).Unwrap();
}
```

You can see that, once again, it's our nice readable workflow on the left + some mechanical repeatable
connecting code on the right.

Pattern
-------

Can you see a pattern yet?

I'll repeat the `null`, `List` and `Task` based workflows again:

```
static City NextTalkCity(Speaker speaker) 
{
  return 
    speaker               ?
      .NextTalk()         ?
      .GetConference()    ?
      .GetCity();
}

static List<City> AllCitiesToVisit(Speaker speaker) {
  return 
    speaker
    .GetTalks()            .SelectMany(x => x
    .GetConferences()     ).SelectMany(x => x
    .GetCities()          ).ToList();
}

static Task<City> NextTalkCity(Speaker speaker) 
{
  return 
    speaker
    .NextTalk()            .ContinueWith(x => x.Result
    .GetConference()      ).Unwrap().ContinueWith(x => x.Result
    .GetCity()            ).Unwrap();
}
```

In all 3 cases, there was a complication which prevented us from sequencing method
calls fluently. In all 3 cases, we found a gluing code to get back to fluent composition.

Let's try to generalize this approach. Given some generic container type 
`WorkflowThatReturns<T>`, we have a method to combine an instance of such workflow with
a function which accepts the result of that workflow and returns another workflow back:

```
class WorkflowThatReturns<T> 
{
  WorkflowThatReturns<U> AddStep(Func<T, WorkflowThatReturns<U>> step);
}
```

In case this is hard to grasp, have a look at the picture of what is going on:

TODO

1. An instance of type `T` sits in a generic container.

2. We call `addStep` with a function, which converts `T` to `U` sitting inside yet another
container. 

3. We get an instance of `U` but inside two containers.

4. Two containers are automatically unwrapped into a single container to get back to the
original shape.

5. Now we are ready to add another step!

In the following code, `nextTalk` returns the first instance inside the container:

```
WorkflowThatReturns<Phone> workflow(Speaker speaker) {
  return 
    speaker
    .NextTalk()         
    .addStep(x => x.GetConference())
    .addStep(x => x.GetCity()); 
}
```

Subsequently, `addStep` is called two times to transfer to `Conference` and then
`City` inside the same container:

TODO image with two steps

Finally, Monads
---------------

The name of this pattern is **Monad**.

In C# terms, a Monad is a generic class with two operations: constructor and bind.

```
class Monad<T> {
  Monad(T instance);
  Monad<U> Bind(Func<T, Monad<U>> f);
}
```

Constructor is used to put an object into container, `Bind` is used to replace one
contained object with another contained object.

It's important that `Bind`'s argument returns `Monad<U>` and not just `U`. We can think
of `Bind` as a combination of `Map` and `Unwrap` as defined per following signature:

```
class Monad<T> {
  Monad(T instance);
  Monad<U> Map(Function<T, U> f);
  static Monad<U> Unwrap(Monad<Monad<U>> nested);
}
```

Even though I spent quite some time with examples, I expect you to be slightly confused
at this point. That's ok.

Keep going and let's have a look at several sample implementations of Monad pattern.

<a name="maybe"></a>
Example: Maybe (Option) type
----------------------------

My first motivational example was with `Nullable<T>` and `?.`. The full pattern
containing either 0 or 1 instance of some type is called `Maybe` (it maybe has a value,
or maybe not).

`Maybe` is another approach to dealing with 'no value' value, alternative to the 
concept of `null`. 

Functional-first language F# typically doesn't allow `null` for its types. Instead, F# has 
a maybe implementation built into the language: 
it's called `option` type. Here is a sample implementation in C#:

``` cs
public class Maybe<T> where T : class
{
    private readonly T value;

    public Maybe(T someValue)
    {
        if (someValue == null)
            throw new ArgumentNullException(nameof(someValue));
        this.value = someValue;
    }

    private Maybe()
    {
    }

    public Maybe<TO> Bind<TO>(Func<T, Maybe<TO>> func) where TO : class
    {
        return value != null ? func(value) : Maybe<TO>.None();
    }

    public static Maybe<T> None() => new Maybe<T>();
}
```

When `null` is not allowed, any API contract gets more explicit: either you
return type `T` and it's always going to be filled, or you return `Maybe<T>`.
The client will see that `Maybe` type is used, so it will be forced to handle 
the case of absent value.

Given an imaginary repository contract (which does something with customers and
orders):

``` cs
public interface IMonadicRepository
{
    Maybe<Customer> GetCustomer(int id);
    Maybe<Address> GetAddress(int id);
    Maybe<Order> GetOrder(int id);
}
```

The client can be written with `Bind` method composition, without branching, 
in fluent style:

``` cs
Maybe<Shipper> shipperOfLastOrderOnCurrentAddress =
    repo.GetCustomer(customerId)
        .Bind(c => c.Address)
        .Bind(a => repo.GetAddress(a.Id))
        .Bind(a => a.LastOrder)
        .Bind(lo => repo.GetOrder(lo.Id))
        .Bind(o => o.Shipper);
```

As we saw above, this syntax looks very much like a LINQ query with a bunch 
of `SelectMany` statements. One of the common 
implementations of `Maybe` implements `IEnumerable` interface which allows 
a more C#-idiomatic binding composition. Actually:

IEnumerable + SelectMany is a Monad 
-----------------------------------

`IEnumerable` is an interface for enumerable containers.

Enumerable containers can be created - thus the constructor monadic operation.

The `Bind` operation is defined by the standard LINQ extension method, here 
is its signature:

``` cs
public static IEnumerable<B> SelectMany<A, B>(
    this IEnumerable<A> first, 
    Func<A, IEnumerable<B>> selector)
```

Direct implementation is quite straitforward:

``` cs
static class Enumerable 
{
    public static IEnumerable<U> SelectMany(
        this IEnumerable<T> values, 
        Func<T, IEnumerable<U>> func) 
    { 
        foreach (var item in values)
            foreach (var subItem in func(item))
                yield return subItem;
    }
}
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

Task Monad (Future)
-------------------

Monad laws
----------

There are a couple of laws that `Return` and `Bind` need to adhere to, so
that they produce a proper monad.

**Identity law** says that that `Return` is a neutral operation: you can safely
run it before `Bind`, and it won't change the result of the function call:

``` cs
// Given
T value;
Func<T, M<U>> f;

// == means both parts are equivalent
value.Return().Bind(f) == f(value) 
```

**Associativity law** means that the order in which `Bind` operations
are composed does not matter:

``` cs
// Given
M<T> m;
Func<T, M<U>> f;
Func<U, M<V>> g;

// == means both parts are equivalent
m.Bind(f).Bind(g) == m.Bind(a => f(a).Bind(g))
```

The laws may look complicated, but in fact they are very natural 
expectations that any developer has when working with monads, so don't
spend too much mental effort on memorizing them.

Conclusion
----------

You should not be afraid of the "M-word" just because you are a C# programmer. 
C# does not have a notion of monads as predefined language constructs, but 
it doesn't mean we can't borrow some ideas from the functional world. Having 
said that, it's also true that C# is lacking some powerful ways to combine 
and generalize monads which are possible in Haskell and other functional 
languages.