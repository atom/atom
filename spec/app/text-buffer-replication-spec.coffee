{Site} = require 'telepath'

describe "TextBuffer replication", ->
  [buffer1, buffer2] = []

  beforeEach ->
    buffer1 = project.buildBuffer('sample.js')
    buffer1.insert([0, 0], 'changed\n')
    doc1 = buffer1.getState()
    doc2 = doc1.clone(new Site(2))
    doc1.connect(doc2)
    buffer2 = deserialize(doc2, {project})

  afterEach ->
    buffer1.destroy()
    buffer2.destroy()

  it "replicates the initial path and text", ->
    expect(buffer2.getPath()).toBe buffer1.getPath()
    expect(buffer2.getText()).toBe buffer1.getText()

  it "replicates changes to the text and emits 'change' events on all replicas", ->
    buffer1.on 'changed', handler1 = jasmine.createSpy("buffer1 change handler")
    buffer2.on 'changed', handler2 = jasmine.createSpy("buffer2 change handler")

    buffer1.change([[1, 4], [1, 6]], 'h')
    expect(buffer1.lineForRow(1)).toBe 'var hicksort = function () {'
    expect(buffer2.lineForRow(1)).toBe 'var hicksort = function () {'

    expect(buffer1.isModified()).toBeTruthy()
    expect(buffer2.isModified()).toBeTruthy()

    expectedEvent =
      oldRange: [[1, 4], [1, 6]]
      oldText: "qu"
      newRange: [[1, 4], [1, 5]]
      newText: "h"
    expect(handler1).toHaveBeenCalledWith(expectedEvent)
    expect(handler2).toHaveBeenCalledWith(expectedEvent)
    expect(handler1.callCount).toBe 1
    expect(handler2.callCount).toBe 1
