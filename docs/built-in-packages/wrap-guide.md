## Wrap Guide

The `wrap-guide` extension places a vertical line in each editor at a certain
column to guide your formatting, so lines do not exceed a certain width.

By default, the wrap-guide is placed at the 80th column.

### Configuration

You can customize where the column is placed using the `wrapGuide.columns`
config option:

```coffeescript
"wrap-guide":
  columns: [
    { pattern: "\.mm$", column: 200 },
    { pattern: "\.cc$", column: 120 }
  ]
```

The above config example would place the guide at the 200th column for paths
that end with `.mm` and place the guide at the 120th column for paths that end
with `.cc`.

You can configure the color and/or width of the line by adding the following
CSS to a custom stylesheet:

```css
.wrap-guide {
  width: 10px;
  background-color: red;
}
```
