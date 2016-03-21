---
layout: draft
title: Building a Poker Bot with Akka.NET Actors
date: 2016-02-25
tags: ["poker bot", "F#", "akka.net", "actor model"]
teaser: 
---

*This is the fourth part of **Building a Poker Bot** series where I describe my experience developing bot software 
to play in online poker rooms. I'm building the bot with .NET framework and F# language which makes the task relatively 
easy and very enjoyable. Here are the previous parts:*

- [*Building a Poker Bot: Card Recognition*](http://mikhail.io/2016/02/building-a-poker-bot-card-recognition/)
- [*Building a Poker Bot: String and Number Recognition*](http://mikhail.io/2016/02/building-a-poker-bot-string-recognition/)
- [*Building a Poker Bot: Mouse Movements*](http://mikhail.io/2016/03/building-a-poker-bot-mouse-movements/)

This post lays out the most exciting part of the bot. I'll compose recognition, flow, decision and mouse clicking
parts together into the bot application. The application is a console executable interacting with multiple 
windows of poker room software.

Flow
----

The following picture shows the outline of the application flow:

(Find tables) -> (Recognize each screen) -> (Understand what happened) -> (Make decision) -> (Click the button)

Find tables - Every half a second or so we scan the all windows and search for open poker tables among them.
For each poker table we make a screenshot and send those to recognition.

Recognize a screen - Parse the data from the screenshot. Check whether it's our turn to make a play now, what
the [cards](http://mikhail.io/2016/02/building-a-poker-bot-card-recognition/) and 
[stacks](http://mikhail.io/2016/02/building-a-poker-bot-string-recognition/) are, etc.

Understand what happened - Understand if that's a new hand or there was a past history before. See
what your villains did and which new cards we got. Obviously, the history of current hand state should be 
preserved here.

Make decision - Here the secret sauce comes to play and produces a move to be made. This is actually the meat
that makes the whole application useful, but I won't discuss it in details in this post.

Click the button - Based on the decision made, click the right buttons. It should be done with proper delays
and [human-like movements](http://mikhail.io/2016/03/building-a-poker-bot-mouse-movements/) so that the villain
and poker room don't understand that it's bot that is playing.

Let the Actors Play
-------------------

Because of the multi-tabling that I mentioned, the application is intinsically multi-threaded. At the same time,
the different parts of the flow are executed at different cadence:

- Finding tables is triggered by time and is single-threaded
- Screen recognition, history detection and decision making run in sequence and can be executed parallely
for multiple tables
- Clicking the buttons is again single-threaded, and it must syncronize the outputs from the previous steps,
put them in sequence with appropriate delays

Here are the other threats of the flow:

- It is reactive and event based
- The flow is unidirectional, the output of one step goes to the input of the next step
- Most steps are stateless, but the history state needs to be preserved and, ideally, isolated from the other
steps

This list of features made me pick the Actor-based [Akka.NET](http://getakka.net) framework to implement the flow.
For sure, the application could be done with a bunch of procedural code instead. But I found actors to be
a useful modeling tecnique to be employed. Also, I was curious how F# and Akka.NET would work together.

Supervision Hierachy
--------------------

In Akka.NET each actor has a supervisor actor who is managing its lifecycle. All actors together form a
supervision tree. Here is the tree shown for the Player application:

(TODO)

There is just one copy of both Table Finder and Button Clicker actors and they are supervised by the root
User actor. For each poker table a Recognition actor gets created. These actors are managed by Table 
Finder. Each Recognizer actor creates an instance of History actors to track the hand history, and each
History actor creates an instance of Decision actor to make decisions for a given hand history. Finally,
all decisions are sent to one centralized Clicker actor whose job is to click all the tables with proper
delays and in order.

Implementation Pattern
----------------------

All actors are implementation using one pattern. Here is the definition of this structure:

    type ThisActorMessage = { /* fields of the message */ }

    let actor messageProcessingFunction knownReferences =
      // define mutable actor state here
      // ...
      let imp (mailbox : Actor<'a>) (msg : ThisActorMessage) =    
        let outputMsg = messageProcessingFunction msg
        // send output message to another actor from known references or internal state
        // ...
    imp

Let's look at some examples to understand this structure better.

Clicker Actor
-------------

Clicker actor has the simplest implementation beacause it does not send messages to other actors:

    type ClickTarget = (int * int * int * int)
    type ClickerMessage = {
      WindowTitle: string
      Clicks: ClickTarget[]
    }

    let clickerActor click =
      let imp _ (msg: ClickerMessage) = click msg
      imp

Basically, there are just 3 parts here:

1. Clicker Message with window information and targets to be clicked.
2. A `click` function of type `ClickerMessage -> unit` which executes button clicks with proper
delays etc.
3. The actor implementation `imp`, which is an adapter function between the type of `click` and the type 
that is expected by Akka.NET. The `mailbox` parameter is ignored.

Here is how the actor is created:

    let clickerRef = 
      clickerActor click'
      |> actorOf2 
      |> spawn system "clicker-actor"

Actor goes under supervision by actor system with `click'` as message handler.

Recognizer Actor
----------------

    let actor recognize decider =
      let mutable decideRef = null
      let imp (mailbox : Actor<'a>) (window : WindowInfo) =
        let result = recognize window.Bitmap
        if decideRef = null then decideRef <- spawn mailbox.Context "decide-actor" (actorOf2 <| decider)
        decideRef <! { WindowTitle = window.Title; TableName = window.TableName; Screen = result; Bitmap = window.Bitmap }
      imp