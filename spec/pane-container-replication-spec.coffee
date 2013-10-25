path = require 'path'
temp = require 'temp'
{Site} = require 'telepath'
{View} = require 'atom'
PaneContainer = require '../src/pane-container'
Pane = require '../src/pane'
Environment = require './environment'

describe "PaneContainer replication", ->
  [env1, env2, envConnection, container1, container2, pane1a, pane1b, pane1c] = []

  class TestView extends View
    @deserialize: ({name}) -> new TestView(name)
    @content: -> @div tabindex: -1
    initialize: (@name) -> @text(@name)
    serialize: -> { deserializer: 'TestView', @name }
    getState: -> @serialize()
    getUri: -> path.join(temp.dir, @name)
    isEqual: (other) -> @name is other.name

  beforeEach ->
    registerDeserializer(TestView)

    env1 = new Environment(siteId: 1)
    env2 = env1.clone(siteId: 2)
    envConnection = env1.connect(env2)
    doc2 = null

    env1.run ->
      container1 = new PaneContainer
      pane1a = new Pane(new TestView('A'))
      container1.setRoot(pane1a)
      pane1b = pane1a.splitRight(new TestView('B'))
      pane1c = pane1b.splitDown(new TestView('C'))

      doc1 = container1.getState()
      doc2 = doc1.clone(env2.site)
      envConnection.connect(doc1, doc2)

    env2.run ->
      container2 = deserialize(doc2)

  afterEach ->
    env1.destroy()
    env2.destroy()
    unregisterDeserializer(TestView)

  it "replicates the inital state of a pane container with splits", ->
    expect(container1.find('.row > :eq(0):contains(A)')).toExist()
    expect(container1.find('.row > :eq(1)')).toHaveClass 'column'
    expect(container1.find('.row > :eq(1) > :eq(0):contains(B)')).toExist()
    expect(container1.find('.row > :eq(1) > :eq(1):contains(C)')).toExist()

    expect(container2.find('.row > :eq(0):contains(A)')).toExist()
    expect(container2.find('.row > :eq(1)')).toHaveClass 'column'
    expect(container2.find('.row > :eq(1) > :eq(0):contains(B)')).toExist()
    expect(container2.find('.row > :eq(1) > :eq(1):contains(C)')).toExist()

  it "replicates the splitting of panes", ->
    container1.attachToDom().width(400).height(200)
    container2.attachToDom().width(400).height(200)

    pane1d = pane1a.splitRight(new TestView('D'))

    expect(container1.find('.row > :eq(1):contains(D)')).toExist()
    expect(container2.find('.row > :eq(1):contains(D)')).toExist()

    expect(container2.find('.row > :eq(1):contains(D)').outerWidth()).toBe container1.find('.row > :eq(1):contains(D)').outerWidth()

    pane1d.splitDown(new TestView('E'))

    expect(container1.find('.row > :eq(1)')).toHaveClass('column')
    expect(container1.find('.row > :eq(1) > :eq(0):contains(D)')).toExist()
    expect(container1.find('.row > :eq(1) > :eq(1):contains(E)')).toExist()

    expect(container2.find('.row > :eq(1)')).toHaveClass('column')
    expect(container2.find('.row > :eq(1) > :eq(0):contains(D)')).toExist()
    expect(container2.find('.row > :eq(1) > :eq(1):contains(E)')).toExist()

  it "replicates removal of panes", ->
    pane1c.remove()

    expect(container1.find('.row > :eq(0):contains(A)')).toExist()
    expect(container1.find('.row > :eq(1):contains(B)')).toExist()
    expect(container2.find('.row > :eq(0):contains(A)')).toExist()
    expect(container2.find('.row > :eq(1):contains(B)')).toExist()

    pane1b.remove()

    expect(container1.find('> :eq(0):contains(A)')).toExist()
    expect(container2.find('> :eq(0):contains(A)')).toExist()

    pane1a.remove()

    expect(container1.children()).not.toExist()
    expect(container2.children()).not.toExist()

  # FIXME: We need to get this passing again on master
  xit "replicates splitting of panes containing edit sessions", ->
    env1.run ->
      pane1a.showItem(project.openSync('dir/a'))
      pane1a.splitDown()

      expect(project.getBuffers().length).toBe 1
      expect(container1.find('.row > :eq(0) > :eq(0)').view().activeItem.getRelativePath()).toBe 'dir/a'
      expect(container1.find('.row > :eq(0) > :eq(1)').view().activeItem.getRelativePath()).toBe 'dir/a'

    env2.run ->
      expect(container2.find('.row > :eq(0) > :eq(0)').view().activeItem.getRelativePath()).toBe 'dir/a'
      expect(container2.find('.row > :eq(0) > :eq(1)').view().activeItem.getRelativePath()).toBe 'dir/a'
