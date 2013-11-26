{Model, Document} = require 'telepath'
Focusable = require '../src/focusable'
FocusManager = require '../src/focus-manager'

describe "Focusable mixin", ->
  it "ensures that focus uniqueness is conserved among all documents with the same focus manager", ->
    class Item extends Model
      Focusable.includeInto(this)
      attached: -> @manageFocus()

    doc = Document.create()
    focusManager = doc.set('focusManager', new FocusManager)
    item1 = doc.set('item1', new Item({focusManager}))
    item2 = doc.set('item2', new Item({focusManager}))
    item3 = doc.set('item3', new Item({focusManager}))

    expect(focusManager.focusedDocument).toBe null
    expect(item1.focused).toBe false
    expect(item2.focused).toBe false
    expect(item3.focused).toBe false

    item1.focused = true
    expect(focusManager.focusedDocument).toBe item1
    expect(item1.focused).toBe true
    expect(item2.focused).toBe false
    expect(item3.focused).toBe false

    item2.focused = true
    expect(focusManager.focusedDocument).toBe item2
    expect(item1.focused).toBe false
    expect(item2.focused).toBe true
    expect(item3.focused).toBe false

    item2.focused = false
    expect(focusManager.focusedDocument).toBe null
    expect(item1.focused).toBe false
    expect(item2.focused).toBe false
    expect(item3.focused).toBe false
