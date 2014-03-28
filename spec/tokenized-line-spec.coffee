describe "TokenizedLine", ->
  editor = null

  beforeEach ->
    waitsForPromise -> atom.packages.activatePackage('language-javascript')
    runs -> editor = atom.project.openSync('sample.js')

  describe "::getScopeTree()", ->
    it "returns a tree whose inner nodes are scopes and whose leaf nodes are tokens in those scopes", ->
      scopeTree = editor.lineForScreenRow(1).getScopeTree()
      expect(scopeTree.scope).toBe 'source.js'
      expect(scopeTree.children[0].value).toBe '  '
      expect(scopeTree.children[1].scope).toBe 'storage.modifier.js'
      expect(scopeTree.children[1].children[0].value).toBe 'var'
      expect(scopeTree.children[2].value).toBe ' '
      expect(scopeTree.children[3].scope).toBe 'meta.function.js'
      expect(scopeTree.children[4].value).toBe ' '
      expect(scopeTree.children[5].scope).toBe 'meta.brace.curly.js'
      expect(scopeTree.children[5].children[0].value).toBe '{'
