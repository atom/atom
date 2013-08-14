{Site} = require 'telepath'
Environment = require 'environment'

describe "EditSession replication", ->
  [env1, env2, editSession1, editSession2] = []
  beforeEach ->
    env1 = new Environment(siteId: 1)
    env2 = env1.clone(siteId: 2)
    envConnection = env1.connect(env2)
    doc2 = null

    env1.run ->
      editSession1 = project.open('sample.js')
      editSession1.setScrollTop(5)
      editSession1.setScrollLeft(5)
      editSession1.setCursorScreenPosition([0, 5])
      editSession1.addSelectionForBufferRange([[1, 2], [3, 4]])
      doc1 = editSession1.getState()
      doc2 = doc1.clone(env2.site)
      envConnection.connect(doc1, doc2)

    env2.run ->
      editSession2 = deserialize(doc2)

  afterEach ->
    env1.destroy()
    env2.destroy()

  it "replicates the selections of existing replicas", ->
    expect(editSession2.getRemoteSelectedBufferRanges()).toEqual editSession1.getSelectedBufferRanges()

    editSession1.getLastSelection().setBufferRange([[2, 3], [4, 5]])
    expect(editSession2.getRemoteSelectedBufferRanges()).toEqual editSession1.getSelectedBufferRanges()

    editSession1.addCursorAtBufferPosition([5, 6])
    expect(editSession2.getRemoteSelectedBufferRanges()).toEqual editSession1.getSelectedBufferRanges()

    editSession1.consolidateSelections()
    expect(editSession2.getRemoteSelectedBufferRanges()).toEqual editSession1.getSelectedBufferRanges()

  it "introduces a local cursor for a new replica at the position of the last remote cursor", ->
    expect(editSession2.getCursors().length).toBe 1
    expect(editSession2.getSelections().length).toBe 1
    expect(editSession2.getCursorBufferPosition()).toEqual [3, 4]
    expect(editSession2.getSelectedBufferRanges()).toEqual [[[3, 4], [3, 4]]]

    expect(editSession1.getRemoteCursors().length).toBe 1
    expect(editSession1.getRemoteSelections().length).toBe 1
    [cursor] = editSession1.getRemoteCursors()
    [selection] = editSession1.getRemoteSelections()
    expect(cursor.getBufferPosition()).toEqual [3, 4]
    expect(selection.getBufferRange()).toEqual [[3, 4], [3, 4]]

  it "replicates the scroll position", ->
    expect(editSession2.getScrollTop()).toBe editSession1.getScrollTop()
    expect(editSession2.getScrollLeft()).toBe editSession1.getScrollLeft()

    editSession1.setScrollTop(10)
    expect(editSession2.getScrollTop()).toBe 10

    editSession2.setScrollLeft(20)
    expect(editSession1.getScrollLeft()).toBe 20
