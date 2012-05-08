RootView = require 'root-view'
FileFinder = require 'file-finder'
$ = require 'jquery'
{$$} = require 'space-pen'

describe 'FileFinder', ->
  [rootView, finder] = []

  beforeEach ->
    rootView = new RootView(pathToOpen: require.resolve('fixtures/sample.js'))
    rootView.enableKeymap()
    rootView.activateExtension(FileFinder)
    finder = FileFinder.instance

  describe "when the file-finder:toggle event is triggered on the root view", ->
    describe "when there is a project", ->
      it "shows or hides the FileFinder, returning focus to the active editor when hiding it", ->
        rootView.attachToDom()
        expect(rootView.find('.file-finder')).not.toExist()
        rootView.find('.editor').trigger 'split-right'
        [editor1, editor2] = rootView.find('.editor').map -> $(this).view()

        rootView.trigger 'file-finder:toggle'
        expect(rootView.find('.file-finder')).toExist()
        expect(rootView.find('.file-finder input:focus')).toExist()
        finder.miniEditor.insertText('this should not show up next time we toggle')

        rootView.trigger 'file-finder:toggle'
        expect(editor1.isFocused).toBeFalsy()
        expect(editor2.isFocused).toBeTruthy()
        expect(rootView.find('.file-finder')).not.toExist()

        rootView.trigger 'file-finder:toggle'
        expect(finder.miniEditor.getText()).toBe ''

      it "shows all relative file paths for the current project and selects the first", ->
        rootView.trigger 'file-finder:toggle'
        rootView.project.getFilePaths().done (paths) ->
          expect(finder.pathList.children('li').length).toBe paths.length
          for path in paths
            expect(finder.pathList.find("li:contains(#{path})")).toExist()
          expect(finder.pathList.children().first()).toHaveClass 'selected'

    describe "when root view's project has no path", ->
      beforeEach ->
        rootView.project.setPath(null)

      it "does not open the FileFinder", ->
        expect(rootView.find('.file-finder')).not.toExist()
        rootView.trigger 'file-finder:toggle'
        expect(rootView.find('.file-finder')).not.toExist()

  describe "file-finder:cancel event", ->
    it "hides the finder", ->
      rootView.trigger 'file-finder:toggle'
      expect(finder.hasParent()).toBeTruthy()

      finder.trigger 'file-finder:cancel'
      expect(finder.hasParent()).toBeFalsy()

    it "focuses previously focused element", ->
      rootView.attachToDom()
      activeEditor = rootView.activeEditor()
      activeEditor.focus()

      rootView.trigger 'file-finder:toggle'
      expect(activeEditor.isFocused).toBeFalsy()
      expect(finder.miniEditor.isFocused).toBeTruthy()

      finder.trigger 'file-finder:cancel'
      expect(activeEditor.isFocused).toBeTruthy()
      expect(finder.miniEditor.isFocused).toBeFalsy()

  describe "when characters are typed into the input element", ->
    it "displays matching paths in the ol element and selects the first", ->
      rootView.trigger 'file-finder:toggle'

      listLengthBefore = finder.pathList.children().length

      finder.miniEditor.insertText('samp')

      expect(finder.pathList.children().length).toBeLessThan(listLengthBefore)
      expect(finder.pathList.find('li:first')).toHaveClass 'selected'
      expect(finder.pathList.find('li.selected').length).toBe 1

      # we should clear the list before re-populating it
      finder.miniEditor.insertText('txt')

      expect(finder.pathList.children().length).toBe 1
      expect(finder.pathList.find('li:first')).toHaveClass 'selected'
      expect(finder.pathList.find('li:first')).toHaveText 'sample.txt'

  describe "move-down / move-up events", ->
    beforeEach ->
      rootView.trigger 'file-finder:toggle'

    it "selects the next / previous path in the list", ->
      expect(finder.find('li:eq(0)')).toHaveClass "selected"
      expect(finder.find('li:eq(2)')).not.toHaveClass "selected"

      finder.miniEditor.trigger keydownEvent('down')
      finder.miniEditor.trigger keydownEvent('down')

      expect(finder.find('li:eq(0)')).not.toHaveClass "selected"
      expect(finder.find('li:eq(2)')).toHaveClass "selected"

      finder.miniEditor.trigger keydownEvent('up')

      expect(finder.find('li:eq(0)')).not.toHaveClass "selected"
      expect(finder.find('li:eq(1)')).toHaveClass "selected"
      expect(finder.find('li:eq(2)')).not.toHaveClass "selected"

    it "does not fall off the end or begining of the list", ->
      expect(finder.find('li:first')).toHaveClass "selected"
      finder.miniEditor.trigger keydownEvent('up')
      expect(finder.find('li:first')).toHaveClass "selected"

      for i in [1..finder.pathList.children().length+2]
        finder.miniEditor.trigger keydownEvent('down')

      expect(finder.find('li:last')).toHaveClass "selected"

  describe "select-file events", ->
    [editor1, editor2] = []

    beforeEach ->
      rootView.find('.editor').trigger 'split-right'
      [editor1, editor2] = rootView.find('.editor').map -> $(this).view()

      rootView.trigger 'file-finder:toggle'

    describe "when there is a path selected", ->
      it "opens the file associated with that path in the editor", ->
        finder.trigger 'move-down'
        selectedLi = finder.find('li:eq(1)')

        expectedPath = rootView.project.resolve(selectedLi.text())
        expect(editor1.buffer.path).not.toBe expectedPath
        expect(editor2.buffer.path).not.toBe expectedPath

        finder.trigger 'file-finder:select-file'

        expect(finder.hasParent()).toBeFalsy()
        expect(editor1.buffer.path).not.toBe expectedPath
        expect(editor2.buffer.path).toBe expectedPath
        expect(editor2.isFocused).toBeTruthy()

    describe "when there is no path selected", ->
      it "does nothing", ->
        finder.miniEditor.insertText('this should match nothing, because no one wants to drink battery acid')
        finder.trigger 'file-finder:select-file'
        expect(finder.hasParent()).toBeTruthy()

  describe "findMatches(queryString)", ->
    beforeEach ->
      rootView.trigger 'file-finder:toggle'

    it "returns up to finder.maxResults paths if queryString is empty", ->
      expect(finder.paths.length).toBeLessThan finder.maxResults
      expect(finder.findMatches('').length).toBe finder.paths.length

      finder.maxResults = finder.paths.length - 1

      expect(finder.findMatches('').length).toBe finder.maxResults

    it "returns paths sorted by score of match against the given query", ->
      finder.paths = ["app.coffee", "atom/app.coffee"]
      expect(finder.findMatches('app.co')).toEqual ["app.coffee", "atom/app.coffee"]
      expect(finder.findMatches('atom/app.co')).toEqual ["atom/app.coffee"]
