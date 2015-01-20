describe "TokenizedLine", ->
  editor = null

  beforeEach ->
    waitsForPromise -> atom.packages.activatePackage('language-coffee-script')

  describe "::isOnlyWhitespace()", ->
    beforeEach ->
      waitsForPromise ->
        atom.project.open('coffee.coffee').then (o) -> editor = o

    it "returns true when the line is only whitespace", ->
      expect(editor.tokenizedLineForScreenRow(3).isOnlyWhitespace()).toBe true
      expect(editor.tokenizedLineForScreenRow(7).isOnlyWhitespace()).toBe true
      expect(editor.tokenizedLineForScreenRow(23).isOnlyWhitespace()).toBe true

    it "returns false when the line is not only whitespace", ->
      expect(editor.tokenizedLineForScreenRow(0).isOnlyWhitespace()).toBe false
      expect(editor.tokenizedLineForScreenRow(2).isOnlyWhitespace()).toBe false

  describe "::getScopeTree()", ->
    it "returns a tree whose inner nodes are scopeDescriptor and whose leaf nodes are tokens in those scopeDescriptor", ->
      [tokens, tokenIndex] = []

      ensureValidScopeTree = (scopeTree, scopeDescriptor=[]) ->
        if scopeTree.children?
          for child in scopeTree.children
            ensureValidScopeTree(child, scopeDescriptor.concat([scopeTree.scope]))
        else
          expect(scopeTree).toBe tokens[tokenIndex++]
          expect(scopeDescriptor).toEqual scopeTree.scopes

      waitsForPromise ->
        atom.project.open('coffee.coffee').then (o) -> editor = o

      runs ->
        tokenIndex = 0
        tokens = editor.tokenizedLineForScreenRow(1).tokens
        scopeTree = editor.tokenizedLineForScreenRow(1).getScopeTree()
        ensureValidScopeTree(scopeTree)
