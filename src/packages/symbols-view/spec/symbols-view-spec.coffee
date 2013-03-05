RootView = require 'root-view'
SymbolsView = require 'symbols-view/lib/symbols-view'
TagGenerator = require 'symbols-view/lib/tag-generator'
fs = require 'fs'

describe "SymbolsView", ->
  [symbolsView, setArraySpy] = []

  beforeEach ->
    window.rootView = new RootView
    window.loadPackage("symbols-view")

    rootView.attachToDom()
    setArraySpy = spyOn(SymbolsView.prototype, 'setArray').andCallThrough()

  afterEach ->
    setArraySpy.reset()

  describe "when tags can be generated for a file", ->
    it "initially displays all JavaScript functions with line numbers", ->
      rootView.open('sample.js')
      rootView.getActiveEditor().trigger "symbols-view:toggle-file-symbols"
      symbolsView = rootView.find('.symbols-view').view()
      expect(symbolsView.find('.loading')).toHaveText 'Generating symbols...'

      waitsFor ->
        setArraySpy.callCount > 0

      runs ->
        expect(symbolsView.find('.loading')).toBeEmpty()
        expect(rootView.find('.symbols-view')).toExist()
        expect(symbolsView.list.children('li').length).toBe 2
        expect(symbolsView.list.children('li:first').find('.label')).toHaveText 'quicksort'
        expect(symbolsView.list.children('li:first').find('.function-details')).toHaveText 'Line 1'
        expect(symbolsView.list.children('li:last').find('.label')).toHaveText 'quicksort.sort'
        expect(symbolsView.list.children('li:last').find('.function-details')).toHaveText 'Line 2'
        expect(symbolsView).not.toHaveClass "error"
        expect(symbolsView.error).not.toBeVisible()

    it "displays error when no tags match text in mini-editor", ->
      rootView.open('sample.js')
      rootView.getActiveEditor().trigger "symbols-view:toggle-file-symbols"
      symbolsView = rootView.find('.symbols-view').view()

      waitsFor ->
        setArraySpy.callCount > 0

      runs ->
        symbolsView.miniEditor.setText("nothing will match this")
        window.advanceClock(symbolsView.inputThrottle)

        expect(rootView.find('.symbols-view')).toExist()
        expect(symbolsView.list.children('li').length).toBe 0
        expect(symbolsView.error).toBeVisible()
        expect(symbolsView.error.text().length).toBeGreaterThan 0
        expect(symbolsView).toHaveClass "error"

        # Should remove error
        symbolsView.miniEditor.setText("")
        window.advanceClock(symbolsView.inputThrottle)

        expect(symbolsView.list.children('li').length).toBe 2
        expect(symbolsView).not.toHaveClass "error"
        expect(symbolsView.error).not.toBeVisible()

  describe "when tags can't be generated for a file", ->
    it "shows an error message when no matching tags are found", ->
      rootView.open('sample.txt')
      rootView.getActiveEditor().trigger "symbols-view:toggle-file-symbols"
      symbolsView = rootView.find('.symbols-view').view()
      setErrorSpy = spyOn(symbolsView, "setError").andCallThrough()

      waitsFor ->
        setErrorSpy.callCount > 0

      runs ->
        expect(rootView.find('.symbols-view')).toExist()
        expect(symbolsView.list.children('li').length).toBe 0
        expect(symbolsView.error).toBeVisible()
        expect(symbolsView.error.text().length).toBeGreaterThan 0
        expect(symbolsView).toHaveClass "error"
        expect(symbolsView.find('.loading')).not.toBeVisible()

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
      expect(rootView.find('.symbols-view')).not.toExist()
      symbolsView = SymbolsView.activate()
      symbolsView.setArray(tags)
      symbolsView.attach()
      expect(rootView.find('.symbols-view')).toExist()
      symbolsView.confirmed(tags[1])
      expect(rootView.getActiveEditor().getCursorBufferPosition()).toEqual [1,2]

  describe "TagGenerator", ->
    it "generates tags for all JavaScript functions", ->
      tags = []

      waitsForPromise ->
        path = require.resolve('fixtures/sample.js')
        callback = (tag) ->
          tags.push tag
        generator = new TagGenerator(path, callback)
        generator.generate()

      runs ->
        expect(tags.length).toBe 2
        expect(tags[0].name).toBe "quicksort"
        expect(tags[0].position.row).toBe 0
        expect(tags[1].name).toBe "quicksort.sort"
        expect(tags[1].position.row).toBe 1

    it "generates no tags for text file", ->
      tags = []

      waitsForPromise ->
        path = require.resolve('fixtures/sample.txt')
        callback = (tag) ->
          tags.push tag
        generator = new TagGenerator(path, callback)
        generator.generate()

      runs ->
        expect(tags.length).toBe 0

  describe "go to declaration", ->
    it "doesn't move the cursor when no declaration is found", ->
      rootView.open("tagged.js")
      editor = rootView.getActiveEditor()
      editor.setCursorBufferPosition([0,2])
      editor.trigger 'symbols-view:go-to-declaration'
      expect(editor.getCursorBufferPosition()).toEqual [0,2]

    it "moves the cursor to the declaration", ->
      rootView.open("tagged.js")
      editor = rootView.getActiveEditor()
      editor.setCursorBufferPosition([6,24])
      editor.trigger 'symbols-view:go-to-declaration'
      expect(editor.getCursorBufferPosition()).toEqual [2,0]

    it "displays matches when more than one exists and opens the selected match", ->
      rootView.open("tagged.js")
      editor = rootView.getActiveEditor()
      editor.setCursorBufferPosition([8,14])
      editor.trigger 'symbols-view:go-to-declaration'
      symbolsView = rootView.find('.symbols-view').view()
      expect(symbolsView.list.children('li').length).toBe 2
      expect(symbolsView).toBeVisible()
      symbolsView.confirmed(symbolsView.array[0])
      expect(rootView.getActiveEditor().getPath()).toBe project.resolve("tagged-duplicate.js")
      expect(rootView.getActiveEditor().getCursorBufferPosition()).toEqual [0,4]

    describe "when the tag is in a file that doesn't exist", ->
      renamedPath = null

      beforeEach ->
        renamedPath = project.resolve("tagged-duplicate-renamed.js")
        fs.remove(renamedPath) if fs.exists(renamedPath)
        fs.move(project.resolve("tagged-duplicate.js"), renamedPath)

      afterEach ->
        fs.move(renamedPath, project.resolve("tagged-duplicate.js"))

      it "doesn't display the tag", ->
        rootView.open("tagged.js")
        editor = rootView.getActiveEditor()
        editor.setCursorBufferPosition([8,14])
        editor.trigger 'symbols-view:go-to-declaration'
        symbolsView = rootView.find('.symbols-view').view()
        expect(symbolsView.list.children('li').length).toBe 1
        expect(symbolsView.list.children('li:first').find('.label')).toHaveText 'tagged.js'

  describe "project symbols", ->
    it "displays all tags", ->
      rootView.open("tagged.js")
      expect(rootView.find('.symbols-view')).not.toExist()
      rootView.trigger "symbols-view:toggle-project-symbols"
      symbolsView = rootView.find('.symbols-view').view()
      expect(symbolsView.find('.loading')).toHaveText 'Loading symbols...'

      waitsFor ->
        setArraySpy.callCount > 0

      runs ->
        expect(symbolsView.find('.loading')).toBeEmpty()
        expect(rootView.find('.symbols-view')).toExist()
        expect(symbolsView.list.children('li').length).toBe 4
        expect(symbolsView.list.children('li:first').find('.label')).toHaveText 'callMeMaybe'
        expect(symbolsView.list.children('li:first').find('.function-details')).toHaveText 'tagged.js'
        expect(symbolsView.list.children('li:last').find('.label')).toHaveText 'thisIsCrazy'
        expect(symbolsView.list.children('li:last').find('.function-details')).toHaveText 'tagged.js'
        expect(symbolsView).not.toHaveClass "error"
        expect(symbolsView.error).not.toBeVisible()

    describe "when selecting a tag", ->
      describe "when the file doesn't exist", ->
        renamedPath = null

        beforeEach ->
          renamedPath = project.resolve("tagged-renamed.js")
          fs.remove(renamedPath) if fs.exists(renamedPath)
          fs.move(project.resolve("tagged.js"), renamedPath)

        afterEach ->
          fs.move(renamedPath, project.resolve("tagged.js"))

        it "doesn't open the editor", ->
          rootView.trigger "symbols-view:toggle-project-symbols"
          symbolsView = rootView.find('.symbols-view').view()

          waitsFor ->
            setArraySpy.callCount > 0

          runs ->
            spyOn(rootView, 'open').andCallThrough()
            symbolsView.list.children('li:first').mousedown().mouseup()
            expect(rootView.open).not.toHaveBeenCalled()
            expect(symbolsView.error.text().length).toBeGreaterThan 0
            expect(symbolsView).toHaveClass "error"
