TextEditorElement = require '../src/text-editor-element'
TextEditor = require '../src/text-editor'

# The rest of text-editor-component-spec will be moved to this file when React
# is eliminated. This covers only concerns related to the wrapper element for now
describe "TextEditorElement", ->
  jasmineContent = null

  beforeEach ->
    jasmineContent = document.body.querySelector('#jasmine-content')

  describe "instantiation", ->
    it "honors the mini attribute", ->
      jasmineContent.innerHTML = "<atom-text-editor mini>"
      element = jasmineContent.firstChild
      expect(element.getModel().isMini()).toBe true

    it "honors the placeholder-text attribute", ->
      jasmineContent.innerHTML = "<atom-text-editor placeholder-text='testing'>"
      element = jasmineContent.firstChild
      expect(element.getModel().getPlaceholderText()).toBe 'testing'

    it "honors the text content", ->
      jasmineContent.innerHTML = "<atom-text-editor>testing</atom-text-editor>"
      element = jasmineContent.firstChild
      expect(element.getModel().getText()).toBe 'testing'

  describe "when the model is assigned", ->
    it "adds the 'mini' attribute if .isMini() returns true on the model", ->
      element = new TextEditorElement
      model = new TextEditor(mini: true)
      element.setModel(model)
      expect(element.hasAttribute('mini')).toBe true

  describe "when the editor is attached to the DOM", ->
    describe "when the editor.useShadowDOM config option is true", ->
      it "mounts the react component and unmounts when removed from the dom", ->
        atom.config.set('editor.useShadowDOM', true)

        element = new TextEditorElement
        jasmine.attachToDOM(element)

        component = element.component
        expect(component.isMounted()).toBe true
        element.remove()
        expect(component.isMounted()).toBe false

        jasmine.attachToDOM(element)
        expect(element.component.isMounted()).toBe true

    describe "when the editor.useShadowDOM config option is false", ->
      it "mounts the react component and unmounts when removed from the dom", ->
        atom.config.set('editor.useShadowDOM', false)

        element = new TextEditorElement
        jasmine.attachToDOM(element)

        component = element.component
        expect(component.isMounted()).toBe true
        element.getModel().destroy()
        expect(component.isMounted()).toBe false

  describe "focus and blur handling", ->
    describe "when the editor.useShadowDOM config option is true", ->
      it "proxies focus/blur events to/from the hidden input inside the shadow root", ->
        atom.config.set('editor.useShadowDOM', true)

        element = new TextEditorElement
        jasmineContent.appendChild(element)

        blurCalled = false
        element.addEventListener 'blur', -> blurCalled = true

        element.focus()
        expect(blurCalled).toBe false
        expect(element.hasFocus()).toBe true
        expect(document.activeElement).toBe element
        expect(element.shadowRoot.activeElement).toBe element.shadowRoot.querySelector('input')

        document.body.focus()
        expect(blurCalled).toBe true

    describe "when the editor.useShadowDOM config option is false", ->
      it "proxies focus/blur events to/from the hidden input", ->
        atom.config.set('editor.useShadowDOM', false)

        element = new TextEditorElement
        jasmineContent.appendChild(element)

        blurCalled = false
        element.addEventListener 'blur', -> blurCalled = true

        element.focus()
        expect(blurCalled).toBe false
        expect(element.hasFocus()).toBe true
        expect(document.activeElement).toBe element.querySelector('input')

        document.body.focus()
        expect(blurCalled).toBe true

  describe "when the themes finish loading", ->
    [themeReloadCallback, initialThemeLoadComplete, element] = []

    beforeEach ->
      themeReloadCallback = null
      initialThemeLoadComplete = false

      spyOn(atom.themes, 'isInitialLoadComplete').andCallFake ->
        initialThemeLoadComplete
      spyOn(atom.themes, 'onDidReloadAll').andCallFake (fn) ->
        themeReloadCallback = fn

      atom.config.set("editor.useShadowDOM", false)

      element = new TextEditorElement()
      element.style.height = '200px'
      element.getModel().setText [0..20].join("\n")

    it "re-renders the scrollbar", ->
      jasmineContent.appendChild(element)

      atom.styles.addStyleSheet """
        ::-webkit-scrollbar {
          width: 8px;
        }
      """

      initialThemeLoadComplete = true
      themeReloadCallback()

      verticalScrollbarNode = element.querySelector(".vertical-scrollbar")
      scrollbarWidth = verticalScrollbarNode.offsetWidth - verticalScrollbarNode.clientWidth
      expect(scrollbarWidth).toEqual(8)

  describe "::onDidAttach and ::onDidDetach", ->
    it "invokes callbacks when the element is attached and detached", ->
      element = new TextEditorElement

      attachedCallback = jasmine.createSpy("attachedCallback")
      detachedCallback = jasmine.createSpy("detachedCallback")

      element.onDidAttach(attachedCallback)
      element.onDidDetach(detachedCallback)

      jasmine.attachToDOM(element)

      expect(attachedCallback).toHaveBeenCalled()
      expect(detachedCallback).not.toHaveBeenCalled()

      attachedCallback.reset()
      element.remove()

      expect(attachedCallback).not.toHaveBeenCalled()
      expect(detachedCallback).toHaveBeenCalled()

  describe "::setUpdatedSynchronously", ->
    it "controls whether the text editor is updated synchronously", ->
      spyOn(window, 'requestAnimationFrame').andCallFake (fn) -> fn()

      element = new TextEditorElement
      jasmine.attachToDOM(element)

      element.setUpdatedSynchronously(false)
      expect(element.isUpdatedSynchronously()).toBe false

      element.getModel().setText("hello")
      expect(window.requestAnimationFrame).toHaveBeenCalled()

      expect(element.shadowRoot.textContent).toContain "hello"

      window.requestAnimationFrame.reset()
      element.setUpdatedSynchronously(true)
      element.getModel().setText("goodbye")
      expect(window.requestAnimationFrame).not.toHaveBeenCalled()
      expect(element.shadowRoot.textContent).toContain "goodbye"

  describe "::getDefaultCharacterWidth", ->
    it "returns null before the element is attached", ->
      element = new TextEditorElement
      expect(element.getDefaultCharacterWidth()).toBeNull()

    it "returns the width of a character in the root scope", ->
      element = new TextEditorElement
      jasmine.attachToDOM(element)
      expect(element.getDefaultCharacterWidth()).toBeGreaterThan(0)
