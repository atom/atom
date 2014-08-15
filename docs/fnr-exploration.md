# Find and replace speedup investigation

Find and replace is slow when there are a lot of matches on the page.

## Test junk

I'm testing with `editor-view.coffee` and searching for a single space. There are 9871 spaces in `editor-view.coffee`. I added a command to find and replace that creates a profile.

```coffee
@subscriber.subscribeToCommand atom.workspaceView, 'find-and-replace:find-space-profile', =>
  @findView.findEditor.setText ''
  @findView.updateModel pattern: ''

  console.profile('find spaces')
  console.time('find spaces')
  @findView.findEditor.setText ' '
  @findView.updateModel pattern: ' '
  console.timeEnd('find spaces')
  console.profileEnd('find spaces')
```

## Baseline

As the code is today it takes ~1500ms to do this. Much of the time spent in `SpanSkipList::totalTo`. But there is a whole lot else costing time.

It didnt fluctuate much, ~1490ms - 1590ms.

![baseline](https://cloud.githubusercontent.com/assets/69169/3914724/4337a990-234c-11e4-870c-3ea06c0342dc.png)

## Experiment with removing totalTo

I wondered, was the skip list helping us?

~1280ms; 1260ms - 1360ms

```coffee
# dumb algorithm
positionForCharacterIndex: (offset) ->
  offset = Math.max(0, offset)
  offset = Math.min(@getText().length, offset)

  row = 0
  column = 0
  for line in @lines
    if line.length < offset
      offset -= line.length + @lineEndingForRow(row).length
      row++
    else
      column = offset
      break

  if row > @getLastRow()
    @getEndPosition()
  else
    new Point(row, column)
```

![no skip list](https://cloud.githubusercontent.com/assets/69169/3914767/36263b8a-234d-11e4-9837-13f302d8805f.png)

It's consistently a litte faster than `totalTo`, but also reduces the GC pressure.

## Remove the places it emits slow

Emitter was recently updated to optimize the single arg case. And all of the decotation events were using 2 params. Reduced them to 1, and git a little bit.

It is consistently in the mid-low 1200ms range, and `emitSlow` is no longer being called.

![fixing decoration-added events](https://cloud.githubusercontent.com/assets/69169/3914801/21e5a740-234e-11e4-9ee3-9fbb692cd53a.png)

## Attempt to optimize the emitter.

Is the emitter doing too much? Making too many temp objects?

## No decorations

How much faster is it with out decorations? A little bit less GC pressure.

820 - 900

![no decorations](https://cloud.githubusercontent.com/assets/69169/3914920/4f1176c4-2351-11e4-80b0-bcd23821cf7a.png)

## No markers

How much faster is it with out markers and no decorations?

210ms - 240ms

Whoa. Now, it's all about finding the position in char range. The GC isnt even in the picture.

![no markers](https://cloud.githubusercontent.com/assets/69169/3914913/db1a84cc-2350-11e4-986f-f2feab722cde.png)
