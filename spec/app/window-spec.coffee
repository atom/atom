$ = require 'jquery'
fs = require 'fs'

describe "Window", ->
  projectPath = null

  beforeEach ->
    spyOn(atom, 'getPathToOpen').andReturn(project.getPath())
    window.handleWindowEvents()
    window.buildProjectAndRootView()
    projectPath = project.getPath()

  afterEach ->
    window.shutdown()
    atom.setRootViewStateForPath(projectPath, null)
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
    beforeEach ->
      spyOn($native, "reload")

    it "returns false when no buffers are modified", ->
      window.reload()
      expect($native.reload).toHaveBeenCalled()

    it "shows an alert when a modifed buffer exists", ->
      rootView.open('sample.js')
      rootView.getActiveView().insertText("hi")
      spyOn(atom, "confirm")
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

  describe ".shutdown()", ->
    it "saves the serialized state of the project and root view to the atom object so it can be rehydrated after reload", ->
      projectPath = project.getPath()
      expect(atom.getRootViewStateForPath(projectPath)).toBeUndefined()
      # JSON.stringify removes keys with undefined values
      rootViewState = JSON.parse(JSON.stringify(rootView.serialize()))
      projectState = JSON.parse(JSON.stringify(project.serialize()))

      window.shutdown()

      expect(atom.getRootViewStateForPath(projectPath)).toEqual
        project: projectState
        rootView: rootViewState

    it "unsubscribes from all buffers", ->
      rootView.open('sample.js')
      buffer = rootView.getActivePaneItem().buffer
      rootView.getActivePane().splitRight()
      expect(window.rootView.find('.editor').length).toBe 2

      window.shutdown()

      expect(buffer.subscriptionCount()).toBe 0

    it "only serializes window state the first time it is called", ->
      deactivateSpy = spyOn(atom, "setRootViewStateForPath").andCallThrough()
      window.shutdown()
      window.shutdown()
      expect(atom.setRootViewStateForPath.callCount).toBe 1

  describe ".installAtomCommand(commandPath)", ->
    commandPath = '/tmp/installed-atom-command/atom'

    afterEach ->
      fs.remove(commandPath) if fs.exists(commandPath)

    describe "when the command path doesn't exist", ->
      it "copies atom.sh to the specified path", ->
        expect(fs.exists(commandPath)).toBeFalsy()
        window.installAtomCommand(commandPath)
        expect(fs.exists(commandPath)).toBeTruthy()
        expect(fs.read(commandPath).length).toBeGreaterThan 1
