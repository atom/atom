### Wrap Guide

The `wrap-guide` extension places a vertical line in each editor at a certain
column to guide your formatting so lines do not exceed a certain width.

By default the wrap-guide is placed at the 80th column.

#### Configuration

Setting the wrap guide column still needs to be converted to the new config
system. Bug someone if you find this and we still haven't done it.

You can configure the color and/or width of the line by adding the following
CSS to a custom stylesheet:

```css
.wrap-guide {
  width: 10px;
  background-color: red;
}
```
