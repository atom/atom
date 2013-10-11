{Site} = require 'telepath'
Editor = require '../src/editor'
Environment = require './environment'

describe "Editor replication", ->
  [env1, env2, editSession1, editSession2, editor1, editor2] = []

  beforeEach ->
    env1 = new Environment(siteId: 1)
    env2 = env1.clone(siteId: 2)
    envConnection = env1.connect(env2)
    doc2 = null

    env1.run ->
      editSession1 = project.openSync('sample.js')
      editSession1.setSelectedBufferRange([[1, 2], [3, 4]])
      doc1 = editSession1.getState()
      doc2 = doc1.clone(env2.site)
      envConnection.connect(doc1, doc2)
      editor1 = new Editor(editSession1)
      editor1.attachToDom()

    env2.run ->
      editSession2 = deserialize(doc2)
      editor2 = new Editor(editSession2)
      editor2.attachToDom()

  afterEach ->
    env1.destroy()
    env2.destroy()

  it "displays the cursors and selections from all replicas", ->
    expect(editor1.getSelectionViews().length).toBe 2
    expect(editor2.getSelectionViews().length).toBe 2

    expect(editor1.getCursorViews().length).toBe 2
    expect(editor2.getCursorViews().length).toBe 2
