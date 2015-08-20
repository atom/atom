describe "Babel transpiler support", ->
  describe 'when a .js file starts with /** @babel */;', ->
    it "transpiles it using babel", ->
      transpiled = require('./fixtures/babel/babel-comment.js')
      expect(transpiled(3)).toBe 4

  describe "when a .js file starts with 'use babel';", ->
    it "transpiles it using babel", ->
      transpiled = require('./fixtures/babel/babel-single-quotes.js')
      expect(transpiled(3)).toBe 4

  describe 'when a .js file starts with "use babel";', ->
    it "transpiles it using babel", ->
      transpiled = require('./fixtures/babel/babel-double-quotes.js')
      expect(transpiled(3)).toBe 4

  describe "when a .js file does not start with 'use babel';", ->
    it "does not transpile it using babel", ->
      expect(-> require('./fixtures/babel/invalid.js')).toThrow()
