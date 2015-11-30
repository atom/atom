See https://atom.io/releases

## 1.3.0

* The tree-view now sorts directory entries more naturally, in a locale-sensitive way.
* Lines can now be moved up and down with multiple cursors.
* Improved the performance of marker-dependent code paths such as spell-check and find and replace.
* Fixed copying and pasting in native input fields.
* By default, windows with no pane items are now closed via the `core:close` command. The previous behavior can be restored via the `Close Empty Windows` option in settings.
* Fixed an issue where characters were inserted when toggling the settings view on some keyboard layouts.
* Modules can now temporarily override `Error.prepareStackTrace`. There is also an `Error.prototype.getRawStack()` method if you just need access to the raw v8 trace structure.
* Fixed a problem that caused blurry fonts on monitors that have a slightly higher resolution than 96 DPI.
