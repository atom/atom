# Our audience

_Who are the intended users of this package?_ An important prerequisite to determine what to build and when is to know who you're building for. When you're working on developer tools it's easy to fall into the trap of overfitting to your own workflow and processes. Keeping the full range of our user base in mind while designing can help ensure that the features we build are useful to as many people as possible.

We can segment our user base along the following axes:

## Git familiarity

### Beginning git users

This group includes both new developers (university CS students, precocious high schoolers, professionals in other fields who are interested in joining tech) and those in tech-adjacent professions (technical writers, support).

As a tool, command-line git is very punishing to those who attempt to learn it "in passing" while they're really trying to accomplish something else. It takes a few days of focused study to really click, and until you spend it it's a source of great frustration.

We can help by providing a _gentler introduction to git_ to increase the intuitiveness of those early days. Ideally, someone with no git experience should be able to make a contribution to a project without having to take a class or read a book first. Furthermore, we can _set learners up for future success_ by providing hints and nudges and using terminology that will click later.

My dream is to make an answer to "so, how do I use git" be "oh, just use Atom to get started".

### Experienced git users

These are our users who already use git daily and know command-line incantations inside and out. We want to remain appealing enough to be useful to users who are already comfortable elsewhere, even if only sometimes.

We can serve these users by _reducing context switches_ for the most common tasks. Reducing the number of times you need to change your active desktop window is a productivity win.

The terminology and verbiage we use throughout the package can help _preserve the usefulness of existing knowledge_. Someone who's comfortable with git at the command line should be able to predict at a glance what any given UI action will take.

Finally, we can also introduce _novel git affordances_ that aren't easy to accomplish at the command-line to go above and beyond and give people some extra flair and flash.

## Software development context

Note that these three are often the same people at different times.

### Professionals

These are developers who work within established teams, who often have processes and procedures in place, sometimes imposed externally. These users sometimes have strict needs about branch workflows, linters and hooks, merging vs. rebasing, and mechanisms for tagging and releasing. We can serve these developers best by ensuring we have _maximum flexibility_ so they can fit our tooling to their existing processes with minimal fuss. Providing rich _extensibility_ also helps in these contexts, because it would allow teams to overlay complex workflows on top of our basic building blocks with internal packages and tools.

### Open-source maintainers

Other developers live in an open-source world, shepherding contributions from others, giving feedback, and merging or rejecting pull requests. Maintainers would appreciate features that allow them to _investigate and triage work_ across large sets of repositories and pull requests and _maintain situational awareness_.

### Hobbyists

Finally, users who tinker with personal projects in their free time should have _minimal friction_ to being able to set up and get code out. These users are likely to benefit from being able to work with little ceremony and few obstacles.
