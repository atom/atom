{{{
"title": "Creating a Theme"
}}}

# Authoring Themes

If you understand CSS, you can write an Atom theme easily. Your theme can style
Atom's user interface, specify the appearance of syntax-highlighted code, or
both. For making a syntax highlighting theme, refer to
[section 12.4 of the TextMate Manual](http://manual.macromates.com/en/language_grammars.html)
for a list of the common scopes used by TextMate grammars. You'll just need to
translate scope names to CSS classes. To theme Atom's user interface, take a
look at the existing light and dark themes for an example. Pressing `alt-meta-i`
and inspecting the Atom's markup directly can also be helpful.

The most basic theme is just a _.css_ file. More complex themes occupy their own
folder, which can contain multiple stylesheets along with an optional
_package.cson_ file containing a manifest to control their load-order:

```text
~/.atom/themes/
  rockstar.css
  rainbow/
    package.json
    core.css
    editor.css
    tree-view.css
```

package.cson:
```coffee-script
stylesheets: ["core.css", "editor.less", "tree-view.css"]
```

The `package.cson` file specifies which stylesheets to load and in what order
with the `stylesheets` key. If no manifest is specified, all stylesheets are
loaded in alphabetical order when the user selects the theme.


## Theme Extensions (Not Yet Implemented)

A theme may need to be extended to cover DOM elements that are introduced by a
third-party Atom package. When a package is loaded, stylesheets with the same
name as the package will automatically be loaded from the `packages` directory
of active themes:

```text
~/.atom/themes/
  midnight/midnight.less
  midnight/packages/terminal.less
  midnight/packages/tree-view.less
```

In the example above, if the `midnight` theme is active, its `terminal` and
`tree-view` stylesheets will be loaded automatically if and when those packages
are activated. If you author an extension to a theme consider sending its author
a pull request to have it included in the theme by default. Package-specific
theme stylesheets need not be listed in the theme's `package.json` because they
will be loaded automatically when the package is loaded.
