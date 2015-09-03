path = require 'path'
temp = require 'temp'
PaneContainer = require '../src/pane-container'
PaneContainerView = require '../src/pane-container-view'
PaneView = require '../src/pane-view'
{Disposable} = require 'event-kit'
{$, View, $$} = require '../src/space-pen-extensions'

describe "PaneContainerView", ->
  [TestView, container, pane1, pane2, pane3, deserializerDisposable] = []

  beforeEach ->
    class TestView extends View
      deserializerDisposable = atom.deserializers.add(this)
      @deserialize: ({name}) -> new TestView(name)
      @content: -> @div tabindex: -1
      initialize: (@name) -> @text(@name)
      serialize: -> {deserializer: 'TestView', @name}
      getURI: -> path.join(temp.dir, @name)
      save: -> @saved = true
      isEqual: (other) -> @name is other?.name
      onDidChangeTitle: -> new Disposable(->)
      onDidChangeModified: -> new Disposable(->)

    container = atom.views.getView(atom.workspace.paneContainer).__spacePenView
    pane1 = container.getRoot()
    pane1.activateItem(new TestView('1'))
    pane2 = pane1.splitRight(new TestView('2'))
    pane3 = pane2.splitDown(new TestView('3'))

  afterEach ->
    deserializerDisposable.dispose()
