{createSite} = require 'telepath'
fsUtils = require 'fs-utils'
Project = require 'project'
Git = require 'git'

describe "Project replication", ->
  [doc1, doc2, project1, project2] = []

  beforeEach ->
    # pretend that home-1/project and home-2/project map to the same git repository url
    spyOn(Git, 'open').andReturn
      getOriginUrl: -> 'git://server/project.git'
      destroy: ->

    config.set('core.projectHome', fsUtils.resolveOnLoadPath('fixtures/replication/home-1'))
    project1 = new Project(fsUtils.resolveOnLoadPath('fixtures/replication/home-1/project'))
    project1.bufferForPath('file-1.txt')
    project1.bufferForPath('file-1.txt')
    expect(project1.getBuffers().length).toBe 1

    doc1 = project1.getState()
    doc2 = doc1.clone(createSite(2))
    connection = doc1.connect(doc2)

    # pretend we're bootstrapping a joining window
    config.set('core.projectHome', fsUtils.resolveOnLoadPath('fixtures/replication/home-2'))
    project2 = deserialize(doc2)

  afterEach ->
    project1.destroy()
    project2.destroy()

  it "replicates the initial path and open buffers of the project", ->
    expect(project2.getPath()).not.toBe project1.getPath()
    expect(project2.getBuffers().length).toBe 1
    expect(project2.getBuffers()[0].getRelativePath()).toBe project1.getBuffers()[0].getRelativePath()
    expect(project2.getBuffers()[0].getPath()).not.toBe project1.getBuffers()[0].getPath()

  it "replicates insertion and removal of open buffers", ->
    project2.bufferForPath('file-2.txt')
    expect(project1.getBuffers().length).toBe 2
    expect(project2.getBuffers()[0].getRelativePath()).toBe project1.getBuffers()[0].getRelativePath()
    expect(project2.getBuffers()[1].getRelativePath()).toBe project1.getBuffers()[1].getRelativePath()
    expect(project2.getBuffers()[0].getRelativePath()).not.toBe project1.getBuffers()[0].getPath()
    expect(project2.getBuffers()[1].getRelativePath()).not.toBe project1.getBuffers()[1].getPath()

    project1.removeBuffer(project1.bufferForPath('file-2.txt'))
    expect(project1.getBuffers().length).toBe 1
    expect(project2.getBuffers()[0].getRelativePath()).toBe project1.getBuffers()[0].getRelativePath()
