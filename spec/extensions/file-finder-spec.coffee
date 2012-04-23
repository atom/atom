FileFinder = require 'file-finder'

{$$} = require 'space-pen'

describe 'FileFinder', ->
  finder = null
  paths = null

  beforeEach ->
    paths = ['app.coffee', 'buffer.coffee', 'atom/app.coffee', 'atom/buffer.coffee']
    finder = new FileFinder({paths})
    finder.enableKeymap()

  describe "initialize", ->
    it "populates the ol with all paths and selects the first element", ->
      expect(finder.pathList.find('li').length).toBe paths.length
      expect(finder.pathList.find('li:first')).toHaveClass('selected')
      expect(finder.pathList.find('li.selected').length).toBe 1

  describe "when characters are typed into the input element", ->
    it "displays matching paths in the ol element and selects the first", ->
      finder.editor.insertText('ap')

      expect(finder.pathList.children().length).toBe 2
      expect(finder.pathList.find('li:contains(app.coffee)').length).toBe 2
      expect(finder.pathList.find('li:contains(atom/app.coffee)').length).toBe 1
      expect(finder.pathList.find('li:first')).toHaveClass 'selected'
      expect(finder.pathList.find('li.selected').length).toBe 1

      # we should clear the list before re-populating it
      finder.editor.setCursorScreenPosition([0, 0])
      finder.editor.insertText('a/')

      expect(finder.pathList.children().length).toBe 1
      expect(finder.pathList.find('li:contains(atom/app.coffee)').length).toBe 1

  describe "move-down / move-up events", ->
    it "selects the next / previous path in the list", ->
      expect(finder.find('li:eq(0)')).toHaveClass "selected"
      expect(finder.find('li:eq(2)')).not.toHaveClass "selected"

      finder.editor.trigger keydownEvent('down')
      finder.editor.trigger keydownEvent('down')

      expect(finder.find('li:eq(0)')).not.toHaveClass "selected"
      expect(finder.find('li:eq(2)')).toHaveClass "selected"

      finder.editor.trigger keydownEvent('up')

      expect(finder.find('li:eq(0)')).not.toHaveClass "selected"
      expect(finder.find('li:eq(1)')).toHaveClass "selected"
      expect(finder.find('li:eq(2)')).not.toHaveClass "selected"

    it "does not fall off the end or begining of the list", ->
      expect(finder.find('li:first')).toHaveClass "selected"
      finder.editor.trigger keydownEvent('up')
      expect(finder.find('li:first')).toHaveClass "selected"

      for i in [1..paths.length+10]
        finder.editor.trigger keydownEvent('down')

      expect(finder.find('li:last')).toHaveClass "selected"

  describe "select", ->
    selectedCallback = jasmine.createSpy 'selected'

    beforeEach ->
      finder = new FileFinder({paths, selected: selectedCallback})
      finder.enableKeymap()

    it "when a file is selected Editor.open is called", ->
      spyOn(finder, 'remove')
      finder.moveDown()
      finder.editor.trigger keydownEvent('enter')
      expect(selectedCallback).toHaveBeenCalledWith(paths[1])
      expect(finder.remove).toHaveBeenCalled()

    it "when no file is selected, does nothing", ->
      spyOn(atom, 'open')
      finder.editor.insertText('this-will-match-nothing-hopefully')
      finder.populatePathList()
      finder.editor.trigger keydownEvent('enter')
      expect(atom.open).not.toHaveBeenCalled()

  describe "findMatches(queryString)", ->
    it "returns up to finder.maxResults paths if queryString is empty", ->
      expect(paths.length).toBeLessThan finder.maxResults
      expect(finder.findMatches('').length).toBe paths.length

      finder.maxResults = paths.length - 1

      expect(finder.findMatches('').length).toBe finder.maxResults

    it "returns paths sorted by score of match against the given query", ->
      expect(finder.findMatches('ap')).toEqual ["app.coffee", "atom/app.coffee"]
      expect(finder.findMatches('a/ap')).toEqual ["atom/app.coffee"]
