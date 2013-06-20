{createSite} = require 'telepath'
{View} = require 'space-pen'
PaneContainer = require 'pane-container'
Pane = require 'pane'

describe "PaneContainer replication", ->
  [container1, pane1a, pane1b, pane1c] = []
  [container2, pane2a, pane2b, pane2c] = []

  class TestView extends View
    @deserialize: ({name}) -> new TestView(name)
    @content: -> @div tabindex: -1
    initialize: (@name) -> @text(@name)
    serialize: -> { deserializer: 'TestView', @name }
    getUri: -> "/tmp/#{@name}"
    isEqual: (other) -> @name is other.name

  beforeEach ->
    registerDeserializer(TestView)
    container1 = new PaneContainer
    pane1a = new Pane(new TestView('A'))
    container1.setRoot(pane1a)
    pane1b = pane1a.splitRight(new TestView('B'))
    pane1c = pane1b.splitDown(new TestView('C'))

    doc1 = container1.serialize()
    doc2 = doc1.clone(createSite(2))
    doc1.connect(doc2)
    container2 = deserialize(doc2)

  afterEach ->
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
