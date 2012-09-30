## Welcome to the Atom guide

## Extensions

### Wrap Guide

The wrap-guide extension places a vertical line in each editor at a certain
column to guide your formatting so lines do not exceed a certain width.

By default the wrap-guide is placed at the 80th column.

#### Configuration

You can configure where this column is on a per-path basis using the following
configuration data options:

```coffeescript
wrapGuideConfig =
  getGuideColumn: (path, defaultColumn) ->
    if path.indexOf('.mm', path.length - 3) isnt -1
      return -1 # Disable the guide for Objective-C files
    else
      return defaultColumn
requireExtension 'wrap-guide', wrapGuideConfig
```

You can configure the color and/or width of the line by adding the following
CSS to a custom stylesheet:

```css
.wrap-guide {
  width: 10px;
  background-color: red;
}
```
