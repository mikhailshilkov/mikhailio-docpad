---
layout: post
title: AWS Lambda Warmer as Pulumi Component
date: 2018-08-01
tags: ["AWS", "AWS Lambda", "Pulumi", "Serverless", "Cold Starts"]
teaserImage: teaser.jpg
description: Provisioning AWS Lambda and API Gateway with Pulumi, examples in 5 programming languages
---

Out of curiosity, I'm currently playing with cold starts of Function-as-a-Service platforms of major cloud providers. Basically,
if a function is not called for several minutes, the cloud instance behind it might be recycled, and then the next request will
take longer because a new instance will need to be provisioned.

Recently, Jeremy Daly [posted](https://www.jeremydaly.com/lambda-warmer-optimize-aws-lambda-function-cold-starts/) a nice
article about the proper way to keep AWS Lambda instances "warm" to (mostly) prevent cold starts with minimal overhead.
Chris Munns [endorsed](https://twitter.com/chrismunns/status/1017777028274294784) the article, so we know it's the right way.

The amount of actions to be taken is quite significant:

- Define a CloudWatch event which would trigger every 5 minutes
- Bind this event as trigger for your Lambda
- Inside the Lambdra, detect that current invocation is triggered by our CloudWatch event
- If so, short-circuit the execution and return immediately. Otherwise, run the normal workload
- (Bonus point) If you want to keep multiple instances alive, do some extra dancing with calling itself N times in parallel,
provided by an extra permission to do so.

Pursuing Reusability
--------------------

To simplify this for his reader, Jeremy was so kind to create 

- Create an NPM package which you can install and then call to a warmer function 
- Provide SAM and Serverless Framework templates to automate Cloud Watch integration

Thanks Jeremy!

Those are still two distict steps: writing the node (JS + NPM) and provisioning the cloud resources (YAML). There are some
drawbacks to that:

- You need to change two parts, which don't look like each other
- They have to work in sync, e.g. Cloud Watch even must provide the right payload for the handler
- There's still some boilerplate

Pulumi Components
-----------------

Pulumi takes a different approach. You can (but don't have to) blend the application code and infrastructure management code
into one cohesive cloud application.

Related resources can be combined together into reusable components, which hide repetitive stuff behind code abstractions.

One way to define an AWS Lambda with Typescript in Pulumi is the following:

``` typescript
const handler = (event: any, context: any, callback: (error: any, result: any) => void) => {
    const response = {
        statusCode: 200,
        body: "Cheers, how are things?"
      };
    
    callback(null, response);
};

const lambda = new aws.serverless.Function("my-function", { /* options */ }, handler);
```

The processing code `handler` is just passed as parameter to infrastructure code as a parameter.

So, if I wanted to make reusable API for an "always warm" function, how would it look like?

Simple, I just want to be able to do that:

``` typescript
const lambda = new mylibrary.WarmLambda("my-warm-function", { /* options */ }, handler);
```

Cloud Watch? Event subscription? Short-circuiting? They are implementation details!

Warm Lambda
-----------

Here is how to implement such component. The declaration starts with a Typescript class:

``` typescript
export class WarmLambda extends pulumi.ComponentResource {
    public lambda: aws.lambda.Function;

    // Implementation goes here...
}
```

We expose the raw Lambda Function object, so that it could be used for further bindings and retrieving outputs.

The constructor accepts the same parameters as `aws.serverless.Function` provided by Pulumi:

``` typescript
constructor(name: string,
        options: aws.serverless.FunctionOptions,
        handler: aws.serverless.Handler,
        opts?: pulumi.ResourceOptions) {

    // Subresources are created here...
}
```

We start resource provisioning by creating the CloudWatch rule to be triggered every 5 minutes:

``` typescript
const eventRule = new aws.cloudwatch.EventRule(`${name}-warming-rule`, 
    { scheduleExpression: "rate(5 minutes)" },
    { parent: this, ...opts }
);
```

Then goes the cool trick. We substitute the user-provided handler with our own "outer" handler. This handler closes
over `eventRule`, so it can use the rule to identity the warm-up call coming from CloudWatch. If such is identifier,
the handler short-cicuits to the callback. Otherwise, it passes the event over to the original handler:

``` typescript
const outerHandler = (event: any, context: aws.serverless.Context, callback: (error: any, result: any) => void) =>
{
    if (event.resources && event.resources[0] && event.resources[0].includes(eventRule.name.get())) {
        console.log('Warming...');
        callback(null, "warmed!");
    } else {
        console.log('Running the real handler...');
        handler(event, context, callback);
    }
};
```

It time to bind both `eventRule` and `outerHandler` to a new serverless function:

``` typescript
const func = new aws.serverless.Function(
    `${name}-warmed`, 
    options, 
    outerHandler, 
    { parent: this, ...opts });
this.lambda = func.lambda;            
```