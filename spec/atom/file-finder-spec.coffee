FileFinder = require 'file-finder'

describe 'FileFinder', ->
  finder = null

  beforeEach -> 
    urls = ['app.coffee', 'buffer.coffee', 'atom/app.coffee', 'atom/buffer.coffee']
    finder = FileFinder.build {urls}

  describe "when characters are typed into the input element", ->
    it "displays matching urls in the ol element", ->
      expect(finder.urlList.find('li')).not.toExist()

      finder.input.text('ap')
      finder.input.keypress()

      expect(finder.urlList.children().length).toBe 2
      expect(finder.urlList.find('li:contains(app.coffee)').length).toBe 2
      expect(finder.urlList.find('li:contains(atom/app.coffee)').length).toBe 1

      # we should clear the list before re-populating it
      finder.input.text('a/ap')
      finder.input.keypress()

      expect(finder.urlList.children().length).toBe 1
      expect(finder.urlList.find('li:contains(atom/app.coffee)').length).toBe 1

  describe "findMatches(queryString)", ->
    it "returns urls sorted by score of match against the given query", ->
      expect(finder.findMatches('ap')).toEqual ["app.coffee", "atom/app.coffee"]
      expect(finder.findMatches('a/ap')).toEqual ["atom/app.coffee"]

