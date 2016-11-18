---
layout: draft
title: Refactoring
date: 2015-10-14
tags: []
teaser: TODO
---
Let's say we have a service which receives some scanned documents and put them into the database. You are new to the code but you got an assignment to fix a bug or implement a change request. Here is the code that you see:

``` cs
documentRepository.SaveDocument(
    document,
    @doc =>
    {
        if (@doc.HasContent && @doc.Id > 0)
        {
            if (@doc.WorkflowGUID != Guid.Empty)
            {
                messageRepository.AddJobDocument(@doc.WorkflowGUID, @doc.GlobalBatchId);
            }

            notificationHub.EnqueuePacket(packetFactory.GetDocumentScanPacket(@doc));
        }
    });
```

So, what do we see from this piece of code?

1. We call document repository to save the document to the database. This one is straightforward.

2. We also pass a callback which does some extra actions. This callback is probably called when save operation succeeds.

3. If some conditions are met, we also add a job document to message repository.

4. We send a package to notification hub.

The overall picture is probably clear, but a lot of questions appear once you start digging into details:

1. Is the callback run on success or also on failure? The `@doc.Id > 0` check looks like success/failure check.

2. What is the `@doc` variable? In IntelliSense we can see that it has the same type as `document`. Is it a reference to modified `document`? Is the `document` itself modified? Which properties are changed and which are not?

3. Is the callback called synchronosly? We don't remember having async code in repositories, but why is it a callback then? Can I use properties of `@doc` outside the callback (e.g. to return something from the method).

These questions are killing readability. It appears that you have to go and read the actual implementation of `DocumentRepository` to make any kind of significant change or judgement. Let's see which principles are violated by this implementation:

1. Command-query separation. `SaveDocument` is the command but it also changes and returns some data.

2. Immutability. It's not totally clear from the code above, but the `document` is actually modified by the repository.

3. No simple imperative flow. The order of code execution is unclear.

4. Mixture of domain logic and orchestration in one block.

Here is my attempt to improve the code. First, let's get rid of the callback:

``` cs
var documentIds = documentRepository.SaveDocument(document);
if (document.HasContent && documentIds.Id > 0)
{
    if (documentIds.WorkflowGUID != Guid.Empty)
    {
        messageRepository.AddJobDocument(documentIds.WorkflowGUID, document.GlobalBatchId);
    }

    notificationHub.EnqueuePacket(packetFactory.GetDocumentScanPacket(document));
}
```