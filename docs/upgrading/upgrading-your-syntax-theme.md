# Upgrading Your Syntax Theme

Text editor content is now rendered in the shadow DOM, which shields it from being styled by global style sheets to protect against accidental style pollution. For more background on the shadow DOM, check out the [Shadow DOM 101][shadow-dom-101] on HTML 5 Rocks.

Syntax themes are specifically intended to style only text editor content, so they are automatically loaded directly into the text editor's shadow DOM when it is enabled. This happens automatically when the the theme's `package.json` contains a `theme: "syntax"` declaration, so you don't need to change anything to target the appropriate context.

When theme style sheets are loaded into the text editor's shadow DOM, selectors intended to target the editor from the *outside* no longer make sense. Styles targeting the `.editor` and `.editor-colors` classes instead need to target the `:host` pseudo-element, which matches against the containing `atom-text-editor` node. Check out the [Shadow DOM 201][host-pseudo-element] article for more information about the `:host` pseudo-element.

Here's an example from Atom's light syntax theme. Note that the previous selectors intended to target the editor from the outside have been retained to allow the theme to keep working during the transition phase when it is possible to disable the shadow DOM.

```css
.editor-colors, :host { /* :host added */
  background-color: @syntax-background-color;
  color: @syntax-text-color;
}

.editor, :host { /* :host added */
  .invisible-character {
    color: @syntax-invisible-character-color;
  }

  /* more nested selectors... */
}
```

[shadow-dom-101]: http://www.html5rocks.com/en/tutorials/webcomponents/shadowdom
[host-pseudo-element]: http://www.html5rocks.com/en/tutorials/webcomponents/shadowdom-201#toc-style-host
