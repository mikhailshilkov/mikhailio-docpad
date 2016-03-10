---
layout: draft
title: Actors patterns and antipatterns
date: 2016-02-25
tags: ["F#", "akka.net", "actors"]
teaser: TODO
---

My exploration of Actors model started with [Akka.NET](http://getakka.net) framework - a .NET port of
JVM-based [Akka](http://akka.io) framework. Actors programming model made a lot of sense to me, but once
I started playing with it, some questions arised. Most of those questions were related to the
following definition:

> An actor is a container for `State`, `Behavior`, a `Mailbox`, `Children` and a `Supervisor Strategy`.

So, based on the [Akka.NET Bootcamp](https://github.com/petabridge/akka-bootcamp) course I undestood that
an Actor

- knows what kind of messages it can accept
- does some processing of each message
- holds some state throughout its lifecycle which is changed during message processing
- potentially changes behavior based on the current state
- creates and stores references to child actors
- obtains references to other actors
- sends messages to children and other actors

While it's nice that the framework enables us to develop for different aspects of actor 
behavior, it might also be dangerous in case you do all the things in one place. At least,
that's where I ended up during my first attempt. My actors were doing all the things from 
the above list and the code got messy very quick. So, the following questions popped up
in my head:

How do I avoid mixing several concerns in one piece of code?

How do I make the code easily testable?

How do I minimize the usage of mutable state?

How do I avoid boilerplate code when it's not needed?

Functional Actors
-----------------

~Functions are nice. How do we make actors out of functions? Sometimes actors
don't need all the features of the framework. Let's look at the some common
patterns that I see.

~ The default actor function looks like shit. `actorOf2` is better. My approach
is to create `actorOfX` helper functions for different types of actors.

Message Sink
------------

~ The simplest type of actor. It gets a message and does some action on it. 
And that's it. It does not produce any new messages and has no state. It could
be represented with a function of type `msg: 'a -> unit`. E.g. the following
function just logs the message (it could save it to a database)

``` fs
let messageSink msg =
  printn "Message received: %A" msg
```

So how do we make an actor out of this function?

``` fs
let actorOfSink (f : 'a -> unit) =
  actorOf2 (fun _ msg -> f msg)
```

Converter
---------

~ Receives a message