# Style variables

Atom's UI provides a set of variables you can use in your own themes and packages.

## Use in Themes

Each custom theme must specify a `ui-variables.less` file with all of the
following variables defined. The top-most theme specified in the theme settings
will be loaded and available for import.

## Use in Packages

In any of your package's `.less` files, you can access the theme variables
by importing the `ui-variables` file from Atom.

Your package should generally only specify structural styling, and these should
come from [the style guide][styleguide]. Your package shouldn't specify colors,
padding sizes, or anything in absolute pixels. You should instead use the theme
variables. If you follow this guideline, your package will look good out of the
box with any theme!

Here's an example `.less` file that a package can define using theme variables:

```css
@import "ui-variables";

.my-selector {
  background-color: @base-background-color;
  padding: @component-padding;
}
```

## Variables

### Text colors

* `@text-color`
* `@text-color-subtle`
* `@text-color-highlight`
* `@text-color-selected`
* `@text-color-info` - A blue
* `@text-color-success`- A green
* `@text-color-warning`- An orange or yellow
* `@text-color-error` - A red

### Background colors

* `@background-color-info` - A blue
* `@background-color-success` - A green
* `@background-color-warning` - An orange or yellow
* `@background-color-error` - A red
* `@background-color-highlight`
* `@background-color-selected`
* `@app-background-color` - The app's background under all the editor components

### Component colors

* `@base-background-color` -
* `@base-border-color` -

* `@pane-item-background-color` -
* `@pane-item-border-color` -

* `@input-background-color` -
* `@input-border-color` -

* `@tool-panel-background-color` -
* `@tool-panel-border-color` -

* `@inset-panel-background-color` -
* `@inset-panel-border-color` -

* `@panel-heading-background-color` -
* `@panel-heading-border-color` -

* `@overlay-background-color` -
* `@overlay-border-color` -

* `@button-background-color` -
* `@button-background-color-hover` -
* `@button-background-color-selected` -
* `@button-border-color` -

* `@tab-bar-background-color` -
* `@tab-bar-border-color` -
* `@tab-background-color` -
* `@tab-background-color-active` -
* `@tab-border-color` -

* `@tree-view-background-color` -
* `@tree-view-border-color` -

* `@ui-site-color-1` -
* `@ui-site-color-2` -
* `@ui-site-color-3` -
* `@ui-site-color-4` -
* `@ui-site-color-5` -

### Component sizes

* `@disclosure-arrow-size` -

* `@component-padding` -
* `@component-icon-padding` -
* `@component-icon-size` -
* `@component-line-height` -
* `@component-border-radius` -

* `@tab-height` -

### Fonts

* `@font-size` -
* `@font-family` -

[styleguide]: https://github.com/atom/styleguide
