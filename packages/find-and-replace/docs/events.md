# Events specification

This document specifies all the data (along with the format) which gets sent from the Find and Replace package to the GitHub analytics pipeline. This document follows the same format and nomenclature as the [Atom Core Events spec](https://github.com/atom/metrics/blob/master/docs/events.md).

## Counters

Currently Find and Replace does not log any counter events.

## Timing events

#### Time to search on a project

* **eventType**: `find-and-replace-v1`
* **metadata**

  | field | value |
  |-------|-------|
  | `ec` | `time-to-search`
  | `ev` | Number of found results
  | `el` | Search system in use (`ripgrep` or `standard`)

## Standard events

Currently Find and Replace does not log any standard events.