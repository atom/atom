TextEditorRegistry = require '../src/text-editor-registry'

describe "TextEditorRegistry", ->
  [registry, editor] = []

  beforeEach ->
    registry = new TextEditorRegistry

  describe "when a TextEditor is added", ->
    it "gets added to the list of registered editors", ->
      editor = {}
      registry.add(editor)
      expect(editor.registered).toBe true
      expect(registry.editors.size).toBe 1
      expect(registry.editors.has(editor)).toBe(true)

    it "returns a Disposable that can unregister the editor", ->
      editor = {}
      disposable = registry.add(editor)
      expect(registry.editors.size).toBe 1
      disposable.dispose()
      expect(registry.editors.size).toBe 0
      expect(editor.registered).toBe false

    it "can be removed", ->
      editor = {}
      registry.add(editor)
      expect(registry.editors.size).toBe 1
      success = registry.remove(editor)
      expect(success).toBe true
      expect(registry.editors.size).toBe 0
      expect(editor.registered).toBe false

  describe "when the registry is observed", ->
    it "calls the callback for current and future editors until unsubscribed", ->
      [editor1, editor2, editor3] = [{}, {}, {}]

      registry.add(editor1)
      subscription = registry.observe spy = jasmine.createSpy()
      expect(spy.calls.length).toBe 1

      registry.add(editor2)
      expect(spy.calls.length).toBe 2
      expect(spy.argsForCall[0][0]).toBe editor1
      expect(spy.argsForCall[1][0]).toBe editor2

      subscription.dispose()
      registry.add(editor3)
      expect(spy.calls.length).toBe 2
