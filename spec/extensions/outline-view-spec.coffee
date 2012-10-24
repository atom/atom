TagGenerator = require 'outline-view/tag-generator'

describe "OutlineView", ->

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
