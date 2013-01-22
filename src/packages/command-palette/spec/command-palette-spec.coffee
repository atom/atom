RootView = require 'root-view'
CommandPalette = require 'command-palette/src/command-palette-view'
$ = require 'jquery'
_ = require 'underscore'

describe "CommandPalette", ->
  [rootView, palette] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    atom.loadPackage("command-palette")
    palette = CommandPalette.instance
    rootView.attachToDom().focus()
    rootView.trigger 'command-palette:toggle'

  afterEach ->
    rootView.remove()

  describe "when command-palette:toggle is triggered on the root view", ->
    it "shows a list of all valid command descriptions, names, and keybindings for the previously focused element", ->
      keyBindings = _.losslessInvert(keymap.bindingsForElement(rootView.getActiveEditor()))
      for eventName, description of rootView.getActiveEditor().events()
        eventLi = palette.list.children("[data-event-name='#{eventName}']")
        if description
          expect(eventLi).toExist()
          expect(eventLi.find('.event-name')).toHaveText(eventName)
          expect(eventLi.find('.event-description')).toHaveText(description)
          for binding in keyBindings[eventName] ? []
            expect(eventLi.find(".key-binding:contains(#{binding})")).toExist()
        else
          expect(eventLi).not.toExist()

    it "displays all commands registerd on the window", ->
      editorEvents = rootView.getActiveEditor().events()
      windowEvents = $(window).events()
      expect(_.isEmpty(windowEvents)).toBeFalsy()
      for eventName, description of windowEvents
        eventLi = palette.list.children("[data-event-name='#{eventName}']")
        description = editorEvents[eventName] unless description
        if description
          expect(eventLi).toExist()
          expect(eventLi.find('.event-name')).toHaveText(eventName)
          expect(eventLi.find('.event-description')).toHaveText(description)
        else
          expect(eventLi).not.toExist()

    it "focuses the mini-editor and selects the first command", ->
      expect(palette.miniEditor.isFocused).toBeTruthy()
      expect(palette.find('.event:first')).toHaveClass 'selected'

    it "clears the previous mini editor text", ->
      palette.miniEditor.setText('hello')
      palette.trigger 'command-palette:toggle'
      rootView.trigger 'command-palette:toggle'
      expect(palette.miniEditor.getText()).toBe ''

  describe "when command-palette:toggle is triggered on the open command palette", ->
    it "focus the root view and detaches the command palette", ->
      expect(palette.hasParent()).toBeTruthy()
      palette.trigger 'command-palette:toggle'
      expect(palette.hasParent()).toBeFalsy()
      expect(rootView.getActiveEditor().isFocused).toBeTruthy()

  describe "when the command palette is cancelled", ->
    it "focuses the root view and detaches the command palette", ->
      expect(palette.hasParent()).toBeTruthy()
      palette.cancel()
      expect(palette.hasParent()).toBeFalsy()
      expect(rootView.getActiveEditor().isFocused).toBeTruthy()

  describe "when an command selection is confirmed", ->
    it "detaches the palette, then focuses the previously focused element and emits the selected command on it", ->
      eventHandler = jasmine.createSpy 'eventHandler'
      activeEditor = rootView.getActiveEditor()
      {eventName} = palette.array[5]
      activeEditor.preempt eventName, eventHandler

      palette.confirmed(palette.array[5])

      expect(activeEditor.isFocused).toBeTruthy()
      expect(eventHandler).toHaveBeenCalled()
      expect(palette.hasParent()).toBeFalsy()
