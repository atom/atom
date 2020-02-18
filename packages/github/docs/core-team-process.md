# Core @atom/github team process

This guide describes the way that the core @atom/github team works together day-to-day.

We value:

* **Trust** in each other's judgement and instincts.
* Feeling **included** and present among the team.
* Respect for **differing individual preferences** in social needs and tolerance for practices like pair programming.
* Acknowledgement that **we are distributed geographically** and the differences in timezone and daily schedules that that implies.
* **Continuous improvement** to find what works best for the team we are today and for the immediate problem at hand, and to adjust as both of these change fluidly.

## Organization

When we plan, we choose to pursue _a single task_ as a single team, rather than distributing tasks among ourselves from a queue and working on independent tasks in parallel. This is intended to increase the amount and quality of communication we can share in chat and in synchronous meetings: it's much easier to maintain an ongoing technical conversation when all participants share the mental context of a unified goal.

This does not mean that we all pair program all the time. We do get value from pair programming but this is not always practical or desirable. Pair programming may be chosen independently from the methods below -- functionally, the pair becomes one "developer" in any of the descriptions.

## Concepts

### 1. Seams

Divide the issue at hand among the team along the abstraction layers in our codebase. Each developer continuously negotiates the interface with neighboring layers by an active Slack conversation, correcting their direction based on feedback. Developers push their work as commits to a single shared branch, documenting and coordinating overall progress in a shared pull request.

> Example: developer A implements changes to the model, developer B implements the view component, and developer C implements the controller methods. Developer B writes code as though the model and controller are already complete, using sinon mocks for tests and communicating the view's needs as they arise. Developer C proceeds similarly with the controller methods. Developer A gives feedback on the feasibility of requested model functionality from both A and B and negotiates method names and property names. When developer C leaves for the day or takes time off, developers A and B proceed, leaving asynchronous notes for developer C as pull request comments for them to catch up on when they come back online.

:+1: _Advantages:_

* Encourages high-touch, continuous conversation involving and relevant to the full team.
* Resilient to time off and asynchronicity.
* Minimizes the need to context switch up and down abstraction layers while working.

:-1: _Disadvantages:_

* Diminishes variety of work done by any individual developer, which could become boring.
* Reduces the familiarity developed by any single developer to a single abstraction layer within the codebase.
* Timing may become difficult. It's possible that one "seam" may take much more time to implement than the others, which could lead to a bottleneck.
* Some efforts will not be decomposable into easily identified seams for division of labor.

### 2. Pull request hierarchy

The problem at hand is decomposed into a queue of relatively independent tasks to complete. A primary branch and a pull request are created to accumulate the full, shippable solution on full completion. Each developer creates an individual branch from the primary one and pushes commits as they work, opening a pull request that targets the primary branch as a base. Developers review one another's sub-pull requests with pull request reviews and coordinate merges to the primary until all tasks are complete, at which point the primary pull request is merged.

> Example: developers A and B create and push a parent branch `a-b/big-feature` and open pull request 123 with an overall problem definition and a checklist of tasks to complete. Developer A creates branch `a/user-story-a` from `a-b/big-feature` and opens pull request 444 while developer B works on branch `b/user-story-b` and pull request 555. Developer A reviews and merges pull request 555 while developer B moves on to branch `b/user-story-c`, then developer B reviews and merges pull request 444. Developers A and B continuously calibrate the task list to represent the remaining work. Once the task list is complete, the primary pull request 123 is merged and the feature is shipped.

:+1: _Advantages:_

* Makes it less likely that one developer may block the others when their tasks take longer than expected.
* More asynchronous-friendly.
* Leaves a trail of documentation for each task.

:-1: _Disadvantages:_

* Decomposing tasks well is challenging.
* Less communication-friendly; we risk a developer on a long-running task feeling isolated.
* Merging closely related pull requests requires careful coordination. Merge conflicts will be frequent.

### 3. Hand-offs

