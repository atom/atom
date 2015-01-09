# Keymaps In-Depth

## Structure of a Keymap File

Keymap files are encoded as JSON or CSON files containing nested hashes. They
work much like style sheets, but instead of applying style properties to elements
matching the selector, they specify the meaning of keystrokes on elements
matching the selector. Here is an example of some bindings that apply when
keystrokes pass through `atom-text-editor` elements:

```coffee
'atom-text-editor':
  'cmd-delete': 'editor:delete-to-beginning-of-line'
  'alt-backspace': 'editor:delete-to-beginning-of-word'
  'ctrl-A': 'editor:select-to-first-character-of-line'
  'ctrl-shift-e': 'editor:select-to-end-of-line'
  'cmd-left': 'editor:move-to-first-character-of-line'

'atom-text-editor:not([mini])'
  'cmd-alt-[': 'editor:fold-current-row'
  'cmd-alt-]': 'editor:unfold-current-row'
```

Beneath the first selector are several bindings, mapping specific *keystroke
patterns* to *commands*. When an element with the `atom-text-editor` class is focused and
`cmd-delete` is pressed, an custom DOM event called
`editor:delete-to-beginning-of-line` is emitted on the `atom-text-editor` element.

The second selector group also targets editors, but only if they don't have the
`mini` attribute. In this example, the commands for code folding don't really
make sense on mini-editors, so the selector restricts them to regular editors.

### Keystroke Patterns

Keystroke patterns express one or more keystrokes combined with optional
modifier keys. For example: `ctrl-w v`, or `cmd-shift-up`. A keystroke is
composed of the following symbols, separated by a `-`. A multi-keystroke pattern
can be expressed as keystroke patterns separated by spaces.


| Type                | Examples
| --------------------|----------------------------
| Character literals  | `a` `4` `$`
| Modifier keys       | `cmd` `ctrl` `alt` `shift`
| Special keys        | `enter` `escape` `backspace` `delete` `tab` `home` `end` `pageup` `pagedown` `left` `right` `up` `down`

### Commands

Commands are custom DOM events that are triggered when a keystroke matches a
binding. This allows user interface code to listen for named commands without
specifying the specific keybinding that triggers it. For example, the following
code sets up {EditorView} to listen for commands to move the cursor to the first
character of the current line:

```coffee
class EditorView
  listenForEvents: ->
    @command 'editor:move-to-first-character-of-line', =>
      @editor.moveToFirstCharacterOfLine()
```

The `::command` method is basically an enhanced version of jQuery's `::on`
method that listens for a custom DOM event and adds some metadata to the DOM,
which is read by the command palette.

When you are looking to bind new keys, it is often useful to use the command
palette (`ctrl-shift-p`) to discover what commands are being listened for in a
given focus context. Commands are "humanized" following a simple algorithm, so a
command like `editor:fold-current-row` would appear as "Editor: Fold Current
Row".

### Specificity and Cascade Order

As is the case with CSS applying styles, when multiple bindings match for a
single element, the conflict is resolved by choosing the most *specific*
selector. If two matching selectors have the same specificity, the binding
for the selector appearing later in the cascade takes precedence.

Currently, there's no way to specify selector ordering within a single keymap,
because JSON objects do not preserve order. We eventually plan to introduce a
custom CSS-like file format for keymaps that allows for ordering within a single
file. For now, we've opted to handle cases where selector ordering is critical
by breaking the keymap into two separate files, such as `snippets-1.cson` and
`snippets-2.cson`.

## Removing Bindings

When the keymap system encounters a binding with the `unset!` directive as its
command, it will treat the current element as if it had no key bindings matching
the current keystroke sequence and continue searching from its parent. If you
want to remove a binding from a keymap you don't control, such as keymaps in
Atom core or in packages, use the `unset!` directive.

For example, the following code removes the keybinding for `a` in the Tree View,
which is normally used to trigger the `tree-view:add-file` command:

```coffee
'.tree-view':
    'a': 'unset!'
```

![](https://cloud.githubusercontent.com/assets/38924/3174771/e7f6ce64-ebf4-11e3-922d-f280bffb3fc5.png)

## Forcing Chromium's Native Keystroke Handling

If you want to force the native browser behavior for a given keystroke, use the
`native!` directive as the command of a binding. This can be useful to enable
the correct behavior in native input elements, for example. If you apply the
`.native-key-bindings` class to an element, all the keystrokes typically handled
by the browser will be assigned the `native!` directive.

## Overloading Key Bindings

Occasionally, it makes sense to layer multiple actions on top of the same key
binding. An example of this is the snippets package. Snippets are inserted by
typing a snippet prefix such as `for` and then pressing `tab`. Every time `tab`
is pressed, we want to execute code attempting to expand a snippet if one exists
for the text preceding the cursor. If a snippet *doesn't* exist, we want `tab`
to actually insert whitespace.

To achieve this, the snippets package makes use of the `.abortKeyBinding()`
method on the event object representing the `snippets:expand` command.

```coffee-script
# pseudo-code
editor.command 'snippets:expand', (e) =>
  if @cursorFollowsValidPrefix()
    @expandSnippet()
  else
    e.abortKeyBinding()
```

When the event handler observes that the cursor does not follow a valid prefix,
it calls `e.abortKeyBinding()`, telling the keymap system to continue searching
for another matching binding.

## Step-by-Step: How Keydown Events are Mapped to Commands

* A keydown event occurs on a *focused* element.
* Starting at the focused element, the keymap walks upward towards the root of
  the document, searching for the most specific CSS selector that matches the
  current DOM element and also contains a keystroke pattern matching the keydown
  event.
* When a matching keystroke pattern is found, the search is terminated and the
  pattern's corresponding command is triggered on the current element.
* If `.abortKeyBinding()` is called on the triggered event object, the search
  is resumed, triggering a binding on the next-most-specific CSS selector for
  the same element or continuing upward to parent elements.
* If no bindings are found, the event is handled by Chromium normally.
