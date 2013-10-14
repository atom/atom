{{{
"title": "Creating a Theme"
}}}

# Creating a Theme

## Overview

Atom is built using web technologies, the interface is rendered using HTML and
it's styled via [LESS] (a superset of CSS). Don't worry if you haven't
heard of LESS before, it's just like CSS but with a few handy extensions.

Since CSS is the basis of the theming system, we can load multiple themes within
Atom and it behaves just like a website. Themes loaded first are overridden by
themes which are loaded later (the order is controlled from within the Settings
pane).

This flexibility is helpful for users which prefer a light interface with a dark
syntax theme. Atom only has interface and syntax themes currently but it's easy
see how one might want to create their own  language specific syntax theme for
very specific styling.

## Getting Started

To create your own theme you'll need a few things:

* A working install of [Atom], so you can work on your new theme.
* A working install of [git] to track changes.
* A [GitHub] account, so you can distribute your themes.

Themes are pretty straight forward but it's still helpful to be familiar with
a few things before starting:

* LESS is a superset of CSS but it's got some really handy features like
  variables. If you aren't familiar with it's syntax take a few minutes
  to [familiarize yourself][less-tutorial].
* Atom uses Chrome at it's core, so you can use Chrome devtools to
  inspect the current state of the interface. Checkout Google's
  [extensive tutorial][devtools-tutorial] for a short introduction.

# Creating a Minimal Syntax Theme

1. Open the Command Palette (`cmd+p`)
1. Search for `Package Generator: Generate Theme` and select it.
1. Choose a name for the folder which will contain your theme.
1. An Atom window will open with your newly created theme.
  1. Open `package.json` and update the relevant parts.
  1. Open `stylesheets/colors.less` to change the various colors variables which
     have been already been defined.
  1. Open `stylesheets/base.less` and modify the various syntax CSS selectors that
     have been already been defined.
  1. When you're ready update the `README.md` and include an example screenshot of
     your new theme in action.
1. Open a terminal, find your new theme's directory, initialize the git repository
   and push it to repository on  GitHub.
1. Once you're ready for others to use your theme run `apm publish` from within
   that directory to make it available to other Atom users.

## Interface Themes

There are only two differences between interface and syntax themes - what
they target and what they provide. Interface themes only target elements which
are outside of the editor and **must** provide a `ui-variables.less` file which
contains all of the variables provided by the [core themes][ui-variables].
Syntax themes don't need to provide any variables to other themes and only
target elements within the editor.

## How to Style a Specific Element

Once you've got the basics down you'll find that there will be changes you want
to make but you aren't sure how to reference an element. That's when the
devtools become really useful, just open them up (`cmd+alt+i`), switch to the
`Elements` tab and inspect the element you're interested in.

[LESS]: http://lesscss.org/
[git]: http://git-scm.com/
[Atom]: https://atom.io/
[GitHub]: https://github.com/
[less-tutorial]: https://speakerdeck.com/danmatthews/less-css
[devtools-tutorial]: https://developers.google.com/chrome-developer-tools/docs/elements
[ui-variables]: https://github.com/atom/atom-dark-ui/blob/master/stylesheets/ui-variables.less