In this method, each developer (or pair) tackles a single problem in serial during their working hours. When the next developer becomes available, the previous one writes a summary of their efforts and progress in a hand-off, synchronously and interactively in a dedicated Slack channel. Once the next developer is caught up, they make progress and hand off to the next, and so on.

> Example: developer A logs in during their morning and works for a few hours on the next phase of a feature implementation. They make some progress on the model, but don't progress the controller beyond some stubs and don't get a chance to touch the view at all. When developer B logs in, developer A shares their progress with a conversation in Slack until developer B is confident that they understand the problem's current state, at which point developer B begins working and making commits to the feature branch. Developer B implements the view, correcting and adding some methods to the model as needed. Finally, developer C logs in, and developers A and C pair to write the controller methods. They update Slack with their progress as they wrap up describing the changes that they've made together. Developer B returns the next day, puts the finishing touches on the tests, writes or refines some documentation on the new code, and merges the pull request.

:+1: _Advantages:_

* Maximizes knowledge transfer among participants: everyone gets a chance to work on and become familiar with all the system's layers.
* Ensures that nobody needs to wait when somebody else is stuck.
* Handles differences in timezones gracefully.

:-1: _Disadvantages:_

* Overlap times need to be negotiated, either by pair programming or using another method to divvy up work. If we all overlap significantly it functionally decays to one of the other solutions.
* Hand-offs are high communication touchpoints, but the rest of the time is more isolated.

### 4. Dark shipping

Incrementally create and test new hierarchies of React components and model classes in pull requests that are merged _before_ they are referenced from the "live" package root.

:+1: _Advantages:_

* Enables us to merge pull requests into master more frequently
* Keeps code reviews focused and tractable
* Prevents pull requests from drifting too far from master and being a pain to merge

:-1: _Disadvantages:_

* May cause an accumulation of dead code
* The merge points may not be obvious in some efforts

### 5. Feature flags

Use a package configuration setting to control when features under development are loaded.

:+1: _Advantages:_

* Enables us to merge pull requests into master more frequently
* Makes it easier for developers outside of the core team to try out new features and provide feedback

:-1: _Disadvantages:_

* Requires some up-front infrastructure work to put the mechanisms in place
* Needs some discipline in removing old code, so we don't accumulate flags without bound

## All together

Each set of developers who are online synchronously can divide work into Seams. As that set changes when people come online and drop offline, we use Handoffs to pass context along. Remaining tasking is tracked in a dedicated, loosely-managed feature project linked from the feature request PR.

As we work, we push commits to a common branch, against a common pull request. Depending on the feature under construction, we either Dark Ship code in an early state or hide its entry points behind a Feature Flag.

For a concrete example:

1. Developer A comes online first and works solo for a few hours, shifting up and down the abstraction stack.
2. When developer B comes online, they get caught up on the work developer A has pushed so far and chats to sync up on progress. Developers A and B divvy up areas of work to focus on for the next few hours, chatting in Slack as they go.
3. Developers C and D come online next. Developers A and B bring them up to speed and subdivide the work underway further. Maybe C and D pair on the view work while A and B work on the model and controller.
4. When D is done for the day, they summarize how far they got on their bit. One of the other three catches up, picks up where D left off, and keeps it going. C does the same when they log off.
5. When A and B are finishing up they leave a quick writeup of their collective progress.
7. The next morning, developer A reads the diff and the writeup and gets traction on continuing through their day.
8. ...and repeat. ♻️

## Ambient socialization

In addition to these strategies, we can take advantage of other technologies to help us feel connected in an ambient way.

* We all open [Teletype](https://teletype.atom.io/) portals as we work, even when not actively pairing, and share the URL in Slack. We join each other's portals in a window on a separate Atom window and watch each other's progress as a background process.
* We stream to the world on [Twitch](https://twitch.tv) as we work. We sometimes jump into each other's streams to chat or catch up.
