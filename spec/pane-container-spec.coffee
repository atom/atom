path = require 'path'
temp = require 'temp'
{Model} = require 'telepath'
PaneContainer = require '../src/pane-container'
Pane = require '../src/pane'
{_, $, View, $$} = require 'atom'

describe "PaneContainer", ->
  [container, pane1, pane2, pane3] = []

  class Item extends Model
    @property 'uri'

  beforeEach ->
    container = PaneContainer.createAsRoot()
    pane1 = container.root
    pane2 = pane1.splitRight()
    pane3 = pane2.splitDown()

  describe "::panes", ->
    it "contains all panes currenly in the container", ->
      expect(container.panes).toEqual [pane1, pane2, pane3]
      pane4 = pane3.splitUp()
      expect(container.panes).toEqual [pane1, pane2, pane4, pane3]
      pane3.remove()
      expect(container.panes).toEqual [pane1, pane2, pane4]

  describe "::paneItems", ->
    it "contains all items of all panes currently in the container", ->
      expect(container.paneItems).toEqual []
      item1 = new Item
      item2 = new Item
      item3 = new Item
      pane1.addItem(item1)
      pane1.addItem(item2)
      pane3.addItem(item3)
      expect(container.paneItems).toEqual [item1, item2, item3]
      pane1.removeItem(item2)
      expect(container.paneItems).toEqual [item1, item3]
      pane1.remove()
      expect(container.paneItems).toEqual [item3]

  describe "::paneForUri(uri)", ->
    it "returns the first pane with an item for the given uri", ->
      expect(container.paneItems).toEqual []
      item1 = new Item(uri: 'a')
      item2 = new Item(uri: 'b')
      pane1.addItem(item1)
      pane2.addItem(item1)
      pane3.addItem(item1)
      pane3.addItem(item2)

      expect(container.paneForUri('a')).toBe pane1
      expect(container.paneForUri('b')).toBe pane3

  describe "::focusNextPane()", ->
    it "focuses the next pane, wrapping around from the end to the beginning", ->
      expect(container.focusedPane).toBeUndefined()
      container.focusNextPane()
      expect(container.focusedPane).toBe pane1
      container.focusNextPane()
      expect(container.focusedPane).toBe pane2
      container.focusNextPane()
      expect(container.focusedPane).toBe pane3
      container.focusNextPane()
      expect(container.focusedPane).toBe pane1

  describe "::focusPreviousPane()", ->
    it "focuses the previous pane, wrapping around from the beginning to the end", ->
      expect(container.focusedPane).toBeUndefined()
      container.focusPreviousPane()
      expect(container.focusedPane).toBe pane3
      container.focusPreviousPane()
      expect(container.focusedPane).toBe pane2
      container.focusPreviousPane()
      expect(container.focusedPane).toBe pane1
      container.focusPreviousPane()
      expect(container.focusedPane).toBe pane3
