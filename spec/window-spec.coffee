{$, $$, fs} = require 'atom'
path = require 'path'
WindowEventHandler = require '../src/window-event-handler'

describe "Window", ->
  [projectPath, windowEventHandler] = []

  beforeEach ->
    spyOn(atom, 'hide')
    atom.getLoadSettings() # Causes atom.loadSettings to be initialized
    atom.loadSettings.initialPath = project.getPath()
    project.destroy()
    windowEventHandler = new WindowEventHandler()
    window.deserializeEditorWindow()
    projectPath = project.getPath()

  afterEach ->
    windowEventHandler.unsubscribe()
    $(window).off 'beforeunload'

  describe "when the window is loaded", ->
    it "doesn't have .is-blurred on the body tag", ->
      expect($("body")).not.toHaveClass("is-blurred")

  describe "when the window is blurred", ->
    beforeEach ->
      $(window).triggerHandler 'blur'

    afterEach ->
      $('body').removeClass('is-blurred')

    it "adds the .is-blurred class on the body", ->
      expect($("body")).toHaveClass("is-blurred")

    describe "when the window is focused again", ->
      it "removes the .is-blurred class from the body", ->
        $(window).triggerHandler 'focus'
        expect($("body")).not.toHaveClass("is-blurred")

  describe "window:close event", ->
    it "closes the window", ->
      spyOn(atom, 'close')
      $(window).trigger 'window:close'
      expect(atom.close).toHaveBeenCalled()

    it "emits the beforeunload event", ->
      $(window).off 'beforeunload'
      beforeunload = jasmine.createSpy('beforeunload').andReturn(false)
      $(window).on 'beforeunload', beforeunload

      $(window).trigger 'window:close'
      expect(beforeunload).toHaveBeenCalled()

  describe "beforeunload event", ->
    [beforeUnloadEvent] = []

    beforeEach ->
      beforeUnloadEvent = $.Event(new Event('beforeunload'))

    describe "when pane items are are modified", ->
      it "prompts user to save and and calls rootView.confirmClose", ->
        spyOn(rootView, 'confirmClose').andCallThrough()
        spyOn(atom, "confirmSync").andReturn(2)
        editSession = rootView.openSync("sample.js")
        editSession.insertText("I look different, I feel different.")
        $(window).trigger(beforeUnloadEvent)
        expect(rootView.confirmClose).toHaveBeenCalled()
        expect(atom.confirmSync).toHaveBeenCalled()

      it "prompts user to save and handler returns true if don't save", ->
        spyOn(atom, "confirmSync").andReturn(2)
        editSession = rootView.openSync("sample.js")
        editSession.insertText("I look different, I feel different.")
        $(window).trigger(beforeUnloadEvent)
        expect(atom.confirmSync).toHaveBeenCalled()

      it "prompts user to save and handler returns false if dialog is canceled", ->
        spyOn(atom, "confirmSync").andReturn(1)
        editSession = rootView.openSync("sample.js")
        editSession.insertText("I look different, I feel different.")
        $(window).trigger(beforeUnloadEvent)
        expect(atom.confirmSync).toHaveBeenCalled()

  describe ".unloadEditorWindow()", ->
    it "saves the serialized state of the window so it can be deserialized after reload", ->
      rootViewState = rootView.serialize()
      syntaxState = syntax.serialize()

      window.unloadEditorWindow()

      expect(atom.getWindowState().getObject('rootView')).toEqual rootViewState.toObject()
      expect(atom.getWindowState().getObject('syntax')).toEqual syntaxState
      expect(atom.saveWindowState).toHaveBeenCalled()

    it "unsubscribes from all buffers", ->
      rootView.openSync('sample.js')
      buffer = rootView.getActivePaneItem().buffer
      rootView.getActivePane().splitRight()
      expect(window.rootView.find('.editor').length).toBe 2

      window.unloadEditorWindow()

      expect(buffer.subscriptionCount()).toBe 0

  describe "drag and drop", ->
    buildDragEvent = (type, files) ->
      dataTransfer =
        files: files
        data: {}
        setData: (key, value) -> @data[key] = value
        getData: (key) -> @data[key]

      event = $.Event(type)
      event.originalEvent = { dataTransfer }
      event.preventDefault = ->
      event.stopPropagation = ->
      event

    describe "when a file is dragged to window", ->
      it "opens it", ->
        spyOn(atom, "open")
        event = buildDragEvent("drop", [ {path: "/fake1"}, {path: "/fake2"} ])
        $(document).trigger(event)
        expect(atom.open.callCount).toBe 1
        expect(atom.open.argsForCall[0][0]).toEqual pathsToOpen: ['/fake1', '/fake2']

    describe "when a non-file is dragged to window", ->
      it "does nothing", ->
        spyOn(atom, "open")
        event = buildDragEvent("drop", [])
        $(document).trigger(event)
        expect(atom.open).not.toHaveBeenCalled()

  describe "when a link is clicked", ->
    it "opens the http/https links in an external application", ->
      shell = require 'shell'
      spyOn(shell, 'openExternal')

      $("<a href='http://github.com'>the website</a>").appendTo(document.body).click().remove()
      expect(shell.openExternal).toHaveBeenCalled()
      expect(shell.openExternal.argsForCall[0][0]).toBe "http://github.com"

      shell.openExternal.reset()
      $("<a href='https://github.com'>the website</a>").appendTo(document.body).click().remove()
      expect(shell.openExternal).toHaveBeenCalled()
      expect(shell.openExternal.argsForCall[0][0]).toBe "https://github.com"

      shell.openExternal.reset()
      $("<a href=''>the website</a>").appendTo(document.body).click().remove()
      expect(shell.openExternal).not.toHaveBeenCalled()

      shell.openExternal.reset()
      $("<a href='#scroll-me'>link</a>").appendTo(document.body).click().remove()
      expect(shell.openExternal).not.toHaveBeenCalled()

  describe "core:focus-next and core:focus-previous", ->
    describe "when there is no currently focused element", ->
      it "focuses the element with the lowest/highest tabindex", ->
        elements = $$ ->
          @div =>
            @button tabindex: 2
            @input tabindex: 1

        elements.attachToDom()

        elements.trigger "core:focus-next"
        expect(elements.find("[tabindex=1]:focus")).toExist()

        $(":focus").blur()

        elements.trigger "core:focus-previous"
        expect(elements.find("[tabindex=2]:focus")).toExist()

    describe "when a tabindex is set on the currently focused element", ->
      it "focuses the element with the next highest tabindex", ->
        elements = $$ ->
          @div =>
            @input tabindex: 1
            @button tabindex: 2
            @button tabindex: 5
            @input tabindex: -1
            @input tabindex: 3
            @button tabindex: 7

        elements.attachToDom()
        elements.find("[tabindex=1]").focus()

        elements.trigger "core:focus-next"
        expect(elements.find("[tabindex=2]:focus")).toExist()

        elements.trigger "core:focus-next"
        expect(elements.find("[tabindex=3]:focus")).toExist()

        elements.focus().trigger "core:focus-next"
        expect(elements.find("[tabindex=5]:focus")).toExist()

        elements.focus().trigger "core:focus-next"
        expect(elements.find("[tabindex=7]:focus")).toExist()

        elements.focus().trigger "core:focus-next"
        expect(elements.find("[tabindex=1]:focus")).toExist()

        elements.trigger "core:focus-previous"
        expect(elements.find("[tabindex=7]:focus")).toExist()

        elements.trigger "core:focus-previous"
        expect(elements.find("[tabindex=5]:focus")).toExist()

        elements.focus().trigger "core:focus-previous"
        expect(elements.find("[tabindex=3]:focus")).toExist()

        elements.focus().trigger "core:focus-previous"
        expect(elements.find("[tabindex=2]:focus")).toExist()

        elements.focus().trigger "core:focus-previous"
        expect(elements.find("[tabindex=1]:focus")).toExist()

      it "skips disabled elements", ->
        elements = $$ ->
          @div =>
            @input tabindex: 1
            @button tabindex: 2, disabled: 'disabled'
            @input tabindex: 3

        elements.attachToDom()
        elements.find("[tabindex=1]").focus()

        elements.trigger "core:focus-next"
        expect(elements.find("[tabindex=3]:focus")).toExist()

        elements.trigger "core:focus-previous"
        expect(elements.find("[tabindex=1]:focus")).toExist()
