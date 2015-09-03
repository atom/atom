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

  describe "changing focus directionally between panes", ->
    [pane1, pane2, pane3, pane4, pane5, pane6, pane7, pane8, pane9] = []

    beforeEach ->
      # Set up a grid of 9 panes, in the following arrangement, where the
      # numbers correspond to the variable names below.
      #
      # -------
      # |1|2|3|
      # -------
      # |4|5|6|
      # -------
      # |7|8|9|
      # -------

      container = atom.views.getView(new PaneContainer).__spacePenView
      pane1 = container.getRoot()
      pane1.activateItem(new TestView('1'))
      pane4 = pane1.splitDown(new TestView('4'))
      pane7 = pane4.splitDown(new TestView('7'))

      pane2 = pane1.splitRight(new TestView('2'))
      pane3 = pane2.splitRight(new TestView('3'))

      pane5 = pane4.splitRight(new TestView('5'))
      pane6 = pane5.splitRight(new TestView('6'))

      pane8 = pane7.splitRight(new TestView('8'))
      pane9 = pane8.splitRight(new TestView('9'))

      container.height(400)
      container.width(400)
      container.attachToDom()

    describe ".focusPaneViewAbove()", ->
      describe "when there are multiple rows above the focused pane", ->
        it "focuses up to the adjacent row", ->
          pane8.focus()
          container.focusPaneViewAbove()
          expect(pane5.activeItem).toMatchSelector ':focus'

      describe "when there are no rows above the focused pane", ->
        it "keeps the current pane focused", ->
          pane2.focus()
          container.focusPaneViewAbove()
          expect(pane2.activeItem).toMatchSelector ':focus'

    describe ".focusPaneViewBelow()", ->
      describe "when there are multiple rows below the focused pane", ->
        it "focuses down to the adjacent row", ->
          pane2.focus()
          container.focusPaneViewBelow()
          expect(pane5.activeItem).toMatchSelector ':focus'

      describe "when there are no rows below the focused pane", ->
        it "keeps the current pane focused", ->
          pane8.focus()
          container.focusPaneViewBelow()
          expect(pane8.activeItem).toMatchSelector ':focus'

    describe ".focusPaneViewOnLeft()", ->
      describe "when there are multiple columns to the left of the focused pane", ->
        it "focuses left to the adjacent column", ->
          pane6.focus()
          container.focusPaneViewOnLeft()
          expect(pane5.activeItem).toMatchSelector ':focus'

      describe "when there are no columns to the left of the focused pane", ->
        it "keeps the current pane focused", ->
          pane4.focus()
          container.focusPaneViewOnLeft()
          expect(pane4.activeItem).toMatchSelector ':focus'

    describe ".focusPaneViewOnRight()", ->
      describe "when there are multiple columns to the right of the focused pane", ->
        it "focuses right to the adjacent column", ->
          pane4.focus()
          container.focusPaneViewOnRight()
          expect(pane5.activeItem).toMatchSelector ':focus'

      describe "when there are no columns to the right of the focused pane", ->
        it "keeps the current pane focused", ->
          pane6.focus()
          container.focusPaneViewOnRight()
          expect(pane6.activeItem).toMatchSelector ':focus'
