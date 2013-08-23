# API Docs Proposal

## Goals
- Distinguish between **public** and **private** methods
- Generate a HTML documentation of the public API that can be browsed online.
- Provide *relevant*, *non-obvious* explanation beyond what can be inferred from
  method signatures.
- Provide type-information for what is otherwise a dynamically-typed language.
- Effort should scale proportionately to the amount of information being
  provided. The conventions should enforce minimal conventions for simple
  methods, while simultaneously providing robust conventions when deeper
  explanation is needed.
- Clutter source files as little as possible

## Proposal

Basic API documentation is a combination of a **visibility declaration**, one or
more **type signatures**, and a short string of informal, non-obvious
**explanatory text**. Expanded documentation can be also added, separated by a
newline. All explanatory text is in markdown format, with special links to
other code entities wrapped in `{}`, like `{Array::splice}`.

### Examples

Minimal requirement for public methods: A visibility declaration and a type
signature. Use this when the method's behavior can be reasonably inferred from its
name and signature.

```coffee-script
# Public :: (Point) -> Cursor
addCursorAtBufferPosition(bufferPosition) -> # ...
```

Common case: Includes the visibility and type declarations, plus a short,
non-obvious explanation. Note the empty type signature representing a method that
takes no arguments and has no return value.

```coffee-script
# Public :: ->
# Reduces multiple selections to a single, empty selection. Only the *last*
# selection is retained.
clearSelections: -> # ...
```

Expanded approach: Includes an expanded description of individual attributes or
other details in markdown format. Also note the optional parameter name in
the type signature, since for implementation reasons we were unable to include
it in the method signature in the source.

```coffee-script
# Public :: ([options :: Object], [Function]) ->
# If passed a function, it executes the function with merging suppressed,
# then merges intersecting selections afterward.
#
# - options
#   See {EditSession::setSelectedBufferRange} for a description of options.
#
mergeIntersectingSelections: (args...) -> # ...
```

Multiple type signatures: Each type signature can also include its own
description or expanded commentary.

```coffee-script
# Public: Creates a replicated document instance based on the given object.
#
# :: (Document) -> Document
# If the argument is already a Document, it will be returned unchanged.
#
# :: (Array, [Object]) -> SharedArray
# :: (Object, [Object]) -> SharedMap
@create: (value, options={}) -> # ...
```

### Type Signatures

The goal of a type signature is to express type information and to provide
parameter names in cases where they can't be provided in the code.

A fully-qualified type signature for the `Array::splice` method would look like
this. Note that the type qualifier symbol should always be surrounded with
whitespace to distinguish it from CoffeeScripts prototype syntax. There
will rarely be a need to spell a signature out so completely, but this is here
for reference.

```coffee-script
# Array::splice :: (index :: Number, count :: Number, elements :: Array) -> removed :: Array
```

If the above type signature were above a method definition, then the method name
and parameter names could be dropped. The return value name could be kept for
clarity.

```coffee-script
# :: (Number, Number, Array) -> removed :: Array
splice: (index, count, elements) -> # ...
```

Optional parameters are wrapped in `[]`. Variable numbers of parameters can be
indicated by adding `...`.

```coffee-script
# Array::slice :: (start :: Number, [end :: Number]) -> Array
# console.log :: (Object...) ->
```
