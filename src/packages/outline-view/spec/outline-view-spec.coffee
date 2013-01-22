RootView = require 'root-view'
OutlineView = require 'outline-view/src/outline-view'
TagGenerator = require 'outline-view/src/tag-generator'
fs = require 'fs'

describe "OutlineView", ->
  [rootView, outlineView, setArraySpy] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures'))
    atom.loadPackage("outline-view")
    outlineView = OutlineView.instance
    rootView.attachToDom()
    setArraySpy = spyOn(outlineView, 'setArray').andCallThrough()

  afterEach ->
    rootView.deactivate()
    setArraySpy.reset()

  describe "when tags can be generated for a file", ->
    it "initially displays all JavaScript functions with line numbers", ->
      rootView.open('sample.js')
      expect(rootView.find('.outline-view')).not.toExist()
      rootView.getActiveEditor().trigger "outline-view:toggle-file-outline"
      expect(outlineView.find('.loading')).toHaveText 'Generating symbols...'

      waitsFor ->
        setArraySpy.callCount > 0

      runs ->
        expect(outlineView.find('.loading')).toBeEmpty()
        expect(rootView.find('.outline-view')).toExist()
        expect(outlineView.list.children('li').length).toBe 2
        expect(outlineView.list.children('li:first').find('.function-name')).toHaveText 'quicksort'
        expect(outlineView.list.children('li:first').find('.function-details')).toHaveText 'Line 1'
        expect(outlineView.list.children('li:last').find('.function-name')).toHaveText 'quicksort.sort'
        expect(outlineView.list.children('li:last').find('.function-details')).toHaveText 'Line 2'
        expect(outlineView).not.toHaveClass "error"
        expect(outlineView.error).not.toBeVisible()

    it "displays error when no tags match text in mini-editor", ->
      rootView.open('sample.js')
      expect(rootView.find('.outline-view')).not.toExist()
      rootView.getActiveEditor().trigger "outline-view:toggle-file-outline"

      waitsFor ->
        setArraySpy.callCount > 0

      runs ->
        outlineView.miniEditor.setText("nothing will match this")
        window.advanceClock(outlineView.inputThrottle)

        expect(rootView.find('.outline-view')).toExist()
        expect(outlineView.list.children('li').length).toBe 0
        expect(outlineView.error).toBeVisible()
        expect(outlineView.error.text().length).toBeGreaterThan 0
        expect(outlineView).toHaveClass "error"

        # Should remove error
        outlineView.miniEditor.setText("")
        window.advanceClock(outlineView.inputThrottle)

        expect(outlineView.list.children('li').length).toBe 2
        expect(outlineView).not.toHaveClass "error"
        expect(outlineView.error).not.toBeVisible()

  describe "when tags can't be generated for a file", ->
    it "shows an error message when no matching tags are found", ->
      rootView.open('sample.txt')
      expect(rootView.find('.outline-view')).not.toExist()
      rootView.getActiveEditor().trigger "outline-view:toggle-file-outline"
      setErrorSpy = spyOn(outlineView, "setError").andCallThrough()

      waitsFor ->
        setErrorSpy.callCount > 0

      runs ->
        expect(rootView.find('.outline-view')).toExist()
        expect(outlineView.list.children('li').length).toBe 0
        expect(outlineView.error).toBeVisible()
        expect(outlineView.error.text().length).toBeGreaterThan 0
        expect(outlineView).toHaveClass "error"
        expect(outlineView.find('.loading')).not.toBeVisible()

  it "moves the cursor to the selected function", ->
    tags = []
    waitsForPromise ->
      tags = []
      path = require.resolve('fixtures/sample.js')
      callback = (tag) ->
        tags.push tag
      generator = new TagGenerator(path, callback)
      generator.generate()

    runs ->
      rootView.open('sample.js')
      expect(rootView.getActiveEditor().getCursorBufferPosition()).toEqual [0,0]
      expect(rootView.find('.outline-view')).not.toExist()
      outlineView.setArray(tags)
      outlineView.attach()
      expect(rootView.find('.outline-view')).toExist()
      outlineView.confirmed(tags[1])
      expect(rootView.getActiveEditor().getCursorBufferPosition()).toEqual [1,2]

  describe "TagGenerator", ->
    it "generates tags for all JavaScript functions", ->
      waitsForPromise ->
        tags = []
        path = require.resolve('fixtures/sample.js')
        callback = (tag) ->
          tags.push tag
        generator = new TagGenerator(path, callback)
        generator.generate().done ->
          expect(tags.length).toBe 2
          expect(tags[0].name).toBe "quicksort"
          expect(tags[0].position.row).toBe 0
          expect(tags[1].name).toBe "quicksort.sort"
          expect(tags[1].position.row).toBe 1

    it "generates no tags for text file", ->
      waitsForPromise ->
        tags = []
        path = require.resolve('fixtures/sample.txt')
        callback = (tag) ->
          tags.push tag
        generator = new TagGenerator(path, callback)
        generator.generate().done ->
          expect(tags.length).toBe 0

  describe "jump to declaration", ->
    it "doesn't move the cursor when no declaration is found", ->
      rootView.open("tagged.js")
      editor = rootView.getActiveEditor()
      editor.setCursorBufferPosition([0,2])
      editor.trigger 'outline-view:jump-to-declaration'
      expect(editor.getCursorBufferPosition()).toEqual [0,2]

    it "moves the cursor to the declaration", ->
      rootView.open("tagged.js")
      editor = rootView.getActiveEditor()
      editor.setCursorBufferPosition([6,24])
      editor.trigger 'outline-view:jump-to-declaration'
      expect(editor.getCursorBufferPosition()).toEqual [2,0]

    it "displays matches when more than one exists and opens the selected match", ->
      rootView.open("tagged.js")
      editor = rootView.getActiveEditor()
      editor.setCursorBufferPosition([8,14])
      editor.trigger 'outline-view:jump-to-declaration'
      expect(outlineView.list.children('li').length).toBe 2
      expect(outlineView).toBeVisible()
      outlineView.confirmed(outlineView.array[0])
      expect(rootView.getActiveEditor().getPath()).toBe rootView.project.resolve("tagged-duplicate.js")
      expect(rootView.getActiveEditor().getCursorBufferPosition()).toEqual [0,4]

    describe "when the tag is in a file that doesn't exist", ->
      beforeEach ->
        fs.move(rootView.project.resolve("tagged-duplicate.js"), rootView.project.resolve("tagged-duplicate-renamed.js"))

      afterEach ->
        fs.move(rootView.project.resolve("tagged-duplicate-renamed.js"), rootView.project.resolve("tagged-duplicate.js"))

      it "doesn't display the tag", ->
        rootView.open("tagged.js")
        editor = rootView.getActiveEditor()
        editor.setCursorBufferPosition([8,14])
        editor.trigger 'outline-view:jump-to-declaration'
        expect(outlineView.list.children('li').length).toBe 1
        expect(outlineView.list.children('li:first').find('.function-name')).toHaveText 'tagged.js'

  describe "project outline", ->
    it "displays all tags", ->
      rootView.open("tagged.js")
      expect(rootView.find('.outline-view')).not.toExist()
      rootView.trigger "outline-view:toggle-project-outline"
      expect(outlineView.find('.loading')).toHaveText 'Loading symbols...'

      waitsFor ->
        setArraySpy.callCount > 0

      runs ->
        expect(outlineView.find('.loading')).toBeEmpty()
        expect(rootView.find('.outline-view')).toExist()
        expect(outlineView.list.children('li').length).toBe 4
        expect(outlineView.list.children('li:first').find('.function-name')).toHaveText 'callMeMaybe'
        expect(outlineView.list.children('li:first').find('.function-details')).toHaveText 'tagged.js'
        expect(outlineView.list.children('li:last').find('.function-name')).toHaveText 'thisIsCrazy'
        expect(outlineView.list.children('li:last').find('.function-details')).toHaveText 'tagged.js'
        expect(outlineView).not.toHaveClass "error"
        expect(outlineView.error).not.toBeVisible()
