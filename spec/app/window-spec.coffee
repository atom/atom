$ = require 'jquery'
fsUtils = require 'fs-utils'
{less} = require 'less'

describe "Window", ->
  projectPath = null

  beforeEach ->
    spyOn(atom, 'getPathToOpen').andReturn(project.getPath())
    window.handleWindowEvents()
    window.deserializeEditorWindow()
    projectPath = project.getPath()

  afterEach ->
    window.unloadEditorWindow()
    $(window).off 'beforeunload'

  describe "when the window is loaded", ->
    it "doesn't have .is-blurred on the body tag", ->
      expect($("body")).not.toHaveClass("is-blurred")

  describe "when the window is blurred", ->
    beforeEach ->
      $(window).trigger 'blur'

    afterEach ->
      $('body').removeClass('is-blurred')

    it "adds the .is-blurred class on the body", ->
      expect($("body")).toHaveClass("is-blurred")

    describe "when the window is focused again", ->
      it "removes the .is-blurred class from the body", ->
        $(window).trigger 'focus'
        expect($("body")).not.toHaveClass("is-blurred")

  describe "window:close event", ->
    describe "when no pane items are modified", ->
      it "calls window.close", ->
        spyOn window, 'close'
        $(window).trigger 'window:close'
        expect(window.close).toHaveBeenCalled()

    describe "when pane items are are modified", ->
      it "prompts user to save and and calls window.close", ->
        spyOn(window, 'close')
        spyOn(atom, "confirm").andCallFake (a, b, c, d, e, f, g, noSave) -> noSave()
        editSession = rootView.open("sample.js")
        editSession.insertText("I look different, I feel different.")
        $(window).trigger 'window:close'
        expect(window.close).toHaveBeenCalled()
        expect(atom.confirm).toHaveBeenCalled()

      it "prompts user to save and aborts if dialog is canceled", ->
        spyOn(window, 'close')
        spyOn(atom, "confirm").andCallFake (a, b, c, d, e, cancel) -> cancel()
        editSession = rootView.open("sample.js")
        editSession.insertText("I look different, I feel different.")
        $(window).trigger 'window:close'
        expect(window.close).not.toHaveBeenCalled()
        expect(atom.confirm).toHaveBeenCalled()

  describe "requireStylesheet(path)", ->
    it "synchronously loads css at the given path and installs a style tag for it in the head", ->
      cssPath = project.resolve('css.css')
      lengthBefore = $('head style').length

      requireStylesheet(cssPath)
      expect($('head style').length).toBe lengthBefore + 1

      element = $('head style[id*="css.css"]')
      expect(element.attr('id')).toBe cssPath
      expect(element.text()).toBe fsUtils.read(cssPath)

      # doesn't append twice
      requireStylesheet(cssPath)
      expect($('head style').length).toBe lengthBefore + 1

      $('head style[id*="css.css"]').remove()

    it "synchronously loads and parses less files at the given path and installs a style tag for it in the head", ->
      lessPath = project.resolve('sample.less')
      lengthBefore = $('head style').length
      requireStylesheet(lessPath)
      expect($('head style').length).toBe lengthBefore + 1

      element = $('head style[id*="sample.less"]')
      expect(element.attr('id')).toBe lessPath
      expect(element.text()).toBe """
      #header {
        color: #4d926f;
      }
      h2 {
        color: #4d926f;
      }

      """

      # doesn't append twice
      requireStylesheet(lessPath)
      expect($('head style').length).toBe lengthBefore + 1
      $('head style[id*="sample.less"]').remove()

    it "supports requiring css and less stylesheets without an explicit extension", ->
      requireStylesheet 'fixtures/css'
      expect($('head style[id*="css.css"]').attr('id')).toBe project.resolve('css.css')
      requireStylesheet 'fixtures/sample'
      expect($('head style[id*="sample.less"]').attr('id')).toBe project.resolve('sample.less')

      $('head style[id*="css.css"]').remove()
      $('head style[id*="sample.less"]').remove()

  describe ".removeStylesheet(path)", ->
    it "removes styling applied by given stylesheet path", ->
      cssPath = require.resolve(fsUtils.join("fixtures", "css.css"))

      expect($(document.body).css('font-weight')).not.toBe("bold")
      requireStylesheet(cssPath)
      expect($(document.body).css('font-weight')).toBe("bold")
      removeStylesheet(cssPath)
      expect($(document.body).css('font-weight')).not.toBe("bold")

  describe ".unloadEditorWindow()", ->
    it "saves the serialized state of the window so it can be deserialized after reload", ->
      projectPath = project.getPath()
      expect(atom.getWindowState()).toEqual {}

      # JSON.stringify removes keys with undefined values
      rootViewState = JSON.parse(JSON.stringify(rootView.serialize()))
      projectState = JSON.parse(JSON.stringify(project.serialize()))
      syntaxState = JSON.parse(JSON.stringify(syntax.serialize()))

      window.unloadEditorWindow()

      windowState = atom.getWindowState()
      expect(windowState.rootView).toEqual rootViewState
      expect(windowState.project).toEqual projectState
      expect(windowState.syntax).toEqual syntaxState

      expect(atom.saveWindowState).toHaveBeenCalled()

    it "unsubscribes from all buffers", ->
      rootView.open('sample.js')
      buffer = rootView.getActivePaneItem().buffer
      rootView.getActivePane().splitRight()
      expect(window.rootView.find('.editor').length).toBe 2

      window.unloadEditorWindow()

      expect(buffer.subscriptionCount()).toBe 0

    it "only serializes window state the first time it is called", ->
      window.unloadEditorWindow()
      window.unloadEditorWindow()
      expect(atom.saveWindowState.callCount).toBe 1

  describe ".installAtomCommand(commandPath)", ->
    commandPath = '/tmp/installed-atom-command/atom'

    afterEach ->
      fsUtils.remove(commandPath) if fsUtils.exists(commandPath)

    describe "when the command path doesn't exist", ->
      it "copies atom.sh to the specified path", ->
        expect(fsUtils.exists(commandPath)).toBeFalsy()
        window.installAtomCommand(commandPath)

        waitsFor ->
          fsUtils.exists(commandPath)

        runs ->
          expect(fsUtils.read(commandPath).length).toBeGreaterThan 1

  describe ".deserialize(state)", ->
    class Foo
      @deserialize: ({name}) -> new Foo(name)
      constructor: (@name) ->

    beforeEach ->
      registerDeserializer(Foo)

    afterEach ->
      unregisterDeserializer(Foo)

    it "calls deserialize on the deserializer for the given state object, or returns undefined if one can't be found", ->
      object = deserialize({ deserializer: 'Foo', name: 'Bar' })
      expect(object.name).toBe 'Bar'
      expect(deserialize({ deserializer: 'Bogus' })).toBeUndefined()

    describe "when the deserializer has a version", ->
      beforeEach ->
        Foo.version = 2

      describe "when the deserialized state has a matching version", ->
        it "attempts to deserialize the state", ->
          object = deserialize({ deserializer: 'Foo', version: 2, name: 'Bar' })
          expect(object.name).toBe 'Bar'

      describe "when the deserialized state has a non-matching version", ->
        it "returns undefined", ->
          expect(deserialize({ deserializer: 'Foo', version: 3, name: 'Bar' })).toBeUndefined()
          expect(deserialize({ deserializer: 'Foo', version: 1, name: 'Bar' })).toBeUndefined()
          expect(deserialize({ deserializer: 'Foo', name: 'Bar' })).toBeUndefined()

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
        window.onDrop(event)
        expect(atom.open.callCount).toBe 2

    describe "when a non-file is dragged to window", ->
      it "does nothing", ->
        spyOn(atom, "open")
        event = buildDragEvent("drop", [])
        window.onDrop(event)
        expect(atom.open).not.toHaveBeenCalled()
