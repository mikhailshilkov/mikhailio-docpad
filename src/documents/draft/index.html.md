---
layout: draft
title: Refactoring
date: 2015-07-18
tags: ["refactoring"]
---
Test
<pre><code>
    public ConsumptionRate GetFuelConsumptionForCardId(IEnumerable<KPIHistoryEntry> items, int cardId)
    {
        var entries = items.Where(c => c.Driver.CardId == **cardId**);
        return new ConsumptionRate(entries.Select(i => i.TotalFuelUsed).Sum(), &lt;s&gt;entries.Select(i => i.TotalDistance).Sum()&lt;/s&gt;);
    }
</code></pre>
Test