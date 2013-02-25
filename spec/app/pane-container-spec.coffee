PaneContainer = require 'pane-container'
Pane = require 'pane'
{View, $$} = require 'space-pen'
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

  describe ".getActivePane()", ->
    it "returns the most-recently focused pane", ->
      focusStealer = $$ -> @div tabindex: -1, "focus stealer"
      focusStealer.attachToDom()
      container.attachToDom()

      pane2.focus()
      expect(container.getFocusedPane()).toBe pane2
      expect(container.getActivePane()).toBe pane2

      focusStealer.focus()
      expect(container.getFocusedPane()).toBeUndefined()
      expect(container.getActivePane()).toBe pane2

      pane3.focus()
      expect(container.getFocusedPane()).toBe pane3
      expect(container.getActivePane()).toBe pane3

      # returns the first pane if none have been set to active
      container.find('.pane.active').removeClass('active')
      expect(container.getActivePane()).toBe pane1

  describe ".eachPane(callback)", ->
    it "runs the callback with all current and future panes until the subscription is cancelled", ->
      panes = []
      subscription = container.eachPane (pane) -> panes.push(pane)
      expect(panes).toEqual [pane1, pane2, pane3]

      panes = []
      pane4 = pane3.splitRight()
      expect(panes).toEqual [pane4]

      panes = []
      subscription.cancel()
      pane4.splitDown()
      expect(panes).toEqual []

  describe "serialization", ->
    it "can be serialized and deserialized, and correctly adjusts dimensions of deserialized panes after attach", ->
      newContainer = deserialize(container.serialize())
      expect(newContainer.find('.row > :contains(1)')).toExist()
      expect(newContainer.find('.row > .column > :contains(2)')).toExist()
      expect(newContainer.find('.row > .column > :contains(3)')).toExist()

      newContainer.height(200).width(300).attachToDom()
      expect(newContainer.find('.row > :contains(1)').width()).toBe 150
      expect(newContainer.find('.row > .column > :contains(2)').height()).toBe 100
