## Focus in Atom, how does it work?

### As a user, how do I navigate with my keyboard?

tab => `core:focus-next`, shift-tab => `core:focus-previous` in the default keymap.

those bindings call these two functions which shift you around by calling `setFocus()` with the "next" or "previous" symbol in `GitTabView`.

### Debugging setup

First, you'll want to add this snippet to your init file:

```
function focusTracer (event) {
  console.log('window.focus =', event.target)
}

atom.commands.add('atom-workspace', {
  'me:trace-focus': () => window.addEventListener('focusin', focusTracer),
  'me:untrace-focus': () => window.removeEventListener('focusin', focusTracer),
})
```
Opening the developer tools pane changes what's in focus, so the focusTracer helps debug what's going on.

### Lifecycle of a focus event

We move focus around by registering Atom commands.

For example, in `GitTabView`:

```
      this.props.commands.add(this.refRoot, {
        'tool-panel:unfocus': this.blur,
        'core:focus-next': this.advanceFocus,
        'core:focus-previous': this.retreatFocus,
      }),
```

How do we handle restoring keyboard focus to the right place when you toggle it back and forth?

We install an event handler on the root element of the [GitTabView](https://github.com/atom/github/blob/aw/file-patch-editor/lib/controllers/git-tab-controller.js#L138).

Every time focus changes to an element that's a descendant of the git tab, this event handler fires and sets a `lastFocus` property within the controller.

When the git tab regains focus again (by being revealed with a hotkey, say) `restoreFocus` gets called:

```
  restoreFocus() {
    this.refView.setFocus(this.lastFocus);
  }
```

components in the GitTabView tree implement `rememberFocus()`, to inspect `event.target` and return a Symbol corresponding to a logical focus position within them (or delegate to a child component)
"logical focus position" meaning "the staging view" or "the commit editor" as opposed to the actual DOM elements that get focus (because those can change on re-render).  We want to restore users to the logical place in the tab where they were even if the actual DOM elements have been swapped out.

For example: in GitTabView, we have this symbol as a static prop:

```
  static focus = {
    STAGING: Symbol('staging'),
  };
```

in its `rememberFocus()` method, we see if the active element is within the staging view, and if so we return that symbol:
```
  rememberFocus(event) {
    return this.refRoot.contains(event.target) ? StagingView.focus.STAGING : null;
  }
```

Then in `setFocus()`, if we recognize the symbol, we call `.focus()` imperatively to bring focus back in.

```
  setFocus(focus) {
    if (focus === StagingView.focus.STAGING) {
      this.refRoot.focus();
      return true;
    }

    return false;
  }
  ```
