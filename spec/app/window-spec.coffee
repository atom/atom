$ = require 'jquery'
fs = require 'fs'

describe "Window", ->
  [rootView] = []

  beforeEach ->
    window.attachRootView(require.resolve('fixtures'))
    rootView = window.rootView

  afterEach ->
    window.shutdown()
    atom.setRootViewStateForPath(rootView.project.getPath(), null)
    $(window).off 'beforeunload'

  describe "when the window is loaded", ->
    it "doesn't have .is-blurred on the body tag", ->
      expect($("body")).not.toHaveClass("is-blurred")

  fdescribe "when the window is blurred", ->
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

  describe "before the window is unloaded", ->
    it "saves the serialized state of the root view to the atom object so it can be rehydrated after reload", ->
      expect(atom.getRootViewStateForPath(window.rootView.project.getPath())).toBeUndefined()
      expectedState = JSON.parse(JSON.stringify(window.rootView.serialize())) # JSON.stringify removes keys with undefined values
      $(window).trigger 'beforeunload'
      expect(atom.getRootViewStateForPath(rootView.project.getPath())).toEqual expectedState

    it "unsubscribes from all buffers", ->
      rootView.open('sample.js')
      editor1 = rootView.getActiveEditor()
      editor2 = editor1.splitRight()
      expect(window.rootView.getEditors().length).toBe 2

      $(window).trigger 'beforeunload'

      expect(editor1.getBuffer().subscriptionCount()).toBe 0

  describe ".shutdown()", ->
    it "only deactivates the RootView the first time it is called", ->
      deactivateSpy = spyOn(rootView, "deactivate").andCallThrough()
      window.shutdown()
      expect(rootView.deactivate).toHaveBeenCalled()
      deactivateSpy.reset()
      window.shutdown()
      expect(rootView.deactivate).not.toHaveBeenCalled()
