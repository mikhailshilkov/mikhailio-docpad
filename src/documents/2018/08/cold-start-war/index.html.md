---
layout: post
title: Cold Start War
date: 2018-08-29
tags: ["Azure", "Azure Functions", "Serverless", "Performance", "Cold Start", "AWS", "AWS Lambda", "GCP", "Google Cloud Functions"]
---

Serverless cloud services are hot. Except when they are not :)

AWS Lambda, Azure Functions, Google Cloud Functions are all similar in their attempt
to enable rapid development of cloud-native serverless applications.

Auto-provisioning and auto-scalability are the killer features of those Function-as-a-Service
cloud offerings. No management required, cloud providers will do the provisioning for the user
based on the actual incoming load.

One drawback of such dynamic provisioning is a phenomenon called "Cold Start". Basically,
applications that haven't been used for a while take longer to startup and to handle the
first request.

TODO brief summary, with picture:

![Cold Start](/coldstart.jpg)

The problem was described multiple times, here are the notable links:
- [Understanding Serverless Cold Start](https://blogs.msdn.microsoft.com/appserviceteam/2018/02/07/understanding-serverless-cold-start/)
- TODO

The goal of my article today is to explore how cold starts compare:

- Across Big-3 cloud providers
- For different languages and runtimes
- For smaller vs larger applications (including dependencies)
- What can be done to optimize the cold starts

TODO: shed the light on where industry is going = teaser of conclusion.

Methodology
-----------

All tests were run against HTTP Functions, because that's where cold start matters the most. 

All the functions were returning a simple JSON reporting their current instance ID, language etc.
Some functions were also loading extra dependencies, see below.

I did not rely on execution time reported by a cloud provider. Instead, I measured end-to-end duration from
client perspective. This means that durations of HTTP gateway (e.g. API Gateway in case of AWS) are included
into the total duration. However, all calls were made from within the same region, so network latency should 
have minimal impact:

![Test Setup](/test-setup.png)

Important notes:

- Azure tests were done with version 1 of Functions runtime (Full .NET Framework), which is the production-ready GA version as of today
- Google Cloud Functions are still in beta, so it might be they haven't rolled out all optimizations yet

When Does Cold Start Happen?
----------------------------

Obviously, cold start happens when the very first request comes in. After that request is processed,
the instance is kept alive in case subsequent requests arrive. But for how long?

The answer differs between cloud providers.

### Azure

Here is the chart for Azure. It shows values of normalized request durations across
different languages and runtime versions (Y axis) depending on the time since the previous
request in minutes (X axis):

![Azure Cold Start Threshold](/azure-coldstart-threshold.png)

Clearly, an idle instance lives for 20 minutes and then gets recycled. All requests after 20 minutes
threshold hit another cold start.

### AWS

AWS is more tricky. Here is the same kind of chart, relative durations vs time since last request, 
measured for AWS Lambda. To help you read it, I've marked cold starts with blue color, and warm starts
with orange color:

TODO: make Azure orage too?

![AWS Cold Start vs Warm Start](/aws-coldstart-threshold.png)

There's no clear threshold here... Within this sample, no cold starts happenned within 28 minutes after previous 
invocation. Then the frequency of cold starts slowly rises. But even after 1 hour of inactivity, there's still a
good chance that your instance is alive and ready to take requests.

This doesn't match the official information that AWS Lambdas stay alive for just 5 minutes after the last
invocation. I reached out to Chris Munns, and he confirmed:

<blockquote class="twitter-tweet" data-conversation="none" data-lang="en"><p lang="en" dir="ltr">So what you are seeing is very much possible as the team plays with certain knobs/levers for execution environment lifecycle. let me know if you have concerns about it, but it should be just fine</p>&mdash; chrismunns (@chrismunns) <a href="https://twitter.com/chrismunns/status/1021452964630851585?ref_src=twsrc%5Etfw">July 23, 2018</a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

A couple learning points here:

- AWS is working on improving cold start experience (and probably Azure/GCP do too)
- My results might not be reliably reproducible in your application, since it's affected by recent adjustments

### GCP

Google Cloud Functions left me completely puzzled. Here is the same chart for GCP coldstarts (again,
orange are warm and blue are cold):

![GCP Cold Start vs Warm Start](/gcp-coldstart-threshold.png)

This looks totally random to me. Cold start can happen in 3 minutes after the previous request, or an instance
can be kept alive for the whole hour. The probability of cold start doesn't seem to depend on the interval,
at least just by looking at this chart.

Any ideas of what's going on are welcome!

Memory Allocation
-----------------

AWS Lambda and Google Cloud Functions have a setting to define the max memory size that gets allocated to a single
instance of a function. User can select a value from 128MB to 2GB and above at creation time.

More importantly, the virtual CPU cycles get allocated proportionally to this provisioned memory size. This means
that an instance of 512 MB will have twice as many CPU speed as an instance of 256MB.

Does this affect the cold start time?

I've run a series of tests to compare cold start latency across the board of memory/CPU sizes:

TODO

In contrast to Amazon and Google, Microsoft doesn't ask to select a memory limit. Azure will charge Functions based 
on the actual memory usage. More importantly, it will always dedicate a full vCore for a give Function execution.

It's not exactly apples-to-apples, but I chose to fix the memore allocations of AWS Lambda and GCF to 1024MB.
This feels the closest to Azure's vCore capacity, although I haven't tried a formal CPU performance comparison.

Given that, let's see how the 3 cloud providers compare in cold start time.

Javascript Baseline
-------------------

Javascript is the only language supported by Google Cloud Functions right now. Javascript is also
probably by far the most popular language for serverless applications across the board.

Thus, it makes sense to compare the 3 cloud providers on how they perform in Javascript. The
base test measures the cold starts of "Hello World" type of functions. Functions have to 
dependencies, so deployment package is really small.

Here are the numbers for cold starts:

![Cold Start for Basic Javascript Functions](/coldstart-js-baseline.png)

TODO conclusion

How Do Languages Compare?
-------------------------

I've written Hello World HTTP function in all supported languages of the cloud platforms: 

- AWS: Javascript, Python, Java, Go and C# (.NET Core)
- Azure: Javascript and C# (precompiled .NET assembly)
- GCP: Javascript

Azure kind of supports much more languages, including Python and Java but they are still considered
experimental / preview, so the cold starts are not fully optimized. See 
[my previous article](https://mikhail.io/2018/04/azure-functions-cold-starts-in-numbers/) for exact numbers.

The following chart shows some intuition about the cold start duration per language. The languages
are ordered based on mean response time, from lowest to highest. 65% of request
durations are inside the vertical bar (1-sigma interval) and 95% are inside the vertical line (2-sigma):

![Cold Start per Language per Cloud and Language](/coldstart-per-language.png)

TODO conclusion

Does Size Matter?
-----------------

OK, enough of Hello World. A real-life function might be more heavy, mainly because it would
depend on other third-party libraries.

To simulate such scenario, I've measured cold starts for functions with extra dependencies:

- Javascript referenced Bluebird, lodash and AWS SDK (TODO total size)
- .NET function references Entity Framework, Automapper, Polly and Serilog (TODO)
- Java function references TODO

Here are the results:

![Cold Start Dependencies](/coldstarts-dependencies.png)

As expected, the dependencies slow the loading down. You should keep your Functions lean,
otherwise you will pay in seconds for every cold start.

TODO:
An important note for Javascript developers: the above numbers are for Functions deployed
after [`Funcpack`](https://github.com/Azure/azure-functions-pack) preprocessor. The package
contained the single `js` file with Webpack-ed dependency tree. Without that, the mean
cold start time of the same function is 20 seconds!

Keeping Always Warm
-------------------

Can we avoid cold starts except the very first one by keeping the instance warm? In theory,
if we issue at least 1 request every several minutes, the first instance should stay warm for
long time.

For each service, I've added an extra hook to trigger the function every 10 minutes. I then 
measured the cold start statistics similar to all the tests above.

TODO:

During 2 days I was issuing infrequent requests to the same app, most of them would normally
lead to a cold start. Interestingly, even though I was regularly firing the timer, Azure 
switched instances to serve my application 2 times during the test period:

![Infrequent Requests to Azure Functions with "Keep It Warm" Timer](/cold-starts-keep-warm.png)

I can see that most responses are fast, so timer "warmer" definitely helps.

Anyway, keeping Functions warm seems a viable strategy.

TODO: link to prewarmer

Parallel Requests
-----------------

The problem of cold starts is not solved yet, at least not for more busy applications. 

What happens when there is a warm instance, but it's already busy with processing another
request?

I tested with a very lightweight function, which nevertheless takes some time to complete.
All it does is a sleep for 500 ms.

I believe it's an OK approximation for an IO-bound function.

The test client then issued 2 to 10 parallel requests to this function and measured the
response time for all requests.

TODO: 

The answer is that each instance can only handle one request simultaneously. Even if one 
instance is warm, if two requests come at the same time, one of the requests will hit a 
cold start because existing instance is busy with the other.

It's not the easiest chart to understand in full, but note the following:

- Each group of bars are for requests sent at the same time. Then there goes a pause about
20 seconds before the next group of requests gets sent

- The bars are colored by the instance which processed that request: same instance - same
color

![Azure Functions Response Time to Batches of Simultaneous Requests](/cold-starts-during-simultaneous-requests.png)

Here are some observations from this experiment:

- Out of 64 requests, there were 11 cold starts

- Same instance *can* process multiple simultaneous requests, e.g. one instance processed
7 out of 10 requests in the last batch

- Nonetheless, Azure is eager to spin up new instances for multiple requests. In total
12 instances were created, which is even more than max amount of requests in any single
batch

- Some of those instances were actually never reused (gray-ish bars in batched x2 and x3,
brown bar in x10)

- The first request to each new instance pays the full cold start price. Runtime doesn't
provision them in background while reusing existing instances for received requests

- If an instance handled more than one request at a time, response time invariably suffers,
even though the function is super lightweight (`Task.Delay`)


Conclusions
-----------

Here are some lessons learned from all the experiments above:

- Be prepared for 1-3 seconds cold starts even for the smallest Functions
- Stay on V1 of runtime until V2 goes GA unless you don't care about perf
- .NET precompiled and Javascript Functions have roughly same cold start time
- Minimize the amount of dependencies, only bring what's needed

Do you see anything weird or unexpected in my results? Do you need me to dig deeper on other aspects?
Please leave a comment below or ping me on twitter, and let's sort it all out.

Conclusions2
----------

Getting back to the experiment goals, there are several things that we learned.

For low-traffic apps with sporadic requests it makes sense to setup a "warmer" timer
function firing every 10 minutes or so to prevent the only instance from being recycled.

However, scale-out cold starts are real and I don't see any way to prevent them from
happening.

When multiple requests come in at the same time, we might expect some of them to hit
a new instance and get slowed down. The exact algorithm of instance reuse is not
entirely clear.

Same instance is capable of processing multiple requests in parallel, so there are
possibilities for optimization in terms of routing to warm instances during the
provisioning of cold ones. 

If such optimizations happen, I'll be glad to re-run my tests and report any noticeable
improvements.

Stay tuned for more serverless perf goodness!