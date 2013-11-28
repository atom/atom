path = require 'path'
temp = require 'temp'
PaneContainer = require '../src/pane-container'
Pane = require '../src/pane'
{_, $, View, $$} = require 'atom'

describe "PaneContainer", ->
  [container, pane1, pane2, pane3] = []

  beforeEach ->
    container = PaneContainer.createAsRoot()
    pane1 = container.root
    pane2 = pane1.splitRight()
    pane3 = pane2.splitDown()

  describe "::panes", ->
    it "contains all panes currenly in the container", ->
      expect(container.panes).toEqual [pane1, pane2, pane3]
      pane4 = pane3.splitUp()
      console.log container.root.panes.map('id')
      expect(container.panes).toEqual [pane1, pane2, pane4, pane3]
