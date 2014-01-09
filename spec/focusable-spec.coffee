{Model} = require 'theorist'
Focusable = require '../src/focusable'
FocusContext = require '../src/focus-context'

describe "Focusable mixin", ->
  it "ensures that only a single model is focused for a given focus manager", ->
    class Item extends Model
      Focusable.includeInto(this)

    focusContext = new FocusContext
    item1 = new Item({focusContext})
    item2 = new Item({focusContext})
    item3 = new Item({focusContext})

    expect(focusContext.focusedObject).toBe null
    expect(item1.focused).toBe false
    expect(item2.focused).toBe false
    expect(item3.focused).toBe false

    item1.focus()
    expect(focusContext.focusedObject).toBe item1
    expect(item1.focused).toBe true
    expect(item2.focused).toBe false
    expect(item3.focused).toBe false

    item2.focus()
    expect(focusContext.focusedObject).toBe item2
    expect(item1.focused).toBe false
    expect(item2.focused).toBe true
    expect(item3.focused).toBe false

    item2.blur()
    expect(focusContext.focusedObject).toBe null
    expect(item1.focused).toBe false
    expect(item2.focused).toBe false
    expect(item3.focused).toBe false
