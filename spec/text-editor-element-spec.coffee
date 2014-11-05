TextEditorElement = require '../src/text-editor-element'

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
      afterEach ->
        document.head.querySelector('atom-styles[context="atom-text-editor"]').remove()

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
