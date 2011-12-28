FileFinder = require 'file-finder'

fdescribe 'FileFinder', ->
  finder = null

  beforeEach -> 
    urls = ['app.coffee', 'buffer.coffee', 'atom/app.coffee', 'atom/buffer.coffee']
    finder = FileFinder.build {urls}

  describe 'findMatches(queryString)', ->
    it "returns urls sorted by score of match against the given query", ->
      expect(finder.findMatches('ap')).toEqual ["app.coffee", "atom/app.coffee"]
      expect(finder.findMatches('a/ap')).toEqual ["atom/app.coffee"]

