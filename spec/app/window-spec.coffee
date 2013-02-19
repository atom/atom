$ = require 'jquery'
fs = require 'fs'

describe "Window", ->
  [rootView] = []

  beforeEach ->
    window.handleWindowEvents()
    spyOn(atom, 'getPathToOpen').andReturn(project.getPath())
    window.buildProjectAndRootView()
    rootView = window.rootView

  afterEach ->
    window.stopApplication()
    atom.setRootViewStateForPath(rootView.project.getPath(), null)
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

  describe ".close()", ->
    it "is triggered by the 'core:close' event", ->
      spyOn window, 'close'
      $(window).trigger 'core:close'
      expect(window.close).toHaveBeenCalled()

    it "is triggered by the 'window:close event'", ->
      spyOn window, 'close'
      $(window).trigger 'window:close'
      expect(window.close).toHaveBeenCalled()

  describe ".reload()", ->
    it "returns false when no buffers are modified", ->
      spyOn($native, "reload")
      window.reload()
      expect($native.reload).toHaveBeenCalled()

    it "shows alert when a modifed buffer exists", ->
      rootView.open('sample.js')
      rootView.getActiveEditor().insertText("hi")
      spyOn(atom, "confirm")
      spyOn($native, "reload")
      window.reload()
      expect($native.reload).not.toHaveBeenCalled()
      expect(atom.confirm).toHaveBeenCalled()

  describe "requireStylesheet(path)", ->
    it "synchronously loads the stylesheet at the given path and installs a style tag for it in the head", ->
      $('head style[id*="atom.css"]').remove()
      lengthBefore = $('head style').length
      requireStylesheet('atom.css')
      expect($('head style').length).toBe lengthBefore + 1

      styleElt = $('head style[id*="atom.css"]')

      fullPath = require.resolve('atom.css')
      expect(styleElt.attr('id')).toBe fullPath
      expect(styleElt.text()).toBe fs.read(fullPath)

      # doesn't append twice
      requireStylesheet('atom.css')
      expect($('head style').length).toBe lengthBefore + 1

  describe ".disableStyleSheet(path)", ->
    it "removes styling applied by given stylesheet path", ->
      cssPath = require.resolve(fs.join("fixtures", "css.css"))

      expect($(document.body).css('font-weight')).not.toBe("bold")
      requireStylesheet(cssPath)
      expect($(document.body).css('font-weight')).toBe("bold")
      removeStylesheet(cssPath)
      expect($(document.body).css('font-weight')).not.toBe("bold")

  describe "stopApplication()", ->
    it "saves the serialized state of the project and root view to the atom object so it can be rehydrated after reload", ->
      expect(atom.getRootViewStateForPath(rootView.project.getPath())).toBeUndefined()
      # JSON.stringify removes keys with undefined values
      rootViewState = JSON.parse(JSON.stringify(rootView.serialize()))
      projectState = JSON.parse(JSON.stringify(project.serialize()))

      stopApplication()

      expect(atom.getRootViewStateForPath(project.getPath())).toEqual
        project: projectState
        rootView: rootViewState

    it "unsubscribes from all buffers", ->
      rootView.open('sample.js')
      editor1 = rootView.getActiveEditor()
      editor2 = editor1.splitRight()
      expect(window.rootView.getEditors().length).toBe 2

      stopApplication()

      expect(editor1.getBuffer().subscriptionCount()).toBe 0

