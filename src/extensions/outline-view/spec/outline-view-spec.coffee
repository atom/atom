RootView = require 'root-view'
OutlineView = require 'outline-view'
TagGenerator = require 'outline-view/src/tag-generator'

describe "OutlineView", ->
  [rootView, outlineView, setArraySpy] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures'))
    rootView.activateExtension(OutlineView)
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
      rootView.getActiveEditor().trigger "outline-view:toggle"
      expect(outlineView.find('.loading')).toHaveText 'Generating symbols...'

      waitsFor ->
        setArraySpy.callCount > 0

      runs ->
        expect(outlineView.find('.loading')).toBeEmpty()
        expect(rootView.find('.outline-view')).toExist()
        expect(outlineView.list.children('li').length).toBe 2
        expect(outlineView.list.children('li:first').find('.function-name')).toHaveText 'quicksort'
        expect(outlineView.list.children('li:first').find('.function-line')).toHaveText 'Line 1'
        expect(outlineView.list.children('li:last').find('.function-name')).toHaveText 'quicksort.sort'
        expect(outlineView.list.children('li:last').find('.function-line')).toHaveText 'Line 2'
        expect(outlineView).not.toHaveClass "error"
        expect(outlineView.error).not.toBeVisible()

    it "displays error when no tags match text in mini-editor", ->
      rootView.open('sample.js')
      expect(rootView.find('.outline-view')).not.toExist()
      rootView.getActiveEditor().trigger "outline-view:toggle"

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
      rootView.getActiveEditor().trigger "outline-view:toggle"
      setErrorSpy = spyOn(outlineView, "setError").andCallThrough()

      waitsFor ->
        setErrorSpy.callCount > 0

      runs ->
        expect(rootView.find('.outline-view')).toExist()
        expect(outlineView.list.children('li').length).toBe 0
        expect(outlineView.error).toBeVisible()
        expect(outlineView.error.text().length).toBeGreaterThan 0
        expect(outlineView).toHaveClass "error"

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
      expect(rootView.getActiveEditor().getCursorBufferPosition()).toEqual [1,0]

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
