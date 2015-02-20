# Upgrading Your UI Theme Or Package Selectors

In addition to changes in Atom's scripting API, we'll also be making some breaking changes to Atom's DOM structure, requiring style sheets and keymaps in both packages and themes to be updated.

## Deprecation Cop

Deprecation cop will list usages of deprecated selector patterns to guide you. You can access it via the command palette (`cmd-shift-p`, then search for `Deprecation`). It breaks the deprecations down by package:

![dep-cop](https://cloud.githubusercontent.com/assets/69169/5078860/d38a5df4-6e64-11e4-95b6-eb585ee9bbfc.png)

## Custom Tags

Rather than adding classes to standard HTML elements to indicate their role, Atom now uses custom element names. For example, `<div class="workspace">` has now been replaced with `<atom-workspace>`. Selectors should be updated accordingly. Note that tag names have lower specificity than classes in CSS, so you'll need to take care in converting things.

Old Selector        | New Selector
--------------------|--------------------------------
`.editor`           | `atom-text-editor`
`.editor.mini`      | `atom-text-editor[mini]`
`.workspace`        | `atom-workspace`
`.horizontal`       | `atom-workspace-axis.horizontal`
`.vertical`         | `atom-workspace-axis.vertical`
`.pane-container`   | `atom-pane-conatiner`
`.pane`             | `atom-pane`
`.tool-panel`       | `atom-panel`
`.panel-top`        | `atom-panel.top`
`.panel-bottom`     | `atom-panel.bottom`
`.panel-left`       | `atom-panel.left`
`.panel-right`      | `atom-panel.right`
`.overlay`          | `atom-panel.modal`

## Supporting the Shadow DOM

Text editor content is now rendered in the shadow DOM, which shields it from being styled by global style sheets to protect against accidental style pollution. For more background on the shadow DOM, check out the [Shadow DOM 101][shadow-dom-101] on HTML 5 Rocks. If you need to style text editor content in a UI theme, you'll need to circumvent this protection for any rules that target the text editor's content. Some examples of the kinds of UI theme styles needing to be updated:

* Highlight decorations
* Gutter decorations
* Line decorations
* Scrollbar styling
* Anything targeting a child selector of `.editor`

During a transition phase, it will be possible to enable or disable the text editor's shadow DOM in the settings, so themes will need to be compatible with both approaches.

### Shadow DOM Selectors

Chromium provides two tools for bypassing shadow boundaries, the `::shadow` pseudo-element and the `/deep/` combinator. For an in-depth explanation of styling the shadow DOM, see the [Shadow DOM 201][shadow-dom-201] article on HTML 5 Rocks.

#### ::shadow

The `::shadow` pseudo-element allows you to bypass a single shadow root. For example, say you want to update a highlight decoration for a linter package. Initially, the style looks as follows:

```css
// Without shadow DOM support
atom-text-editor .highlight.my-linter {
  background: hotpink;
}
```

In order for this style to apply with the shadow DOM enabled, you will need to add a second selector with the `::shadow` pseudo-element. You should leave the original selector in place so your theme continues to work with the shadow DOM disabled during the transition period.

```css
// With shadow DOM support
atom-text-editor .highlight.my-linter,
atom-text-editor::shadow .highlight.my-linter {
  background: hotpink;
}
```

Check out the [find-and-replace][find-and-replace] package for another example of using `::shadow` to pierce the shadow DOM.

#### /deep/

The `/deep/` combinator overrides *all* shadow boundaries, making it useful for rules you want to apply globally such as scrollbar styling. Here's a snippet containing scrollbar styling for the Atom Dark UI theme before shadow DOM support:

```css
// Without shadow DOM support
.scrollbars-visible-always {
  ::-webkit-scrollbar {
    width: 8px;
    height: 8px;
  }

  ::-webkit-scrollbar-track,
  ::-webkit-scrollbar-corner {
    background: @scrollbar-background-color;
  }

  ::-webkit-scrollbar-thumb {
    background: @scrollbar-color;
    border-radius: 5px;
    box-shadow: 0 0 1px black inset;
  }
}
```

To style scrollbars even inside of the shadow DOM, each rule needs to be prefixed with `/deep/`. We use `/deep/` instead of `::shadow` because we don't care about the selector of the host element in this case. We just want our styling to apply everywhere.

```css
// With shadow DOM support using /deep/
.scrollbars-visible-always {
  /deep/ ::-webkit-scrollbar {
    width: 8px;
    height: 8px;
  }

  /deep/ ::-webkit-scrollbar-track,
  /deep/ ::-webkit-scrollbar-corner {
    background: @scrollbar-background-color;
  }

  /deep/ ::-webkit-scrollbar-thumb {
    background: @scrollbar-color;
    border-radius: 5px;
    box-shadow: 0 0 1px black inset;
  }
}
```

### Context-Targeted Style Sheets

The selector features discussed above allow you to target shadow DOM content with specific selectors, but Atom also allows you to target a specific shadow DOM context with an entire style sheet. The context into which a style sheet is loaded is based on the file name. If you want to load a style sheet into the editor, name it with the `.atom-text-editor.less` or `.atom-text-editor.css` extensions.

```
my-ui-theme/
  styles/
    index.less                   # loaded globally
    index.atom-text-editor.less  # loaded in the text editor shadow DOM
```

Check out this [style sheet](https://github.com/atom/decoration-example/blob/master/styles/decoration-example.atom-text-editor.less) from the decoration-example package for an example of context-targeting.

Inside a context-targeted style sheet, there's no need to use the `::shadow` or `/deep/` expressions. If you want to refer to the element containing the shadow root, you can use the `::host` pseudo-element.

During the transition phase, style sheets targeting the `atom-text-editor` context will *also* be loaded globally. Make sure you update your selectors in a way that maintains compatibility with the shadow DOM being disabled. That means if you use a `::host` pseudo element, you should also include the same style rule matches against `atom-text-editor`.

[shadow-dom-101]: http://www.html5rocks.com/en/tutorials/webcomponents/shadowdom
[shadow-dom-201]: http://www.html5rocks.com/en/tutorials/webcomponents/shadowdom-201#toc-style-cat-hat
[find-and-replace]: https://github.com/atom/find-and-replace/blob/95351f261bc384960a69b66bf12eae8002da63f9/styles/find-and-replace.less#L10
