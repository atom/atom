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
