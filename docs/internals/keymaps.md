## Keymaps In-Depth

### Structure of a Keymap File

Keymap files are encoded as JSON or CSON files containing nested hashes. The
top-level keys of a keymap are **CSS 3 selectors**, which specify a particular
context in Atom's interface. Common selectors are `.editor`, which scopes
bindings to just work when an editor is focused, and `body`, which scopes
bindings globally.

Beneath the selectors are hashes mapping **keystroke patterns** to
**semantic events**. A keystroke pattern looks like the following examples.
Note that the last example describes multiple keystrokes in succession:

- `p`
- `2`
- `ctrl-p`
- `ctrl-alt-cmd-p`
- `tab`
- `escape`
- `enter`
- `ctrl-w w`

A semantic event is the name of the custom event that will be triggered on the
target of the keydown event when a key binding matches. You can use the command
palette (bound to `cmd-p`), to get a list of relevant events and their bindings
in any focused context in Atom.

### Rules for Mapping A Keydown Event to A Semantic Event

A keymap's job is to translate a physical keystroke event (like `cmd-D`) into a
semantic event (like `editor:duplicate-line`). Whenever a keydown event occurs
on a focused element, it bubbles up the DOM as usual. As soon as an element on
the bubble path matches a key binding for the keystroke, the binding's semantic
event is triggered on the original target of the keydown event. Just as with
CSS, if multiple selectors match an element, the most specific selector is
favored. If two selectors have the same specificity, the selector that occurs
latest in the cascade is favored.

Currently, there's no way to specify selector ordering within a single keymap,
because JSON hashes do not preserve order. Rather than making the format more
awkward in order to preserve order, we've opted to handle cases where order is
critical by breaking the keymap into two separate files, such as
`snippets-1.cson` and `snippets-2.cson`.

### Overloading Key Bindings

Occasionally, it makes sense to layer multiple actions on top of the same key
binding. An example of this is the snippets package. You expand a snippet by
pressing `tab` immediately following a snippet's prefix. But if the cursor is
not following a valid snippet prefix, then we want tab to perform its normal
action (probably inserting a tab character or the appropriate number of spaces).

To achieve this, the snippets package makes use of the `abortKeyBinding` method
on the event object that's triggered by the binding for `tab`.

```coffee-script
# pseudo-code
editor.command 'snippets:expand', (e) =>
  if @cursorFollowsValidPrefix()
    @expandSnippet()
  else
    e.abortKeyBinding()
```

When the event handler observes that the cursor does not follow a valid prefix,
it calls `e.abortKeyBinding()`, which tells the keymap system to continue
searching up the cascade for another matching binding. In this case, the default
implementation of `tab` ends up getting triggered.
