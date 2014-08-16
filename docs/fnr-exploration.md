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

## Optimizing Marker creation

So our largest chunk of time is spent creating markers. How slow is marker creation compared to regular object creation + emit

![benchmarks](https://cloud.githubusercontent.com/assets/69169/3939214/2dc9d96a-24c4-11e4-8d3f-757a14b6a60f.png)

It's a lot slower.

This The profile for marker-creation:

![marker-creation-from-buffer](https://cloud.githubusercontent.com/assets/69169/3939227/74b32da4-24c4-11e4-8468-c3098b35b0a4.png)

The profile looked like we were spending some time in `Range.toObject`. Is there a difference between `new Range(new Point(row, 0), new Point(row, 1))` and `[[row, 0], [row, 1]]`? Yeah, and it's pretty big

![use point and range](https://cloud.githubusercontent.com/assets/69169/3939920/7daf04f8-24d0-11e4-9a0d-9b8cdd87f43b.png)

Could optimize it to not use `args...`? __YES__

```coffee
@fromObject: (object, copy) ->
  if Array.isArray(object)
    new this(...)
```

to

```coffee
@fromObject: (object, copy) ->
  if Array.isArray(object)
    [pointA, pointB] = object
    new this(pointA, pointB)
```

And now they are equal performance!

![Optimize range](https://cloud.githubusercontent.com/assets/69169/3939966/83850264-24d1-11e4-81f0-43fc2ed39dc0.png)

### Marker creation in Atom vs TextBuffer

Creation is fast on the text-buffer side, and ~3x+ slower on the atom side. What are we doing?

![atom vs text-buffer](https://cloud.githubusercontent.com/assets/69169/3940109/6962e758-24d5-11e4-92d7-3384f4f98116.png)

Looks like we're spending a lot more time (~4x!) in the garbage collector and a whole lot more time emitting events.

![profile-from-editor](https://cloud.githubusercontent.com/assets/69169/3940132/15fdc6c2-24d6-11e4-8b31-6d4780bf3fba.png)

![profile-from-text-buffer](https://cloud.githubusercontent.com/assets/69169/3940131/15fab5a4-24d6-11e4-8d57-258c4c390b96.png)

#### Subscribing is slow

Commenting out the changed and destroyed handlers in `DisplayBufferMarker` cut the time in _half_.

```coffee
# @subscribe @bufferMarker, 'destroyed', => @destroyed()
# @subscribe @bufferMarker, 'changed', (event) => @notifyObservers(event)
```

![less subscribing](https://cloud.githubusercontent.com/assets/69169/3940319/a1c6c3de-24db-11e4-8da8-bd320b1b1b34.png)

Even using `on` rather than subscribe is faster:

![using on](https://cloud.githubusercontent.com/assets/69169/3940321/d4f5bd96-24db-11e4-8dd6-397c724adbd6.png)
