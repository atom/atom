{createSite} = require 'telepath'
Editor = require 'editor'

describe "EditSession replication", ->
  [editSession1, editSession2] = []
  beforeEach ->
    editSession1 = project.open('sample.js')
    editSession1.setScrollTop(5)
    editSession1.setScrollLeft(5)
    editSession1.setCursorScreenPosition([0, 5])
    editSession1.addSelectionForBufferRange([[1, 2], [3, 4]])

    doc1 = editSession1.getState()
    doc2 = doc1.clone(createSite(2))
    doc1.connect(doc2)
    editSession2 = deserialize(doc2)

  it "replicates the selections", ->
    expect(editSession2.getSelectedBufferRanges()).toEqual editSession1.getSelectedBufferRanges()

  it "replicates the scroll position", ->
    expect(editSession2.getScrollTop()).toBe editSession1.getScrollTop()
    expect(editSession2.getScrollLeft()).toBe editSession1.getScrollLeft()

    editSession1.setScrollTop(10)
    expect(editSession2.getScrollTop()).toBe 10

    editSession2.setScrollLeft(20)
    expect(editSession1.getScrollLeft()).toBe 20
