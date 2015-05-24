Gutter = require '../src/gutter'
GutterContainer = require '../src/gutter-container'

describe 'GutterContainer', ->
  gutterContainer = null
  fakeTextEditor = {}

  beforeEach ->
    gutterContainer = new GutterContainer fakeTextEditor

  describe 'when initialized', ->
    it 'it has no gutters', ->
      expect(gutterContainer.getGutters().length).toBe 0

  describe '::addGutter', ->
    it 'creates a new gutter', ->
      newGutter = gutterContainer.addGutter {'test-gutter', priority: 1}
      expect(gutterContainer.getGutters()).toEqual [newGutter]
      expect(newGutter.priority).toBe 1

    it 'throws an error if the provided gutter name is already in use', ->
      name = 'test-gutter'
      gutterContainer.addGutter {name}
      expect(gutterContainer.addGutter.bind(null, {name})).toThrow()

    it 'keeps added gutters sorted by ascending priority', ->
      gutter1 = gutterContainer.addGutter {name: 'first', priority: 1}
      gutter3 = gutterContainer.addGutter {name: 'third', priority: 3}
      gutter2 = gutterContainer.addGutter {name: 'second', priority: 2}
      expect(gutterContainer.getGutters()).toEqual [gutter1, gutter2, gutter3]

  describe '::removeGutter', ->
    removedGutters = null

    beforeEach ->
      gutterContainer = new GutterContainer fakeTextEditor
      removedGutters = []
      gutterContainer.onDidRemoveGutter (gutterName) ->
        removedGutters.push gutterName

    it 'removes the gutter if it is contained by this GutterContainer', ->
      gutter = gutterContainer.addGutter {'test-gutter'}
      expect(gutterContainer.getGutters()).toEqual [gutter]
      gutterContainer.removeGutter gutter
      expect(gutterContainer.getGutters().length).toBe 0
      expect(removedGutters).toEqual [gutter.name]

    it 'throws an error if the gutter is not within this GutterContainer', ->
      fakeOtherTextEditor = {}
      otherGutterContainer = new GutterContainer fakeOtherTextEditor
      gutter = new Gutter 'gutter-name', otherGutterContainer
      expect(gutterContainer.removeGutter.bind(null, gutter)).toThrow()
