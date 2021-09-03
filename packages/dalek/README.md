# dalek

**EXTERMINATEs** core packages installed in `~/.atom/packages`.

## Why worry?

When people install core Atom packages as if they are community packages, it can cause many problems that are very hard to diagnose. This package is intended to notify people when they are in this precarious position so they can take corrective action.

## I got a warning, what do I do?

1. Note down the packages named in the notification
1. Exit Atom
1. Open a command prompt
1. For each package named in the notification, execute `apm uninstall [package-name]`
1. Start Atom again normally to verify that the warning notification no longer appears

## I have more questions. Where can I ask them?

Please feel free to ask on [the official Atom message board](https://github.com/atom/atom/discussions).
