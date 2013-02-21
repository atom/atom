PaneContainer = require 'pane-container'
Pane = require 'pane'
{View} = require 'space-pen'
$ = require 'jquery'

describe "PaneContainer", ->
  [TestView, container, pane1, pane2, pane3] = []

  beforeEach ->
    class TestView extends View
      registerDeserializer(this)
      @deserialize: ({myText}) -> new TestView(myText)
      @content: -> @div tabindex: -1
      initialize: (@myText) -> @text(@myText)
      serialize: -> deserializer: 'TestView', myText: @myText

    container = new PaneContainer
    pane1 = new Pane(new TestView('1'))
    container.append(pane1)
    pane2 = pane1.splitRight(new TestView('2'))
    pane3 = pane2.splitDown(new TestView('3'))

  afterEach ->
    unregisterDeserializer(TestView)

  describe ".focusNextPane()", ->
    it "focuses the pane following the focused pane or the first pane if no pane has focus", ->
      container.attachToDom()
      container.focusNextPane()
      expect(pane1.currentItem).toMatchSelector ':focus'
      container.focusNextPane()
      expect(pane2.currentItem).toMatchSelector ':focus'
      container.focusNextPane()
      expect(pane3.currentItem).toMatchSelector ':focus'
      container.focusNextPane()
      expect(pane1.currentItem).toMatchSelector ':focus'

  describe "serialization", ->
    it "can be serialized and deserialized, and correctly adjusts dimensions of deserialized panes after attach", ->
      newContainer = deserialize(container.serialize())
      expect(newContainer.find('.row > :contains(1)')).toExist()
      expect(newContainer.find('.row > .column > :contains(2)')).toExist()
      expect(newContainer.find('.row > .column > :contains(3)')).toExist()

      newContainer.height(200).width(300).attachToDom()
      expect(newContainer.find('.row > :contains(1)').width()).toBe 150
      expect(newContainer.find('.row > .column > :contains(2)').height()).toBe 100
