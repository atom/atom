PaneContainer = require '../src/pane-container'
Pane = require '../src/pane'
{Site} = require 'telepath'

describe "Pane replication", ->
  [editSession1a, editSession1b, container1, pane1, doc1] = []
  [editSession2a, editSession2b, container2, pane2, doc2] = []

  beforeEach ->
    editSession1a = project.openSync('sample.js')
    editSession1b = project.openSync('sample.txt')
    container1 = new PaneContainer
    pane1 = new Pane(editSession1a, editSession1b)
    container1.setRoot(pane1)

    doc1 = container1.getState()
    doc2 = doc1.clone(new Site(2))
    doc1.connect(doc2)

    container2 = deserialize(doc2)
    pane2 = container2.getRoot()

  it "replicates the initial state of the panes", ->
    expect(pane2.items).toEqual(pane1.items)

  it "replicates addition and removal of pane items", ->
    pane1.addItem(project.openSync('css.css'), 1)
    expect(pane2.items).toEqual(pane1.items)
    pane1.removeItemAtIndex(2)
    expect(pane2.items).toEqual(pane1.items)

  it "replicates the movement of pane items", ->
    pane1.moveItem(editSession1a, 1)
    expect(pane2.items).toEqual(pane1.items)

  it "replicates which pane item is active", ->
    pane1.showNextItem()
    expect(pane2.activeItem).toEqual pane1.activeItem
    pane1.showNextItem()
    expect(pane2.activeItem).toEqual pane1.activeItem
