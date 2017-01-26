---
layout: draft
title: NEventStore
date: 2017-01-10
tags: ["fsharp", "programming puzzles"]
---

In [my previous post about Event Store read complexity]() I discussed how
the amount of reads to the event database might grow quadratically in
relation to amount of event in aggregate.

On the higher level, it's clear that the event database should be optimized
for reads rather that writes, which is not always obvious from the definition
of the "append-only store".

NEventStore
-----------

I this post I want to look at [NEventStore]() of top of [SQL Database]()
which is the combination we currently use as Event Store in Azure-based
web application.

NEventStore is a C# abstraction over Event Store with multiple providers
for several database backends. We use [SQL provider](). When you intialize
is with a connection string to an empty database, the provider will go
on and create two tables with schema, indices etc. The most important
table is `Commits` and it gets the following schema:

``` sql
CREATE TABLE
```

The primary key is an `IDENTITY` column, which means the new events (commits)
are appended to the end of the clustered index. Clearly, this is good
for `INSERT` performance.

There is a number of secondary non-clustered indexes that are optimized
for reach API of NEventStore library, e.g. TODO

Our Use Case
------------

It turns out that we don't need those extended API provided by `NEventStore`.
Effectivly, we only need two operations to be supported:

- Add a new event to a stream
- Read all events of a stream

Our experience of running production-like workloads showed that the read
operation performance suffers a lot when the size of a stream grows. Here
is a sample query plan for the read query with the default schema:

TODO: comment

Tuning for Reads
----------------

After seing this, we decided to try re-thinking the indexing schema of the
`Commits` table. Here is what we came down to:

``` sql

```

TODO: comment

The change makes INSERT's less efficient. It's not a simple append to the 
end of the clustered index anymore.

But at this price, the reads just got much faster. Here is the plan for 
the same query over the new schema:

TODO: comment

Our Results
-----------

The results looks great for us. We are able to run our 50 GB Commits table
on a 100-DTU SQL Database instance, with typical load of 15 to 30 percent.
The reads are still taking the biggest chunk of the load, with insert still
being far behind.

The mileage may vary, so be sure to test your NEventStore schema versus
your workload.

Further Improvements
--------------------