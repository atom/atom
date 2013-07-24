{createSite} = require 'telepath'
fsUtils = require 'fs-utils'
Project = require 'project'

describe "Project replication", ->
  [project1, project2] = []

  beforeEach ->
    project1 = new Project(fsUtils.resolveOnLoadPath('fixtures/dir'))
    project1.bufferForPath('a')
    project1.bufferForPath('a')
    expect(project1.getBuffers().length).toBe 1

    doc1 = project1.getState()
    doc2 = doc1.clone(createSite(2))
    doc1.connect(doc2)

    project2 = deserialize(doc2)

  afterEach ->
    project1.destroy()
    project2.destroy()

  it "replicates the initial path and open buffers of the project", ->
    expect(project2.getPath()).toBe project1.getPath()
    expect(project2.getBuffers().length).toBe 1
    expect(project2.getBuffers()[0].getPath()).toBe project1.getBuffers()[0].getPath()

  it "replicates insertion and removal of open buffers", ->
    bufferB = project2.bufferForPath('b')
    expect(project1.getBuffers().length).toBe 2
    expect(project2.getBuffers()[0].getPath()).toBe project1.getBuffers()[0].getPath()
    expect(project2.getBuffers()[1].getPath()).toBe project1.getBuffers()[1].getPath()

    project1.removeBuffer(project1.bufferForPath('b'))
    expect(project1.getBuffers().length).toBe 1
    expect(project2.getBuffers()[0].getPath()).toBe project1.getBuffers()[0].getPath()
