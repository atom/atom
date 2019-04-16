# Atom launch behavior

All examples use the following directory structure:

```
/a/1.md
/a/2.md
/b/3.md
```

For brevity, the scenarios below are described using the following notation:

| Notation | Meaning |
| -- | -- |
| [] | single Atom window with no project roots or open editors |
| [/a,/b] | single Atom window with two project roots (`/a` and `/b`) and no open editors |
| [/a 1.md,2.md] | single Atom window with one project root (`/a`) and two open editors `/a/1.md` and `/a/2.md` |
| [ 3.md] | single Atom window with no project roots and one open editor `/b/3.md` |
| [/a 1.md] [/b 3.md] | two Atom windows:<br/>the first-opened has one project root (`/a`) and one open editor `/a/1.md`<br/>the second-opened has one project root (`/b`) and one open editor `/b/3.md`. |

Changes in behavior from the immediately preceding version (the column to the immediate left) are marked with :new:

## CLI actions

### No open windows

When no Atom windows are open, CLI actions have the following outcomes:

| Action | Outcome (<=1.35.1) | Outcome (1.36.0) | Outcome (1.36.1) |
| --- | --- | --- | --- |
| `atom /a/1.md`              | [/a 1.md] | [ 1.md] :new: | [ 1.md] |
| `atom /a`                   | [/a]      | [/a]          | [/a]    |
| `atom --add /a/1.md`        | [/a 1.md] | [ 1.md] :new: | [ 1.md] |
| `atom --add /a`             | [/a]      | [/a]          | [/a]    |
| `atom --new-window /a/1.md` | [/a 1.md] | [ 1.md] :new: | [ 1.md] |
| `atom --new-window /a`      | [/a]      | [/a]          | [/a]    |

### Open window, no project roots

With the following starting state:

> []

| Action | Outcome (<=1.35.1) | Outcome (1.36.0) | Outcome (1.36.1) |
| --- | --- | --- | --- |
| `atom /a/1.md`              | [/a 1.md] | [] [ 1.md] :new: | [ 1.md] :new:|
| `atom /a`                   | [/a]      | [] [/a]          | [] [/a]      |
| `atom --add /a/1.md`        | [/a 1.md]    | [ 1.md] :new:    | [ 1.md]      |
| `atom --add /a`             | [/a]         | [/a]             | [/a]         |
| `atom --new-window /a/1.md` | [] [/a 1.md] | [] [ 1.md] :new: | [] [ 1.md]   |
| `atom --new-window /a`      | [] [/a]      | [] [/a]          | [] [/a]      |

### Open window, project root

With the following starting state:

> [/a]

| Action | Outcome (<=1.35.1) | Outcome (1.36.0) | Outcome (1.36.1) |
| --- | --- | --- | --- |
| `atom /a/1.md`              | [/a 1.md]      | [/a 1.md]          | [/a 1.md]    |
| `atom /a`                   | [/a]           | [/a]               | [/a]         |
| `atom /b/3.md`              | [/a 3.md] | [/a] [ 3.md] :new: | [/a] [ 3.md] |
| `atom /b`                   | [/a] [/b]      | [/a] [/b]          | [/a] [/b]    |
| `atom --add /a/1.md`        | [/a 1.md]      | [/a 1.md]          | [/a 1.md]    |
| `atom --add /a`             | [/a]           | [/a]               | [/a]         |
| `atom --add /b/3.md`        | [/a,/b 3.md]   | [/a 3.md] :new:    | [/a 3.md]    |
| `atom --add /b`             | [/a,/b]        | [/a,/b]            | [/a,/b]      |
| `atom --new-window /a/1.md` | [/a] [/a 1.md] | [/a] [ 1.md] :new: | [/a] [ 1.md] |
| `atom --new-window /a`      | [/a] [/a]      | [/a] [/a]          | [/a] [/a]    |
| `atom --new-window /b/3.md` | [/a] [/b 3.md] | [/a] [ 3.md] :new: | [/a] [ 3.md] |
| `atom --new-window /b`      | [/a] [/b]      | [/a] [/b]          | [/a] [/b]    |

