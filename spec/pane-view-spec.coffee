PaneContainer = require '../src/pane-container'
PaneView = require '../src/pane-view'
fs = require 'fs-plus'
{Emitter, Disposable} = require 'event-kit'
{$, View} = require '../src/space-pen-extensions'
path = require 'path'
temp = require 'temp'

describe "PaneView", ->
  [container, containerModel, view1, view2, editor1, editor2, pane, paneModel, deserializerDisposable] = []

  class TestView extends View
    @deserialize: ({id, text}) -> new TestView({id, text})
    @content: ({id, text}) -> @div class: 'test-view', id: id, tabindex: -1, text
    initialize: ({@id, @text}) ->
      @emitter = new Emitter
    serialize: -> {deserializer: 'TestView', @id, @text}
    getURI: -> @id
    isEqual: (other) -> other? and @id is other.id and @text is other.text
    changeTitle: ->
      @emitter.emit 'did-change-title', 'title'
    onDidChangeTitle: (callback) ->
      @emitter.on 'did-change-title', callback
    onDidChangeModified: -> new Disposable(->)

  beforeEach ->
    jasmine.snapshotDeprecations()

    deserializerDisposable = atom.deserializers.add(TestView)
    container = atom.views.getView(new PaneContainer).__spacePenView
    containerModel = container.model
    view1 = new TestView(id: 'view-1', text: 'View 1')
    view2 = new TestView(id: 'view-2', text: 'View 2')
    waitsForPromise ->
      atom.workspace.open('sample.js').then (o) -> editor1 = o

    waitsForPromise ->
      atom.workspace.open('sample.txt').then (o) -> editor2 = o

    runs ->
      pane = container.getRoot()
      paneModel = pane.getModel()
      paneModel.addItems([view1, editor1, view2, editor2])

  afterEach ->
    deserializerDisposable.dispose()
    jasmine.restoreDeprecationsSnapshot()

  describe "when the pane is focused", ->
    beforeEach ->
      container.attachToDom()

    it "transfers focus to the active view", ->
      focusHandler = jasmine.createSpy("focusHandler")
      pane.getActiveItem().on 'focus', focusHandler
      pane.focus()
      expect(focusHandler).toHaveBeenCalled()

    it "makes the pane active", ->
      paneModel.splitRight(items: [pane.copyActiveItem()])
      expect(paneModel.isActive()).toBe false
      pane.focus()
      expect(paneModel.isActive()).toBe true

  describe "when a pane is split", ->
    it "builds the appropriateatom-pane-axis.horizontal and pane-column views", ->
      pane1 = pane
      pane1Model = pane.getModel()
      pane.activateItem(editor1)

      pane2Model = pane1Model.splitRight(items: [pane1Model.copyActiveItem()])
      pane3Model = pane2Model.splitDown(items: [pane2Model.copyActiveItem()])
      pane2 = pane2Model._view
      pane2 = atom.views.getView(pane2Model).__spacePenView
      pane3 = atom.views.getView(pane3Model).__spacePenView

      expect(container.find('> atom-pane-axis.horizontal > atom-pane').toArray()).toEqual [pane1[0]]
      expect(container.find('> atom-pane-axis.horizontal > atom-pane-axis.vertical > atom-pane').toArray()).toEqual [pane2[0], pane3[0]]

      pane1Model.destroy()
      expect(container.find('> atom-pane-axis.vertical > atom-pane').toArray()).toEqual [pane2[0], pane3[0]]

  describe "serialization", ->
    it "focuses the pane after attach only if had focus when serialized", ->
      container.attachToDom()
      pane.focus()

      container2 = atom.views.getView(container.model.testSerialization()).__spacePenView
      pane2 = container2.getRoot()
      container2.attachToDom()
      expect(pane2).toMatchSelector(':has(:focus)')

      $(document.activeElement).blur()
      container3 = atom.views.getView(container.model.testSerialization()).__spacePenView
      pane3 = container3.getRoot()
      container3.attachToDom()
      expect(pane3).not.toMatchSelector(':has(:focus)')

  describe "drag and drop", ->
    buildDragEvent = (type, files) ->
      dataTransfer =
        files: files
        data: {}
        setData: (key, value) -> @data[key] = value
        getData: (key) -> @data[key]

      event = new CustomEvent("drop")
      event.dataTransfer = dataTransfer
      event

    describe "when a file is dragged to window", ->
      it "opens it", ->
        spyOn(atom, "open")
        event = buildDragEvent("drop", [ {path: "/fake1"}, {path: "/fake2"} ])
        pane[0].dispatchEvent(event)
        expect(atom.open.callCount).toBe 1
        expect(atom.open.argsForCall[0][0]).toEqual pathsToOpen: ['/fake1', '/fake2']

    describe "when a non-file is dragged to window", ->
      it "does nothing", ->
        spyOn(atom, "open")
        event = buildDragEvent("drop", [])
        pane[0].dispatchEvent(event)
        expect(atom.open).not.toHaveBeenCalled()
