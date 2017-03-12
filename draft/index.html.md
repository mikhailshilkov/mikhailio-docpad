---
layout: post
title: Azure Functions as a Facade for Azure Monitoring
date: 2017-03-10
tags: ["azure", "azure functions", "metrics", "monitoring", "prtg"]
---

Azure Functions is a Function-as-a-Service offering from Microsoft Azure cloud.
Basically, Azure Function is a piece of code which gets executed by Azure
every time a specific event happens. The environment manages deployment,
event triggers and scaling for you. This approach is often reffered as 
Serverless.

In this post I will describe one use case for Azure Functions: we implemented
a number of functions as a proxy layer between our operations & monitoring 
tool and Azure metric collection API.

Problem
-------

Automated monitoring and alerting are crucial in order to ensure 24x7 smooth 
operations of our business-critical applications. We host applications both
on-premise and in Azure cloud, and we use a single set of tools for monitoring
across this hybrid environment.

Particularly, we use [PRTG Network Monitor](https://www.paessler.com/prtg)
to collect all kinds of metrics about the health of our systems and produce
both real-time alerts and historic trends.

A unit of monitoring in PRTG is called "sensor". Each sensor polls a specific
data source to collects the current value of a metric. The data source can
be a performance counter, a JSON value in HTTP response, a SQL query and so on.

The problem is that there is no PRTG sensor for Azure metrics out of the box.
It might be possible to implement a sensor with custom code, e.g. in PowerShell,
but it would be problematic in two ways (at least):

1. The custom code sensors are cumbersome to develop and maintain.
2. We would have to put sensitive information like Azure API keys and 
connection strings to PRTG.

Solution Overview
-----------------

To overcome these problems, we introduced an intermediate layer, as shown
on the following picture:

![PRTG to HTTP to Azure](/prtg-http-azure.png)

We use PRTG HTTP XML/REST sensor type. This sensor queries a given HTTP endpoint,
parses the response as JSON and finds a predefined field. This field is then
used as sensor value. It makes 30 seconds to setup such sensor in PRTG. 

The HTTP endpoint is hosted inside Azure. It provides a facade for metric
data access. All the sensitive information needed to access Azure metrics 
API is stored inside Azure configuration itself. The implementation knows 
which Azure API to use to get a specific metric, and it hides those 
complications from the client code.

Azure Functions
---------------

We chose Azure Functions as the technology to implement and host such HTTP
facade.

TODO: why?

Here is how the whole setup works:

![PRTG to HTTP to Azure](/prtg-http-azure.png)

1. Every X minutes (configured per sensor), PRTG makes an HTTP request 
to a predefined URL. The request includes an Access Key as a query parameter 
(the key is stored in sensor URL configuration). Each access key enables 
access to just one endpoint and is easily revoke-able.

2. For each Metric type there is an Azure Function which is listening for 
HTTP requests from PRTG. Azure only authorizes requests with valid Access Key.

3. Based on query parameters of the request, Azure Function retrieves a proper 
metric value from Azure management API. Depending on the metric type, this 
is accomplished with Azure .NET SDK or by sending a raw HTTP request to 
Azure REST API. 

4. Azure Function parses the response from Azure API and converts it to 
just the value which is requested by PRTG. 

5. The function returns a simple JSON object as HTTP response body. PRTG 
parses JSON and extract the numeric value, and saves it into sensor history.

At the time of writing, we have 13 sensors served by 5 Azure Functions:

![PRTG to HTTP to Azure](/prtg-http-azure.png)

I describe each function below.

Service Bus Queue Size
----------------------

The easiest function to implement is the one which gets the amount of 
messages in the backlog of a given Azure Service Bus queue. The 
`function.json` file configures input and output HTTP bindings, including
two parameters to derive from the URL: account (namespace) and queue name:

``` json
{
  "bindings": [
    {
      "authLevel": "function",
      "name": "req",
      "type": "httpTrigger",
      "direction": "in",
      "route": "Queue/{account}/{name}"
    },
    {
      "name": "$return",
      "type": "http",
      "direction": "out"
    }
  ],
  "disabled": false
}
```

The C# implementation uses standard Service Bus API and a connection string
from App Service configuration to retrieve the required data. And then returns
a dynamic object, which will be converted to JSON by Function App runtime.

``` cs
#r "Microsoft.ServiceBus"

using System.Net;
using Microsoft.ServiceBus;

public static object Run(HttpRequestMessage req, string account, string name)
{
    var connectionString = Environment.GetEnvironmentVariable("sb-" + account);
    var nsmgr = NamespaceManager.CreateFromConnectionString(connectionString);
    var queue = nsmgr.GetQueue(name);
    return new 
    {
        messageCount = queue.MessageCountDetails.ActiveMessageCount,
        dlq = queue.MessageCountDetails.DeadLetterMessageCount
    };
}
```

And this is all the code required to start monitoring the queues!

Service Bus Queue Statistics
----------------------------

In addition to queue backlog and dead letter queue size, we wanted to see
some queue statistics like amount of incoming and outgoing messages per
period of time. The corresponding API exists, but it's not that straightforward,
so I described the whole approach in a separate post: 
[Azure Service Bus Entity Metrics .NET APIs](http://mikhail.io/2017/03/azure-service-bus-entity-metrics-dotnet-apis/).

In my Azure Function I'm using the NuGet package that I mentioned in the post.
This is accomplished by adding a `project.json` file:

``` json
{
  "frameworks": {
    "net46":{
      "dependencies": {
        "MikhailIo.ServiceBusEntityMetrics": "0.1.2"
      }
    }
   }
}
```

The `function.json` file is similar to the previous one, but with one added
parameter called `metric`. I won't repeat the whole file here.

The Function implementation loads a certificate from the store, calls 
metric API and returns the last metric value available:

``` cs
using System.Linq;
using System.Security.Cryptography.X509Certificates;
using MikhailIo.ServiceBusEntityMetrics;

public static DataPoint Run(HttpRequestMessage req, string account, string name, string metric)
{
    var subscription = Environment.GetEnvironmentVariable("SubscriptionID");
    var thumbprint = Environment.GetEnvironmentVariable("WEBSITE_LOAD_CERTIFICATES");

    X509Store certStore = new X509Store(StoreName.My, StoreLocation.CurrentUser);
    certStore.Open(OpenFlags.ReadOnly);

    X509Certificate2Collection certCollection = certStore.Certificates.Find(
        X509FindType.FindByThumbprint,
        thumbprint,
        false);

    var client = new QueueStatistics(certCollection[0], subscription, account, name);
    var metrics = client.GetMetricSince(metric, DateTime.UtcNow.AddMinutes(-30));
    return metrics.LastOrDefault();
}
```

Don't forget to set `WEBSITE_LOAD_CERTIFICATES` setting to your certificate 
thumbprint, otherwise Function App won't load it.

Web App Instance Count
----------------------

Users Online (Application Insights)
-----------------------------------

Azure Health
------------

Conclusion
----------