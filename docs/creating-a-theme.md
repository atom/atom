# Creating a Theme

Atom's interface is rendered using HTML, and it's styled via [Less] which is a
superset of CSS. Don't worry if you haven't heard of Less before; it's just like
CSS, but with a few handy extensions.

Atom supports two types of themes: _UI_ and _syntax_.  UI themes style
elements such as the tree view, the tabs, drop-down lists, and the status bar.
Syntax themes style the code inside the editor.

Themes can be installed and changed from the settings view which you can open
by selecting the _Atom > Preferences..._ menu and navigating to the _Install_
section and the _Themes_ section on the left hand side.

## Getting Started

Themes are pretty straightforward but it's still helpful to be familiar with
a few things before starting:

* Less is a superset of CSS, but it has some really handy features like
  variables. If you aren't familiar with its syntax, take a few minutes
  to [familiarize yourself][less-tutorial].
* You may also want to review the concept of a _[package.json]_, too. This file
  is used to help distribute your theme to Atom users.
* Your theme's _package.json_ must contain a `"theme"` key with a value
  of `"ui"` or `"syntax"` for Atom to recognize and load it as a theme.
* You can find existing themes to install or fork on
  [atom.io][atomio-themes].

## Creating a Syntax Theme

Let's create your first theme.

To get started, hit `cmd-shift-P`, and start typing "Generate Syntax Theme" to
generate a new theme package. Select "Generate Syntax Theme," and you'll be
asked for the path where your theme will be created. Let's call ours
_motif-syntax_. __Tip:__ syntax themes should end with _-syntax_.

Atom will pop open a new window, showing the _motif-syntax_ theme, with a
default set of folders and files created for us. If you open the settings view
(`cmd-,`) and navigate to the _Themes_ section on the left, you'll see the
_Motif_ theme listed in the _Syntax Theme_ drop-down. Select it from the menu to
activate it, now when you open an editor you should see that your new
_motif-syntax_ theme in action.

Open up _styles/colors.less_ to change the various colors variables which
have been already been defined. For example, turn `@red` into `#f4c2c1`.

Then open _styles/base.less_ and modify the various selectors that have
been already been defined. These selectors style different parts of code in the
editor such as comments, strings and the line numbers in the gutter.

As an example, let's make the `.gutter` `background-color` into `@red`.

Reload Atom by pressing `cmd-alt-ctrl-l` to see the changes you made reflected
in your Atom window. Pretty neat!

__Tip:__ You can avoid reloading to see changes you make by opening an atom
window in dev mode. To open a Dev Mode Atom window run `atom --dev .` in the
terminal, use `cmd-shift-o` or use the _View > Developer > Open in Dev Mode_
menu. When you edit your theme, changes will instantly be reflected!

> Note: It's advised to _not_ specify a `font-family` in your syntax theme because it will override the Font Family field in Atom's settings. If you still like to recommend a font that goes well with your theme, we recommend you do so in your README.

## Creating an Interface Theme

Interface themes **must** provide a `ui-variables.less` file which contains all
of the variables provided by the [core themes][ui-variables].

To create an interface UI theme, do the following:

1. Fork one of the following repositories:
  * [atom-dark-ui]
  * [atom-light-ui]
2. Clone the forked repository to the local filesystem
3. Open a terminal in the forked theme's directory
4. Open your new theme in a Dev Mode Atom window run `atom --dev .` in the
   terminal or use the _View > Developer > Open in Dev Mode_ menu
5. Change the name of the theme in the theme's `package.json` file
6. Name your theme end with a `-ui`. i.e. `super-white-ui`
7. Run `apm link` to symlink your repository to `~/.atom/packages`
8. Reload Atom using `cmd-alt-ctrl-L`
9. Enable the theme via _UI Theme_ drop-down in the _Themes_ section of the
   settings view
10. Make changes! Since you opened the theme in a Dev Mode window, changes will
   be instantly reflected in the editor without having to reload.

## Development workflow

There are a few of tools to help make theme development faster and easier.

### Live Reload

Reloading by hitting `cmd-alt-ctrl-L` after you make changes to your theme is
less than ideal. Atom supports [live updating][livereload] of styles on Dev Mode
Atom windows.

To enable a Dev Mode window:

1. Open your theme directory in a dev window by either going to the
   __View > Developer > Open in Dev Mode__ menu or by hitting the `cmd-shift-o`
  shortcut
2. Make a change to your theme file and save it. Your change should be
   immediately applied!

If you'd like to reload all the styles at any time, you can use the shortcut
`cmd-ctrl-shift-r`.

### Developer Tools

Atom is based on the Chrome browser, and supports Chrome's Developer Tools. You
can open them by selecting the _View > Toggle Developer Tools_ menu, or by
using the `cmd-alt-i` shortcut.

The dev tools allow you to inspect elements and take a look at their CSS
properties.

![devtools-img]

Check out Google's [extensive tutorial][devtools-tutorial] for a short
introduction.

### Atom Styleguide

If you are creating an interface theme, you'll want a way to see how your theme
changes affect all the components in the system. The [styleguide] is a page that
renders every component Atom supports.

To open the styleguide, open the command palette (`cmd-shift-P`) and search for
_styleguide_, or use the shortcut `cmd-ctrl-shift-g`.

![styleguide-img]

[atomio-themes]: https://atom.io/themes
[Less]: http://lesscss.org/
[git]: http://git-scm.com/
[atom]: https://atom.io/
[package.json]: ./creating-a-package.html#package-json
[less-tutorial]: https://speakerdeck.com/danmatthews/less-css
[devtools-tutorial]: https://developer.chrome.com/devtools/docs/dom-and-styles
[ui-variables]: ./theme-variables.html
[livereload]: https://github.com/atom/dev-live-reload
[styleguide]: https://github.com/atom/styleguide
[atom-dark-ui]: https://github.com/atom/atom-dark-ui
[atom-light-ui]: https://github.com/atom/atom-light-ui
[styleguide-img]: https://f.cloud.github.com/assets/69169/1347390/2d431d98-36af-11e3-8f8e-3f4ce1e67adb.png
[devtools-img]: https://f.cloud.github.com/assets/69169/1347391/2d51f91c-36af-11e3-806f-f7b334af43e9.png
[themesettings-img]: https://f.cloud.github.com/assets/69169/1347569/3150bd0c-36b2-11e3-9d69-423503acfe3f.png
