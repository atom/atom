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

  describe "::focus()", ->
    it "transfers focus to the hidden text area and does not emit 'focusout' or 'blur' events", ->
      element = new TextEditorElement
      jasmineContent.appendChild(element)

      focusoutCalled = false
      element.addEventListener 'focusout', -> focusoutCalled = true
      blurCalled = false
      element.addEventListener 'blur', -> blurCalled = true

      element.focus()
      expect(focusoutCalled).toBe false
      expect(blurCalled).toBe false
      expect(element.hasFocus()).toBe true
      expect(element.querySelector('input')).toBe document.activeElement
