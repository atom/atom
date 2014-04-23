describe "TokenizedLine", ->
  editor = null

  beforeEach ->
    waitsForPromise -> atom.packages.activatePackage('language-coffee-script')

  describe "::getScopeTree()", ->
    it "returns a tree whose inner nodes are scopes and whose leaf nodes are tokens in those scopes", ->
      editor = atom.project.openSync('coffee.coffee')

      ensureValidScopeTree = (scopeTree, scopes=[]) ->
        if scopeTree.children?
          for child in scopeTree.children
            ensureValidScopeTree(child, scopes.concat([scopeTree.scope]))
        else
          expect(scopeTree).toBe tokens[tokenIndex++]
          expect(scopes).toEqual scopeTree.scopes

      tokenIndex = 0
      tokens = editor.lineForScreenRow(1).tokens
      scopeTree = editor.lineForScreenRow(1).getScopeTree()
      ensureValidScopeTree(scopeTree)
