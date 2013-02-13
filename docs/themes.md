# Themes

## Selecting A Theme

Atom comes bundles with two themes "Atom - Dark" and "Atom - Light". You can
select a theme in your core preferences pane.

Because Atom themes are based on CSS, it's possible to have multiple themes
active at the same time. For example, you might select a theme for the UI, and
another theme for syntax highlighting. You select your theme(s) in the core
preferences pane, by selecting themes from the available list and dragging them
in your preferred order. You can also edit the selected themes manually with the
`config.core.themes` array. For example.

```js
{
  "core": {
    "themes": ["Atom - Light", "Mac Classic"]
  },
  "editor": {
    "fontSize": 15
  }
}
```

## Installing A Theme

You install themes by placing them in the `~/.atom/themes` directory. The most
basic theme is just a `.css` or `.less` file. More complex occupy their own
folder, which can contain multiple stylesheets along with an optional
`package.json` file with a manifest to control their load-order:

```text
~/.atom/themes/
  midnight.less
  rockstar.css
  rainbow/
    package.json
    core.less
    editor.less
    tree-view.less
```

package.json:
```json
{
  "stylesheets": ["core.css", "editor.less", "tree-view.css"]
}
```

The package.json specifies which stylesheets to load and in what order with the
`stylesheets` key. If no manifest is specified, all stylesheets are loaded in
alphabetical order when the user selects the theme.

## Authoring A Theme

If you understand CSS, you can write an Atom theme easily. Your theme can style
Atom's user interface, specify the appearance of syntax-highlighted code, or
both. For making a syntax highlighting theme, refer to [section 12.4 of the
TextMate Manual](http://manual.macromates.com/en/language_grammars.html) for a
list of the common scopes used by TextMate grammars. You'll just need to
scope names to CSS classes. To theme Atom's user interface, refer to
[Classnames for Extension and Theme Authors]() for information about the CSS
classes used in Atom's core and the most common classes employed by
extensions.

## Theme Extensions

A theme will often cover the stock features of Atom, but may need to be extended
to cover extensions that weren't covered by its original author. Theme extensions
make this easy to organize. To make a theme extension, just add a theme that
matches the name of the original with an additional filename extension:

```text
~/.atom/themes/
  midnight/midnight.less
  midnight/packages/terminal.less
  midnight/packages/tree-view.less
```

In the example above, when the `midnight` theme is loaded, its `terminal` and
`tree-view` extensions will be loaded with it. If you author a theme extension,
consider sending its author a pull request to have it included in the theme's
core. Package theme extensions, do not need to be in `package.json` because they
will be loaded when needed by the package.

## TextMate Compatibility

If you place a TextMate theme (either `.tmTheme` or `.plist`) in the `themes`
directory, it will automatically be translated from TextMate's format to CSS
so it works with Atom. There are a few slight differences between TextMate's
semantics and those of stylesheets, but they should be negligible in practice.
