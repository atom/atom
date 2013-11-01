# Creating a Theme

Atom's interface is rendered using HTML, and it's styled via [LESS] (a superset
of CSS). Don't worry if you haven't heard of LESS before; it's just like CSS, but
with a few handy extensions.

Since CSS is the basis of the theming system, we can load multiple themes within
Atom, and the themes behave just as they would on a website. Themes loaded first
are overridden by themes which are loaded later. The order of theme loading is
controlled within the Settings/Themes pane.

This flexibility is helpful for users that prefer a light interface with a dark
syntax theme. Atom currently has only interface and syntax themes, but it is
possible to create a theme to style something specific &mdash; say, changing
the colors in the tree view or creating a language specific syntax theme.

## Getting Started

Themes are pretty straight forward but it's still helpful to be familiar with
a few things before starting:

* LESS is a superset of CSS, but it has some really handy features like
  variables. If you aren't familiar with its syntax take a few minutes
  to [familiarize yourself][less-tutorial].
* You may also want to review the concept of a _[package.json]_, too. This file
is used to help distribute your theme to Atom users.

There are two types of themes you can create: syntax themes and interface themes.
The differences between them are simply a matter of what they target and what
they provide. Syntax themes focus on the entire editor pane, while interface themes
target elements which are outside of the editor.

## Creating a Syntax Theme

Let's create your first theme.

To get started, hit `cmd-p`, and start typing "Generate Theme" to generate
a package. Select "Generate Theme," and you'll be asked for a theme name. Let's
call ours _motif_.

Atom will pop open a new window, showing the _motif_ theme, with a default set of
folders and files created for us. If you hit `cmd-,` and navigate to the Themes
menu option, you'll see the `motif` theme already available. Drag it over from
"Enabled Themes" to "Available Themes."

Open up _stylesheets/colors.less_ to change the various colors variables which
have been already been defined. For example, turn `@red` into `#f4c2c1`.

Then, open _stylesheets/base.less_, and modify the various syntax CSS selectors
that have been already been defined. Each of these selectors represents a different
part of the Atom window. Themes that don't need to modify a particular region
can simply remove the selectors they don't need.

As an example, let's make the `.gutter` `background-color` into `@red`.

Reload Atom by hitting `cmd-r` to see the changes you made reflected in your Atom
window. Pretty neat!

## Creating an Interface Theme

Interface themes  **must** provide a `ui-variables.less` file which contains all
of the variables provided by the [core themes][ui-variables].

To create an interface UI theme, do the following:

1. Fork one of the following repos
  1. [atom-dark-ui]
  1. [atom-light-ui]
1. Open a terminal in the forked theme's directory
1. Open your new theme in a Dev Mode Atom window (run `atom -d .` in the terminal or use the __View > Developer > Open in Dev Mode__ menu)
1. Change the name of the theme in the theme's `package.json` file
1. Run `apm link` to tell Atom about your new theme
1. Reload Atom (`cmd-r`)
1. Enable the theme via the themes panel in settings
1. Make changes! Since you opened the theme in a Dev Mode window, changes will
   be instantly reflected in the editor without having to reload.

## Development workflow

There are a few of tools to help make theme development faster.

### Live Reload

Reloading by hitting `cmd-r` after you make changes to your theme is less than ideal.
Atom supports [live updating][livereload] of styles on Dev Mode Atom windows.

To enable a Dev Mode window:

1. Open your theme directory in a dev window by either going to the
__View > Developer > Open in Dev Mode__ menu or by hitting the `cmd-shift-o`
shortcut
1. Make a change to your theme file and save it. Your change should be
immediately applied!

If you'd like to reload all the styles at any time, you can use the shortcut
`cmd-ctrl-R`.

### Developer Tools

Atom is based on the Chrome browser, and supports Chrome's Developer Tools. You
can open them by selecting the __View > Toggle Developer Tools__ menu, or by using
the `cmd-option-i` shortcut.

The dev tools allow you to inspect elements and take a look at their CSS
properties.

![devtools-img]

Check out Google's [extensive tutorial][devtools-tutorial] for a short introduction.

### Atom Styleguide

If you are creating an interface theme, you'll want a way to see how your theme
changes affect all the components in the system. The [styleguide] is a page with
every component Atom supports rendered.

To open the styleguide, open the command palette (`cmd-p`) and search for
_styleguide_, or use the shortcut `cmd-ctrl-shift-g`.

![styleguide-img]

[less]: http://lesscss.org/
[git]: http://git-scm.com/
[atom]: https://atom.io/
[package.json]: ./creating-a-package.html#package-json
[less-tutorial]: https://speakerdeck.com/danmatthews/less-css
[devtools-tutorial]: https://developers.google.com/chrome-developer-tools/docs/elements
[ui-variables]: ./theme-variables.html
[livereload]: https://github.com/atom/dev-live-reload
[styleguide]: https://github.com/atom/styleguide
[atom-dark-ui]: https://github.com/atom/atom-dark-ui
[atom-light-ui]: https://github.com/atom/atom-light-ui
[styleguide-img]: https://f.cloud.github.com/assets/69169/1347390/2d431d98-36af-11e3-8f8e-3f4ce1e67adb.png
[devtools-img]: https://f.cloud.github.com/assets/69169/1347391/2d51f91c-36af-11e3-806f-f7b334af43e9.png
[themesettings-img]: https://f.cloud.github.com/assets/69169/1347569/3150bd0c-36b2-11e3-9d69-423503acfe3f.png