### Open windows, one with a project root and one without

> [/a] []

| Action | Outcome (<=1.35.1) | Outcome (1.36.0) | Outcome (1.36.1) |
| --- | --- | --- | --- |
| `atom /a/1.md`              | [/a 1.md] []      | [/a 1.md] []          | [/a 1.md] []       |
| `atom /a`                   | [/a] []           | [/a] []               | [/a] []            |
| `atom /b/3.md`              | [/a] [/b 3.md]    | [/a] [] [ 3.md] :new: | [/a] [ 3.md] :new: |
| `atom /b`                   | [/a] [/b]         | [/a] [] [/b]          | [/a] [] [/b]       |
| `atom --add /a/1.md`        | [/a 1.md] []      | [/a 1.md] []          | [/a 1.md] []       |
| `atom --add /a`             | [/a] []           | [/a] []               | [/a] []            |
| `atom --add /b/3.md`        | [/a] [/b 3.md]    | [/a] [ 3.md] :new:    | [/a] [ 3.md]       |
| `atom --add /b`             | [/a] [/b]         | [/a] [/b]             | [/a] [/b]          |
| `atom --new-window /a/1.md` | [/a] [] [/a 1.md] | [/a] [] [ 1.md] :new: | [/a] [] [1.md]     |
| `atom --new-window /a`      | [/a] [] [/a]      | [/a] [] [/a]          | [/a] [] [/a]       |
| `atom --new-window /b/3.md` | [/a] [] [/b 3.md] | [/a] [] [ 3.md] :new: | [/a] [] [ 3.md]    |
| `atom --new-window /b`      | [/a] [] [/b]      | [/a] [] [/b]          | [/a] [] [/b]       |

## File manager integration actions

### No open windows

When no Atom windows are open, file manager context operations have the following outcomes:

| Action | Outcome (<=1.35.1) | Outcome (1.36.0) | Outcome (1.36.1) |
| --- | --- | --- | --- |
| Click on `/a/1.md` | [/a 1.md] | [ 1.md] :new: | [ 1.md] |
| Click on `/a`      | [/a]      | [/a]          | [/a]    |

### Open window, no project roots

With the following starting state:

> []

| Action | Outcome (<=1.35.1) | Outcome (1.36.0) | Outcome (1.36.1) |
| --- | --- | --- | --- |
| Click on `/a/1.md` | [/a 1.md] | [] [ 1.md] :new: | [ 1.md] :new: |
| Click on `/a`      | [/a]      | [] [/a]          | [] [/a]       |

### Open window, project root

With the following starting state:

> [/a]

| Action | Outcome (<=1.35.1) | Outcome (1.36.0) | Outcome (1.36.1) |
| --- | --- | --- | --- |
| Click on `/a/1.md` | [/a 1.md]      | [/a 1.md]          | [/a 1.md]    |
| Click on `/a`      | [/a]           | [/a]               | [/a]         |
| Click on `/b/3.md` | [/a 3.md]      | [/a] [ 3.md] :new: | [/a] [ 3.md] |
| Click on `/b`      | [/a] [/b]      | [/a] [/b]          | [/a] [/b]    |

### Open windows, one with a project root and one without

> [/a] []

| Action | Outcome (<=1.35.1) | Outcome (1.36.0) | Outcome (1.36.1) |
| --- | --- | --- | --- |
| Click on `/a/1.md` | [/a 1.md] []      | [/a 1.md] []          | [/a 1.md] []       |
| Click on `/a`      | [/a] []           | [/a] []               | [/a] []            |
| Click on `/b/3.md` | [/a] [/b 3.md]    | [/a] [] [ 3.md] :new: | [/a] [ 3.md] :new: |
| Click on `/b`      | [/a] [] [/b]      | [/a] [] [/b]          | [/a] [] [/b]       |
