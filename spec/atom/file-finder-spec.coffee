FileFinder = require 'file-finder'

describe 'FileFinder', ->
  finder = null
  urls = null

  beforeEach ->
    urls = ['app.coffee', 'buffer.coffee', 'atom/app.coffee', 'atom/buffer.coffee']
    finder = FileFinder.build {urls}

  describe "initialize", ->
    it "populates the ol with all urls and selects the first element", ->
      expect(finder.urlList.find('li').length).toBe urls.length
      expect(finder.urlList.find('li:first')).toHaveClass('selected')
      expect(finder.urlList.find('li.selected').length).toBe 1

  describe "when characters are typed into the input element", ->
    it "displays matching urls in the ol element and selects the first", ->
      finder.input.val('ap')
      finder.input.trigger 'input'

      expect(finder.urlList.children().length).toBe 2
      expect(finder.urlList.find('li:contains(app.coffee)').length).toBe 2
      expect(finder.urlList.find('li:contains(atom/app.coffee)').length).toBe 1
      expect(finder.urlList.find('li:first')).toHaveClass 'selected'
      expect(finder.urlList.find('li.selected').length).toBe 1

      # we should clear the list before re-populating it
      finder.input.val('a/ap')
      finder.input.trigger 'input'

      expect(finder.urlList.children().length).toBe 1
      expect(finder.urlList.find('li:contains(atom/app.coffee)').length).toBe 1

  describe "move-down / move-up events", ->
    it "selects the next / previous url in the list", ->
      expect(finder.find('li:eq(0)')).toHaveClass "selected"
      expect(finder.find('li:eq(2)')).not.toHaveClass "selected"

      finder.trigger 'move-down'
      finder.trigger 'move-down'

      expect(finder.find('li:eq(0)')).not.toHaveClass "selected"
      expect(finder.find('li:eq(2)')).toHaveClass "selected"

      finder.trigger 'move-up'

      expect(finder.find('li:eq(0)')).not.toHaveClass "selected"
      expect(finder.find('li:eq(1)')).toHaveClass "selected"
      expect(finder.find('li:eq(2)')).not.toHaveClass "selected"

    it "does not fall off the end or begining of the list", ->
      expect(finder.find('li:first')).toHaveClass "selected"
      finder.trigger 'move-up'
      expect(finder.find('li:first')).toHaveClass "selected"

      for i in [1..urls.length+10]
        finder.trigger 'move-down'

      expect(finder.find('li:last')).toHaveClass "selected"

  describe "select", ->
    selectedCallback = jasmine.createSpy 'selected'

    beforeEach ->
      finder = FileFinder.build {urls, selected: selectedCallback}

    it "when a file is selected Editor.open is called", ->
      spyOn(finder, 'remove')
      finder.moveDown()
      finder.trigger 'select'
      expect(selectedCallback).toHaveBeenCalledWith(urls[1])
      expect(finder.remove).toHaveBeenCalled()

    it "when no file is selected, does nothing", ->
      spyOn(atom, 'open')
      finder.input.val('this-will-match-nothing-hopefully')
      finder.populateUrlList()
      finder.trigger 'select'
      expect(atom.open).not.toHaveBeenCalled()

  describe "findMatches(queryString)", ->
    it "returns up to finder.maxResults urls if queryString is empty", ->
      expect(urls.length).toBeLessThan finder.maxResults
      expect(finder.findMatches('').length).toBe urls.length

      finder.maxResults = urls.length - 1

      expect(finder.findMatches('').length).toBe finder.maxResults

    it "returns urls sorted by score of match against the given query", ->
      expect(finder.findMatches('ap')).toEqual ["app.coffee", "atom/app.coffee"]
      expect(finder.findMatches('a/ap')).toEqual ["atom/app.coffee"]

