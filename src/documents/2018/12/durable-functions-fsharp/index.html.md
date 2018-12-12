---
layout: post
title: TODO
date: 2018-12-20
tags: ["Azure", "Azure Functions", "Serverless", "F#", "Workflows", "Azure Durable Functions"]
teaserImage: TODO
description: 
---

*The post is published as part of 
[F# Advent Calendar 2018](https://sergeytihon.com/2018/10/22/f-advent-calendar-in-english-2018/).*

This summer I was hired by the office of Santa Claus. They have a large organization that supplies
gifts and happiness to millions of children around the world.

As any large organization, Santa has impressive number of IT systems. As part of IT modernization
effort, they restructured the whole gift supply chain. They moved a lot of legacy components from
self-managed data center at North Pole&mdash;although the cooling is quite cheap there&mdash;to 
Azure cloud. Azure was an easy sell, since Santa's employees are using Office 365, SharePoint and
.NET development stack.

One of the goals of the redesign was to use cloud managed services and serverless archetecture
whenever possible. Santa has no spare elves to keep reinventing IT bycicles.

Wishlist Fulfillment Service
----------------------------

My task was to implement a Wishlist Fulfillment service. The service receives a
wishlist from a client (they call children "Clients"):

[TODO]

Luckily, the wishlist is already parsed by some other service, and also contains the metadata about
the kid's background and preferences.

For each item in the wishlist, our service calls the Matching service, which uses machine learning,
Azure Congintive services, and a bit of magic to determine actual gifts (they call gifts "Products")
that best fit the expressed wish + kid's profile. For instance, my son's "LEGO Draak" will match
to LEGO NINJAGO Masters of Spinjitzu Firstbourne Red Dragon. You get the point.

There might be several matches for each wish, and each result will have a confidence rating.

All the matching results are combined and sent to Gift Picking service. Gift Picking selects one
of the options based on confidence ratings and Naughty-or-Nice score of the client.

The last step of the workflow is to reserve the selected gift in the warehouse and shipping system
called "Santa's Archive of Products", also referred as SAP.

Here is the whole flow in one picture:

[TODO]

How should we implement this service?

Original Design
---------------

The Wishlist Fulfillment service should run in the cloud and integrate with other services. It
should be able to process millions of requests in December and stay very cheap to run during the
low season. We decided to leverage serverless with Azure Functions on Consumption Plan.

Here is the diagram of the original design:

[TODO]

We used Azure Storage Queues to keep the whole flow asynchronous and more resilient to failures
and load fluctuation.

This design would mostly work, but we found a couple of problems with it.

For instance, we had to pass all items of each wish list to the single invocation of Matching Function,
otherwise combining the matching result would be tricky. Matching service proved to be relatively
slow though. Although not in scope for the initial release, there were plans to add manual elf 
intervention for poorly matched items. This didn't really fit into the model of short executions
of serverless functions.

The functions were manually wired with storage queues and correcsponding bindings. The workflow
was spread over infrastructure definition, and thus was hard to grasp.

To improve of these points, we decided to try 
[Durable Functions](https://docs.microsoft.com/azure/azure-functions/durable/durable-functions-overview)&mdash;a library 
that brings workflow orchestration to Azure Functions. It introduces a number of tools to define stateful,
potentially long-running operations, and manages a lot of mechanics of reliable communication 
and state management behind the scenes.

If you want to know more about what Durable Functions are and why they might be a good idea,
I invite you to read my article 
[Making Sense of Azure Durable Functions](https://mikhail.io/2018/12/making-sense-of-azure-durable-functions/)
(20 minutes read).

For the rest of this post, I will walk you through the implementation of Wishlist Fulfillment workflow
with Azure Durable Functions.

Domain Model
------------

A good design starts with a decent domain model. I use F# for this project&mdash;the language with
the most rich domain modelling capabilities in .NET ecosystem.

### Types

Our service is invoked with a wishlist as input parameter, so let's start with the type `WishList`:

``` fsharp
type WishList = {
    Kid: Customer
    Wishes: string list
}
```

It contains information about the author of the list and recognized "order" items. `Customer` is a custom type;
for now it's not really important what's in it.

For each wish we want to produce a list of possible matches:

``` fsharp
type Match = {
    Product: Product
    Confidence: Probability
}
```

The product is a specific gift option from Santa's catalogue, and the confidence is basically a number 
from `0.0` to `1.0` of how reliable the match is.

The end goal of our service is to produce a `Reservation`:

``` fsharp
type Reservation = {
    Kid: Customer
    Product: Product
}
```

It represents the exact product selection for the specific kid.

### Functions

Wishlist Fulfillment service needs to combine three actions to achieve its goal. The actions can be
modelled with three strongly-typed asynchronous functions.

The first action is finding matches for each wish item:

``` fsharp
// string -> Async<Match list>
let findMatchingGift (wish: string) = async {
    // Call custom machine learning model
    // The real implementation uses Customer profile to adjust decisions to age etc.
    // but we keep the model simple for now.
}
```

The second action takes the *combined* list of all matches of all wishes and picks the one. Its
real implementation is the secret souce of Santa, but my model just picks the one with the highest
confidence level:

``` fsharp
// Match list -> Product
let pickGift (candidates: Match list) =
    candidates
    |> List.sortByDescending (fun x -> x.Confidence)
    |> List.head
    |> (fun x -> x.Product)
```

The first line of all my function definitions shows the function type. It's a mapping from untyped
wish item written by a child to the list of matches (zero, one, or many matches).

Provided the picked `gift`, the reservation is simply `{ Kid = wishlist.Kid; Product = gift }`,
not worth of a separate action.

The third action registers a reservation in the SAP system:

``` fsharp
// Reservation -> Async<unit>
let reserve (reservation: Reservation) = async {
    // Call Santa's Archive of Products
}
```

### Workflow

The Fulfillment service combines the three actions into one workflow:

``` fsharp
// WishList -> Async<Reservation>
let workflow (wishlist: WishList) = async {

    // 1. Find matches for each wish 
    let! matches = 
        wishlist.Wishes
        |> List.map findMatchingGift
        |> Async.Parallel

    // 2. Pick one product from the combined list of matches
    let gift = pickGift (List.concat matches)
    
    // 3. Register and return the reservation
    let reservation = { Kid = wishlist.Kid; Product = gift }
    do! reserve reservation
    return reservation
}
```

The workflow implementation is nice and concise summary of the actual domain flow.

Note that the Matching service is called multiple times in parallel, and then
the results are easily combined by virtue of `Async.Parallel` F# function.

So how do we translate the domain model to the actual implementation on top of
serverless Durable Functions?

Classic Durable Functions API
-----------------------------

C# was the first target language for Durable Functions. Javascript is now fully supported too.

F# wasn't initially mentioned as supported, but since F# runs on top of the same .NET runtime
as C#, it always worked. I had a blog post 
[Azure Durable Functions in F#](https://mikhail.io/2018/02/azure-durable-functions-in-fsharp/) and
then added some	[samples](https://github.com/Azure/azure-functions-durable-extension/tree/master/samples/fsharp)
to the oficial repository.

Here are two examples from that old F# code of mine (they have nothing to do with our today's domain):

``` fsharp
// 1. Simple sequencing of activities
let Run([<OrchestrationTrigger>] context: DurableOrchestrationContext) = task {
  let! hello1 = context.CallActivityAsync<string>("E1_SayHello", "Tokyo")
  let! hello2 = context.CallActivityAsync<string>("E1_SayHello", "Seattle")
  let! hello3 = context.CallActivityAsync<string>("E1_SayHello", "London")
  return [hello1; hello2; hello3]
}     

// 2. Parallel calls snippet
let tasks = Array.map (fun f -> context.CallActivityAsync<int64>("E2_CopyFileToBlob", f)) files
let! results = Task.WhenAll tasks
```

This code works and does its job, but doesn't really look like idiomatic F# code:

- No strong typing: the activity functions are called by name and with types manually specified
- Functions are not curried, so the partial application is hard
- Use of `context` object for any operation

Although not shown here, but reading input parameters, error handling, timeouts&mdash;all look
too C#-py.

Better Durable Functions
------------------------

Instead of going that sub-optimal route, we implemented the Durable service with more F#-idiomatic API.
I'll show the code first, and then I'll explain its foundation.

The implementation consists of three parts:

- Activity functions&mdash;one per action function from the domain model
- The Orchestrator function defines the workflow
- Azure Function bindings to instruct Azure how to run the application

### Activity Functions

Each Activity Function defines an action of the worflow: Matching, Picking and Reserving. We
simply reference the F# functions of those actions in one-line definitions:

``` fsharp
let findMatchingGiftActivity = Activity.defineAsync "FindMatchingGift" findMatchingGift
let pickGiftActivity = Activity.define "PickGift" pickGift
let reserveActivity = Activity.defineAsync "Reserve" reserve
```

Each activity is defined by a name and a function.

### Orchestrator

The Orchestrator calls Activity functions to produce the desired outcome of the service:

``` fsharp
let workflow wishlist = orchestrator {
    let! matches = 
        wishlist.Wishes
        |> List.map (Activity.call findMatchingGiftActivity)
        |> Activity.all

    let! gift = Activity.call pickGiftActivity (List.concat matches)
    
    let reservation = { Kid = wishlist.Kid; Product = gift }
    do! Activity.call reserveActivity reservation
    return reservation
}
```

Notice how closely it matches the workflow definition from our domain model:

[TODO]

The only differences are:

- `orchestrator` computation expression is used instead of `async` because multi-threading is
not allowed in Orchestrator functions
- `Activity.call` is used instead of direct call to functions
- `Activity.all` is used instead of `Async.Parallel`

### Hosting layer

Azure Function triggers need to be defined to host any piece of code as a cloud function. This can
be done manually in `function.json`, or via trigger generation from .NET attributes. In my case
I added the following four definitions:

``` fsharp
[<FunctionName("FindMatchingGift")>]
let FindMatchingGift([<ActivityTrigger>] wish) = 
    Activity.run findMatchingGiftActivity wish

[<FunctionName("PickGift")>]
let PickGift([<ActivityTrigger>] matches) = 
    Activity.run pickGiftActivity matches

[<FunctionName("Reserve")>]
let Reserve([<ActivityTrigger>] wish) = 
    Activity.run reserveActivity wish

[<FunctionName("WishlistFulfillment")>]
let Workflow ([<OrchestrationTrigger>] context: DurableOrchestrationContext) =
    Orchestrator.run (workflow, context)
```

The definitions are very mechanical and, again, strongly typed.

Introducing DurableFunctions.FSharp
-----------------------------------

The above code was implemented with the library 
[DurableFunctions.FSharp](https://github.com/mikhailshilkov/DurableFunctions.FSharp). I created
this library as a thin F#-friendly wrapper around Durable Functions.

Frankly, the whole purpose of this article was to introduce this library and make you curious
enough to give it a try. 

Here is how you get started:

TODO

I love to get as much feedback as possible! Pretty please, leave comments below, create issues
on the github repository, or open a PR. This would be super awesome!

Happy coding, and Merry Christmas!