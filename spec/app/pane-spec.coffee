Editor = require 'editor'
Pane = require 'pane'
{$$} = require 'space-pen'

describe "Pane", ->
  [view1, view2, editSession1, editSession2, pane] = []

  beforeEach ->
    view1 = $$ -> @div id: 'view-1', 'View 1'
    view2 = $$ -> @div id: 'view-1', 'View 1'
    editSession1 = project.buildEditSession('sample.js')
    editSession2 = project.buildEditSession('sample.txt')
    pane = new Pane(view1, editSession1, view2, editSession2)

  describe ".initialize(items...)", ->
    it "displays the first item in the pane", ->
      expect(pane.itemViews.find(view1)).toExist()
