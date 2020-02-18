# Long-term vision

This directory contains notes on ideas for the longer-term vision of the @atom/github-package core team for this package. We intend to use the documents in this space to:

* Articulate the objectives we have for the package as a whole. The features we add should contribute to a cohesive experience, not be an amalgamation of unrelated things that sounded cool at the time.
* Delineate our boundaries. We should be able to reference these documents to say why we _won't_ work on a feature in addition to why we will.
* Incubate that long tail of ideas we're excited about that we aren't ready to write in [Feature Request](../how-we-work.md#new-features) form yet.
* Inform our quarterly and weekly planning cycles. We intend to revisit these often as part of our team's planning cadence, both to keep them accurate and timely and to cherry-pick from when we can.
* Share our vision with the world and let the world share its vision with us. :earth_americas:

## So when are you building all this stuff then

The inclusion of a feature here is **not** a commitment to our delivery of said feature on any particular timeline.

Some we may never implement. Some may be unrecognizable from their descriptions here. Others we may deliver in a matter of months. We don't know yet! This is the place where we put ideas that we explicitly haven't fully plumbed the depths of and prioritized against our other work. It turns out that it's a lot easier to write a bunch of markdown than it is to get all of the code working.

If you want to see our plans for what we _are_ working on in the very near term, at various layers of granularity:

* Our [short-term roadmap project](https://github.com/atom/github/projects/8) is where we track the issues and pull requests we're working on a day-to-day basis.
* The [`docs/focus` directory in `atom/atom`](https://github.com/atom/atom/tree/master/docs/focus) contains weekly progress and planning updates from the entire core Atom team, including us.
* Our intermediate-scope plans are listed in [the `#github-package` section of the focus README.](https://github.com/atom/atom/tree/master/docs/focus#github-package)

## This sounds cool, how can I help?

I'm glad you asked!

The first step in tackling any of these would be to [submit a Feature Request](../how-we-work.md#new-features). The ideas described here are very rough - before we can get to work shipping any of them, we need to reach consensus on scope, graphic design direction, user experience, and many other details. If one of our bullet points sparks your imagination, start a draft of the writeup following [the template we provide](https://github.com/atom/github/blob/master/docs/feature-requests/000-template.md). It doesn't have to be complete, but it's a great way to get involved and start a more in-depth conversation.

If that sounds like not much fun to you, and you'd rather just write some code: try making a proof-of-concept as a separate Atom package! Tell us about it in an issue and show us what you've done. If we like it and you're okay with it, we can help you merge it into this package, or we can help provide the proper plumbing to make it an independent thing.

## Table of Contents

* [`who.md`: Our target audience](./who.md)
* [`git.md`: Git integration](./git.md)
* [`github.md`: GitHub integration](./github.md)
* [`ideas.md`: Proto Feature Request incubator](./ideas.md)
