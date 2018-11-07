---
layout: post
title: From 0 To 1000 Instances: How Serverless Providers Scale Queue Processing
date: 2018-11-08
tags: ["Azure", "Azure Functions", "Serverless", "Performance", "Scalability", "AWS", "AWS Lambda", "GCP", "Google Cloud Functions"]
teaserImage: teaser.jpg
description: Comparison of queue processing scalability for FaaS across AWS, Azure and GCP
---

Whenever I see a Getting Started with Function-as-a-Service tutorial, it usually shows off an HTTP-triggered synchronous scenario.
In my projects though, I use a lot of asynchronous functions triggered by a queue or an event stream.

Quite often, the number of messages going through a queue doesn't stay flat over time. I might drop batches of work now and
then. My app might get piles of queue items arriving from upstream systems which were down or under maintenance for an extended period.
The system might see some rush-hour peaks every day or busy days every month.

That's where serverless tech shines: you pay per execution, and the provider takes care of scaling up or down for you. That's the
promise. Today I want to put this scalability under test.

The goal of my article is to explore queue-triggered serverless Functions:

- Across Big-3 cloud providers (Amazon, Microsoft, Google)
- For different types of workload
- For different performance tiers
- To come up with practical advice over asynchronous functions for real projects

Let's see how I did that and what the outcome was.

*DISCLAIMER. Performance testing is hard. I might be missing some crucial factors and parameters that
influence the outcome. My interpretation might be wrong. The results might change over time. If you happen 
to know a way to improve my tests, please let me know, and I will re-run them and re-publish the results.*

Methodology
-----------

In this article I analyze the results of executions of the following cloud services:

- AWS Lambda triggered by SQS queues
- Azure Function triggered by Storage Queues
- Google Cloud Function triggered by Cloud Pub/Sub

All functions are implemented in Javascript and are running on GA runtime.

At the beginning of each test, I throw 100.000 messages into the queue which was idle before that. Enqueuing never took longer
than 1 minute (I send from multiple clients in parallel).

I disabled any batch processing, so each message is consumed by a separate Function invocation.

I then analyze the logs (AWS CloudWatch, Azure Application Insights, and GCP Stackdriver Logging) to draw charts of executions
distribution over time.

How Scaling Actually Works
--------------------------

To understand the results better, let's start by looking at a very simplistic but still useful model of how cloud providers are
scaling the serverless applications.

All the providers are handling the increased load by "scaling out", i.e., by creating multiple instances of the same application that
execute the chunks of work in parallel. 

In theory, a cloud provider could spin up an instance for each message in a queue as soon as the messages arrive. The backlog processing
time would then stay very close to zero.

