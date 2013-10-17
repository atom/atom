# Creating a Theme

Atom's interface is rendered using HTML and it's styled via [LESS] (a superset
of CSS). Don't worry if you haven't heard of LESS before, it's just like CSS but
with a few handy extensions.

Since CSS is the basis of the theming system, we can load multiple themes within
Atom and they behaves just as they would on a website. Themes loaded first are overridden by
themes which are loaded later (the order is controlled from within the Settings
pane).

This flexibility is helpful for users which prefer a light interface with a dark
syntax theme. Atom currently has only interface and syntax themes but it is
possible to create a theme to style something specific &mdash; say a changing
the colors in the tree view or creating a language specific syntax theme.

## Getting Started

To create your own theme you'll need a few things:

* A working install of [Atom], so you can work on your new theme.
* A working install of [git] to track changes.
* And a [GitHub] account, so you can distribute your themes.

Themes are pretty straight forward but it's still helpful to be familiar with
a few things before starting:

* LESS is a superset of CSS but it has some really handy features like
  variables. If you aren't familiar with its syntax take a few minutes
  to [familiarize yourself][less-tutorial].
* Atom uses Chrome at its core, so you can use Chrome devtools to
  inspect the current state of the interface. Checkout Google's
  [extensive tutorial][devtools-tutorial] for a short introduction.

## Creating a Minimal Syntax Theme

1. Open the Command Palette (`cmd-p`)
1. Search for `Package Generator: Generate Theme` and select it.
1. Choose a name for the folder which will contain your theme.
1. An Atom window will open with your newly created theme.
  1. Open `package.json` and update the relevant parts.
  1. Open `stylesheets/colors.less` to change the various colors variables which
     have been already been defined.
  1. Open `stylesheets/base.less` and modify the various syntax CSS selectors
     that have been already been defined.
  1. When you're ready update the `README.md` and include an example screenshot
     of your new theme in action.
1. Reload Atom (`cmd-r`) and your theme should now be applied.
1. Look in the theme settings, your new theme should be show in the enabled themes section
    ![themesettings-img]
1. Open a terminal to your new theme directory; it should be in `~/.atom/packages/<my-name>`.  
  1. To publish, initialize a git repository, push to GitHub, and run
     `apm publish`.

## Interface Themes

There are only two differences between interface and syntax themes - what
they target and what they provide. Interface themes only target elements which
are outside of the editor and **must** provide a `ui-variables.less` file which
contains all of the variables provided by the [core themes][ui-variables].

To create a UI theme, do the following:

1. Fork one of the following repos
  1. [atom-dark-ui]
  1. [atom-light-ui]
1. Open a terminal in the forked theme's directory
1. Open your new theme in a Dev Mode Atom window (either run `atom -d .` in the terminal or use `cmd-shift-o` from atom)
1. Change the name of the theme in the theme's `package.json` file
1. Run `apm link` to tell Atom about your new theme
1. Reload Atom (`cmd-r`)
1. Enable the theme via the themes panel in settings
1. Make changes! Since you opened the theme in a Dev Mode window, changes will
   be instantly reflected in the editor without having to reload.

## Development workflow

There are a few of tools to help make theme development fast.

### Live Reload

Reloading via `cmd-r` after you make changes to your theme is slow. Atom
supports [live updating][livereload] of styles on Dev Mode Atom windows.

1. Open your theme directory in a dev window by either using the
__File > Open in Dev Mode__ menu or the `cmd-shift-o` shortcut
1. Make a change to your theme file and save &mdash; your change should be
immediately applied!

If you'd like to reload all styles at any time, you can use the shortcut
`cmd-ctrl-shift-r`.

### Developer Tools

Atom is based on the Chrome browser, and supports Chrome's Developer Tools. You
can open them by selecting the __View > Toggle Developer Tools__ menu or by using the
`cmd-option-i` shortcut.

The dev tools allow you to inspect elements and take a look at their CSS
properties.

![devtools-img]

### Atom Styleguide

If you are creating an interface theme, you'll want a way to see how your theme
changes affect all the components in the system. The [styleguide] is a page with
every component Atom supports rendered.

To open the styleguide, open the command palette (`cmd-p`) and search for
_styleguide_ or use the shortcut `cmd-ctrl-shift-g`.

![styleguide-img]

[less]: http://lesscss.org/
[git]: http://git-scm.com/
[atom]: https://atom.io/
[github]: https://github.com/
[less-tutorial]: https://speakerdeck.com/danmatthews/less-css
[devtools-tutorial]: https://developers.google.com/chrome-developer-tools/docs/elements
[ui-variables]: https://github.com/atom/atom-dark-ui/blob/master/stylesheets/ui-variables.less
[livereload]: https://github.com/atom/dev-live-reload
[styleguide]: https://github.com/atom/styleguide
[atom-dark-ui]: https://github.com/atom/atom-dark-ui
[atom-light-ui]: https://github.com/atom/atom-light-ui
[styleguide-img]: https://f.cloud.github.com/assets/69169/1347390/2d431d98-36af-11e3-8f8e-3f4ce1e67adb.png
[devtools-img]: https://f.cloud.github.com/assets/69169/1347391/2d51f91c-36af-11e3-806f-f7b334af43e9.png
[themesettings-img]: https://f.cloud.github.com/assets/69169/1347569/3150bd0c-36b2-11e3-9d69-423503acfe3f.png
