{createSite} = require 'telepath'
Editor = require 'editor'

describe "EditSession replication", ->
  [editSession1, editSession2] = []
  beforeEach ->
    editSession1 = project.open('sample.js')
    doc1 = editSession1.getState()
    doc2 = doc1.clone(createSite(2))
    doc1.connect(doc2)
    editSession2 = deserialize(doc2)

  it "replicates the scroll position", ->
    editor1 = new Editor(editSession1)
    editor2 = new Editor(editSession2)

    editor1.attachToDom().width(50).height(50)
    editor2.attachToDom().width(50).height(50)

    editor1.scrollTop(10)
    expect(editor1.scrollTop()).toBe 10
    expect(editor2.scrollTop()).toBe 10

    editor2.scrollLeft(20)
    expect(editor2.scrollLeft()).toBe 20
    expect(editor1.scrollLeft()).toBe 20
