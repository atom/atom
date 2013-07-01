{createSite} = require 'telepath'
TextBuffer = require 'text-buffer'

describe "TextBuffer replication", ->
  [buffer1, buffer2] = []

  beforeEach ->
    buffer1 = new TextBuffer(project.resolve('sample.js'))
    buffer1.insert([0, 0], 'changed\n')
    doc1 = buffer1.getState()
    doc2 = doc1.clone(createSite(2))
    doc1.connect(doc2)
    buffer2 = deserialize(doc2)

  afterEach ->
    buffer1.destroy()
    buffer2.destroy()

  it "replicates the initial path and text of the buffer", ->
    expect(buffer2.getPath()).toBe buffer1.getPath()
    expect(buffer2.getText()).toBe buffer1.getText()
