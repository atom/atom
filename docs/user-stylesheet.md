## User Stylesheet

If you want to apply quick-and-dirty personal styling changes without creating
an entire theme that you intend to distribute, you can add styles to
`user.css` in your `~/.atom` directory.

For example to change the color of the highlighted line number for the line that
contains the cursor, you could add the following style to `user.css`:

```css
.editor .line-number.cursor-line {
  color: pink;
}
```