In practice, allocating instances is not cheap. Cloud provider has to boot up the function, hit a
[cold start](https://mikhail.io/2018/08/serverless-cold-start-war/) and otherwise waste expensive resources on a job which 
potentially will take just a few milliseconds.

So the providers are trying to find a sweet spot between handling the work as soon as possible and using resources
efficiently. The outcomes differ, which is the point of my article.

### AWS

AWS Lambda defines scale out with a notion of Concurrent Executions. Each instance of your AWS Lambda is handling a single
execution at any given time. In our case, it's processing a single SQS message.

It's helpful to imagine an instance to be a container working on a single task. If an execution pauses or waits for an external
I/O operation, the instance is on hold.

The model of concurrent executions is universal to all trigger types supported by Lambdas. An instance doesn't work with event
sources directly; it just receives an event to work on.

There is a central element in the system, let's call it "Controller" (is there an official name?). Controller is the one talking 
to an SQS queue and getting
the messages from it. It's then the job of Controller and related infrastructure to provision the required amount of instances
to be working on concurrent executions:

![Model of AWS Lambda Scale-Out](/aws-lambda-queue-scaling.png)

<center class="img-caption">Model of AWS Lambda Scale-Out</center>

As to scaling behavior, here is what the official [AWS docs](https://docs.aws.amazon.com/en_us/lambda/latest/dg/scaling.html) say:

> AWS Lambda automatically scales up ... until the number of concurrent function executions reaches 1000 ...
> Amazon Simple Queue Service supports an initial burst of 5 
> concurrent function invocations and increases concurrency by 60 concurrent invocations per minute.

### GCP

The model of Google Cloud Functions is very similar to what AWS does. It runs a single simultaneous execution per instance and
routes the messages centrally.

I wasn't able to find any scaling specifics except the definition of [Function Quotas](https://cloud.google.com/functions/quotas).

### Azure

The concurrency model of Azure Functions is different though (I assume Consumption Plan for this article).

Function App instance is more like a VM than a single-task container. It runs multiple concurrent executions in parallel.
Equally importantly, it gets messages from the queue on its own, not from a central controller.

Scale Controller still exists, but its role is a bit more subtle. It connects to the same data source (the queue) and needs
to determine how many instances to provision based on the metrics from that queue:

![Model of Azure Function Scale-Out](/azure-function-queue-scaling.png)

<center class="img-caption">Model of Azure Function Scale-Out</center>

This model might have pros and cons. If one execution is idle waiting for some I/O operation like HTTP request to finish,
the instance could get busy processing other messages, thus being more efficient. Running multiple executions is useful 
in terms of shared resource 
utilization, e.g., keeping database connection pools and reusing HTTP connections.

On the flip side, I can imagine the Scale Controller now needs to be smarter: to know not only the queue backlog but also how
instances are doing and at what pace they are processing the messages. It's probably doable based on queue telemetry though.

Let's start applying this knowledge in practical experiments.

Pause-the-World Workload
------------------------

My first serverless Function is aimed to simulate I/O-bound workloads without actually taking any external dependencies to keep
the experiment clean. So, the implementation is extremely straightforward: pause for 500 ms and return.

It could be loading data from a scalable third-party API. It could be running a database query. Instead, it just runs `setTimeout`.

I send 100k messages to queues of all 3 cloud providers and observe the result.

### AWS

Here comes the first chart of many, so let's learn to read it. The horizontal axis is showing time in minutes since
I've sent all the messages to the queue.

The line going from top-left to bottom-right shows the decreasing queue backlog. Accordingly, the left vertical axis annotates
the number of items still-to-be-handled.

The bars show the number of concurrent executions crunching the messages at a given time. Every execution logs the instance ID 
so that I could derive the instance count from the logs. The right vertical axis shows the instance number.

![AWS Lambda processing 100k SQS messages with "Pause" handler](/aws-lambda-sqs-iobound-scaling.png)

<center class="img-caption">AWS Lambda processing 100k SQS messages with "Pause" handler</center>

It took AWS Lambda 5.5 minutes to process the whole batch of 100k messages. If the same batch were to be processed sequentially,
it would take about 14 hours.

Notice how linear the growth of instance count is. If I apply the official scaling formula:

```
Instance Count = 5 + Minutes * 60 = 5 + 5.5 * 60  = 335
```

We get a very close result! Promises kept.

Since the workload is neither CPU- nor memory-intensive, I was using the smallest memory allocation of 128 MB.

### GCP

Same function, same chart - but this time for Google Cloud Functions:

![Google Cloud Function processing 100k Pub/Sub messages with "Pause" handler](/gcp-cloud-function-pubsub-iobound-scaling.png)

<center class="img-caption">Google Cloud Function processing 100k Pub/Sub messages with "Pause" handler</center>

Coincidentally, the total amount of instances, in the end, was very close to AWS. The scaling pattern looks entirely different though:
within the very first minute there was a burst of scaling close to 300 instances, and then the growth got very modest.

Thanks to this initial jump, GCP managed to finish processing almost 1 minute earlier than AWS.

Similar to AWS, I was using the smallest memory allocation of 128 MB.

### Azure

The shape of the chart for Azure Functions is very similar, but the instance number growth is significantly different:

![Azure Function processing 100k Queue messages with "Pause" handler](/azure-function-queue-iobound-scaling.png)

<center class="img-caption">Azure Function processing 100k Queue messages with "Pause" handler</center>

The total processing time got a bit faster than on AWS and somewhat slower than on GCP. Azure Function instances are more 
"powerful", so it takes much less of them to do the same amount of "work".

Instance number growth seems closer to linear than bursty.

### What we learned

Based on this simple test, it's hard to say if one cloud provider handles scale-out better than the others.

It looks like all serverless platforms under test are making decisions at the time resolution of 5-15 seconds, so the backlog
processing delays are likely to be measured in minutes. It sounds quite far from the theoretic "close to zero" target
but probably is good enough for most applications.

Crunching Numbers
-----------------

That was an easy job though. Let's give cloud providers some hard time by executing CPU-heavy workloads and see if they can
survive that!

This time each message handler calculates a [Bcrypt](https://en.wikipedia.org/wiki/Bcrypt) hash with a cost of 10. One such
calculation takes typically between 100ms and 300ms on a single CPU, depending on its speed.

### AWS

Once again, I've sent 100k messages to an SQS queue and recorded the processing speed and instance count.

Since the workload is CPU-bound, and AWS allocates CPU cycles proportionally to the allocated memory, the instance size might
have much influence on the result.

I've started with the smallest memory allocation of 128 MB:

![AWS Lambda (128 MB) processing 100k SQS messages with "Bcrypt" handler](/aws-lambda-sqs-cpubound-scaling.png)

<center class="img-caption">AWS Lambda (128 MB) processing 100k SQS messages with "Bcrypt" handler</center>

This time it took almost 10 minutes to complete the experiment.

The scaling shape is pretty much the same as last time, still correctly described by the formula `60 * Minutes + 5`.
However, because AWS allocates a small fraction of a full CPU to each 128 MB execution, one message takes around 1.700 ms to complete.
Thus, the total work increased approximately by the factor of 3 (45 hours if done sequentially) and the total processing time by 
the factor of 2 (10 minutes).

At the peak, 612 concurrent executions were running.

Let's see if larger Lambda instances would improve the outcome. Here is the chart for 512 MB of allocated memory:

![AWS Lambda (512 MB) processing 100k SQS messages with "Bcrypt" handler](/aws-lambda-sqs-cpubound-scaling-512.png)

<center class="img-caption">AWS Lambda (512 MB) processing 100k SQS messages with "Bcrypt" handler</center>

And yes it does. The average execution duration is down to 400 ms: 4 times less, as expected. The scaling shape still holds,
so the entire batch was done in less than 4 minutes.

### GCP

I've executed the same experiment on Google Cloud Functions. I've started with 128 MB, and it looks impressive:

![Google Cloud Function (128 MB) processing 100k Pub/Sub messages with "Bcrypt" handler](/gcp-cloud-function-pubsub-cpubound-scaling.png)

<center class="img-caption">Google Cloud Function (128 MB) processing 100k Pub/Sub messages with "Bcrypt" handler</center>

The average execution duration is very close to Amazon's: 1.600 ms. However, GCP scaled more aggressively&mdash;to staggering 1169
parallel executions! Scaling also has a different shape: it's not linear but grows in steep jumps at certain points. As a result,
it took less than 6 minutes on the lowest CPU profile&mdash;very close to AWS's time on 4x more powerful CPU.

What will GCP achieve on a faster CPU? Let's provision 512 MB. It must absolutely crush the test. Umm, wait, look at that:

![Google Cloud Function (512 MB) processing 100k Pub/Sub messages with "Bcrypt" handler](/gcp-cloud-function-pubsub-cpubound-scaling-512.png)

<center class="img-caption">Google Cloud Function (512 MB) processing 100k Pub/Sub messages with "Bcrypt" handler</center>

It actually... got slower. Yes, the average execution time is 4x lower: 400 ms, but the scaling got much less aggressive too,
which canceled the speed-up.

I confirmed it with the largest instance size of 2048 MB:

![Google Cloud Function (2 GB) processing 100k Pub/Sub messages with "Bcrypt" handler](/gcp-cloud-function-pubsub-cpubound-scaling-2048.png)

<center class="img-caption">Google Cloud Function (2 GB) processing 100k Pub/Sub messages with "Bcrypt" handler</center>

CPU is fast: 160 ms average execution time, but the total time to process 100k messages is now 8 minutes. Beyond the initial
spike at the first minute, it failed to scale up any further and stayed at about 110 concurrent executions.

Either GCP is not that keen to scale out larger instances, or I'm already hitting one of the quotas. I'll leave the root
cause analysis to a separate article.

### Azure

Azure Function don't have a configuration for allocated memory or any other instance size parameters. A single invocation
takes about 400 ms to complete. Here is the burndown chart:

![Azure Function processing 100k Queue messages with "Bcrypt" handler](/azure-function-queue-cpubound-scaling.png)

<center class="img-caption">Azure Function processing 100k Queue messages with "Bcrypt" handler</center>

Azure spent 21 minutes to process the whole backlog. The scaling was linear, similarly to AWS, but with much slower pace
regarding instance size growth, about `2.5 * Minutes`.

As a reminder, each instance *could* process multiple queue messages in parallel, but each such execution would be competing
for the same CPU resource, which doesn't help for the purely CPU-bound workload.

Practical Considerations
------------------------

Time for some conclusions and pieces of advice to apply in real serverless applications.

### Serverless is great for async data processing

If you are already using cloud services like managed queues and topics, serverless functions are the easiest way to consume them.
Moreover, the scaling is there too: it will probably take a lot of effort (and money) to roll out a hand-made processor with comparable
throughput and elasticity.

When was the last time when you ran 1.200 copies of your server or container?

### Serverless is not infinitely scalable

There are limits. Your Functions won't scale perfectly to accommodate your spike precisely&mdash;a provider-specific algorithm
will determine the scaling pattern.

If you have large spikes in queue workloads, which is quite likely for medium- to high-load scenarios, you should expect
delays up to several minutes before the backlog is fully digested.

All cloud providers have quotas and limits that define an upper boundary of scalability.

### Cloud providers have different implementations

**AWS Lambda** seems to have a very consistent and well-documented linear scale growth for SQS-triggered Lambda functions. It will
happily scale to 1000 instances, or whatever another limit you hit first.

**Google Cloud Functions** has the most aggressive scale-out strategy for the smallest instance sizes. It can be a cost-efficient and scalable
way to run your queue-based workloads. Larger instances seem to scale in a more limited way, so a further investigation is
required if you use one of those.

**Azure Functions** share instances for multiple concurrent executions, which works better for I/O-bound workloads than for CPU-bound ones.
Depending on the exact scenario that you have, it might help to play with instance-level settings.

### Don't forget batching

For the tests, I was handling queue messages in the 1-by-1 fashion. In practice, it helps if you can batch several messages
together and execute a single action for all of them in one go.

If the destination for your data supports batched operations, the throughput will usually gain immensely.
[Processing 100,000 Events Per Second on Azure Functions](https://blogs.msdn.microsoft.com/appserviceteam/2017/09/19/processing-100000-events-per-second-on-azure-functions/)
is an excellent case to prove the point.

### You might get too much scale

A few days ago, Troy Hunt published a great post [Breaking Azure Functions with Too Many Connections](https://www.troyhunt.com/breaking-azure-functions-with-too-many-connections/).
His scenario looks very familiar: he uses Queue-triggered Azure Functions to notify subscribers about data breaches.
One day he dropped 126 million items into the queue, Azure scaled out, which overloaded Mozilla's servers and caused them to
go all-timeouts.

Non-serverless dependencies limit the scalability of your serverless application. If you call a legacy HTTP endpoint,
a SQL database, a 3rd-party web service&mdash;be sure to test how *they* react when your serverless function scales out to hundreds of
concurrent executions.

Stay tuned for more serverless perf goodness!