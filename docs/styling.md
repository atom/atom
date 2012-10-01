## Styling Tweaks

### Cursor Line Highlighting

Atom highlights the background color of the entire line where the cursor
currently is and also changes the foreground color of the line number in the
gutter.

You can change the background color using the following CSS:

```css
.editor.focused .line.cursor-line,
.editor.focused .line-number.cursor-line-number-background {
  background-color: green;
}
```

You can change the line number foreground color using the following CSS:

```css
.editor.focused .line-number.cursor-line-number {
  color: blue;
}
```
