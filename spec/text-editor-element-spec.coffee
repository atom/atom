TextEditorElement = require '../src/text-editor-element'
TextEditor = require '../src/text-editor'
{Disposable} = require 'event-kit'

# The rest of text-editor-component-spec will be moved to this file when React
# is eliminated. This covers only concerns related to the wrapper element for now
describe "TextEditorElement", ->
  jasmineContent = null

  beforeEach ->
    jasmineContent = document.body.querySelector('#jasmine-content')

  describe "instantiation", ->
    it "honors the 'mini' attribute", ->
      jasmineContent.innerHTML = "<atom-text-editor mini>"
      element = jasmineContent.firstChild
      expect(element.getModel().isMini()).toBe true

    it "honors the 'placeholder-text' attribute", ->
      jasmineContent.innerHTML = "<atom-text-editor placeholder-text='testing'>"
      element = jasmineContent.firstChild
      expect(element.getModel().getPlaceholderText()).toBe 'testing'

    it "honors the 'gutter-hidden' attribute", ->
      jasmineContent.innerHTML = "<atom-text-editor gutter-hidden>"
      element = jasmineContent.firstChild
      expect(element.getModel().isLineNumberGutterVisible()).toBe false

    it "honors the text content", ->
      jasmineContent.innerHTML = "<atom-text-editor>testing</atom-text-editor>"
      element = jasmineContent.firstChild
      expect(element.getModel().getText()).toBe 'testing'

  describe "when the model is assigned", ->
    it "adds the 'mini' attribute if .isMini() returns true on the model", ->
      element = new TextEditorElement
      model = atom.workspace.buildTextEditor(mini: true)
      element.setModel(model)
      expect(element.hasAttribute('mini')).toBe true

  describe "when the editor is attached to the DOM", ->
    describe "when the editor.useShadowDOM config option is true", ->
      it "mounts the react component and unmounts when removed from the dom", ->
        atom.config.set('editor.useShadowDOM', true)

        element = new TextEditorElement
        jasmine.attachToDOM(element)

        component = element.component
        expect(component.mounted).toBe true
        element.remove()
        expect(component.mounted).toBe false

        jasmine.attachToDOM(element)
        expect(element.component.mounted).toBe true

    describe "when the editor.useShadowDOM config option is false", ->
      it "mounts the react component and unmounts when removed from the dom", ->
        atom.config.set('editor.useShadowDOM', false)

        element = new TextEditorElement
        jasmine.attachToDOM(element)

        component = element.component
        expect(component.mounted).toBe true
        element.getModel().destroy()
        expect(component.mounted).toBe false

  describe "when the editor is detached from the DOM and then reattached", ->
    it "does not render duplicate line numbers", ->
      editor = atom.workspace.buildTextEditor()
      editor.setText('1\n2\n3')
      element = atom.views.getView(editor)

      jasmine.attachToDOM(element)

      initialCount = element.shadowRoot.querySelectorAll('.line-number').length

      element.remove()
      jasmine.attachToDOM(element)
      expect(element.shadowRoot.querySelectorAll('.line-number').length).toBe initialCount

    it "does not render duplicate decorations in custom gutters", ->
      editor = atom.workspace.buildTextEditor()
      editor.setText('1\n2\n3')
      editor.addGutter({name: 'test-gutter'})
      marker = editor.markBufferRange([[0, 0], [2, 0]])
      editor.decorateMarker(marker, {type: 'gutter', gutterName: 'test-gutter'})
      element = atom.views.getView(editor)

      jasmine.attachToDOM(element)
      initialDecorationCount = element.shadowRoot.querySelectorAll('.decoration').length

      element.remove()
      jasmine.attachToDOM(element)
      expect(element.shadowRoot.querySelectorAll('.decoration').length).toBe initialDecorationCount

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

    describe "when focused while a parent node is being attached to the DOM", ->
      class ElementThatFocusesChild extends HTMLDivElement
        attachedCallback: ->
          @firstChild.focus()

      document.registerElement("element-that-focuses-child",
        prototype: ElementThatFocusesChild.prototype
      )

      it "proxies the focus event to the hidden input", ->
        element = new TextEditorElement
        parentElement = document.createElement("element-that-focuses-child")
        parentElement.appendChild(element)
        jasmineContent.appendChild(parentElement)
        expect(element.shadowRoot.activeElement).toBe element.shadowRoot.querySelector('input')

  describe "when the themes finish loading", ->
    [themeReloadCallback, initialThemeLoadComplete, element] = []

    beforeEach ->
      themeReloadCallback = null
      initialThemeLoadComplete = false

      spyOn(atom.themes, 'isInitialLoadComplete').andCallFake ->
        initialThemeLoadComplete
      spyOn(atom.themes, 'onDidChangeActiveThemes').andCallFake (fn) ->
        themeReloadCallback = fn
        new Disposable

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

  describe "::getMaxScrollTop", ->
    it "returns the maximum scroll top that can be applied to the element", ->
      editor = atom.workspace.buildTextEditor()
      editor.setText('1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16')
      element = atom.views.getView(editor)
      element.style.lineHeight = "10px"
      element.style.width = "200px"

      expect(element.getMaxScrollTop()).toBe(0)

      jasmine.attachToDOM(element)

      element.setHeight(100)
      expect(element.getMaxScrollTop()).toBe(60)

      element.setHeight(120)
      expect(element.getMaxScrollTop()).toBe(40)

      element.setHeight(200)
      expect(element.getMaxScrollTop()).toBe(0)

  describe "on TextEditor::setMini", ->
    it "changes the element's 'mini' attribute", ->
      element = new TextEditorElement
      jasmine.attachToDOM(element)
      expect(element.hasAttribute('mini')).toBe false
      element.getModel().setMini(true)
      expect(element.hasAttribute('mini')).toBe true
      element.getModel().setMini(false)
      expect(element.hasAttribute('mini')).toBe false

  describe "events", ->
    element = null

    beforeEach ->
      element = new TextEditorElement
      element.getModel().setText("lorem\nipsum\ndolor\nsit\namet")
      element.setUpdatedSynchronously(true)
      element.setHeight(20)
      element.setWidth(20)

    describe "::onDidChangeScrollTop(callback)", ->
      it "triggers even when subscribing before attaching the element", ->
        positions = []
        subscription1 = element.onDidChangeScrollTop (p) -> positions.push(p)
        jasmine.attachToDOM(element)
        subscription2 = element.onDidChangeScrollTop (p) -> positions.push(p)

        positions.length = 0
        element.setScrollTop(10)
        expect(positions).toEqual([10, 10])

        element.remove()
        jasmine.attachToDOM(element)

        positions.length = 0
        element.setScrollTop(20)
        expect(positions).toEqual([20, 20])

        subscription1.dispose()

        positions.length = 0
        element.setScrollTop(30)
        expect(positions).toEqual([30])

    describe "::onDidChangeScrollLeft(callback)", ->
      it "triggers even when subscribing before attaching the element", ->
        positions = []
        subscription1 = element.onDidChangeScrollLeft (p) -> positions.push(p)
        jasmine.attachToDOM(element)
        subscription2 = element.onDidChangeScrollLeft (p) -> positions.push(p)

        positions.length = 0
        element.setScrollLeft(10)
        expect(positions).toEqual([10, 10])

        element.remove()
        jasmine.attachToDOM(element)

        positions.length = 0
        element.setScrollLeft(20)
        expect(positions).toEqual([20, 20])

        subscription1.dispose()

        positions.length = 0
        element.setScrollLeft(30)
        expect(positions).toEqual([30])
