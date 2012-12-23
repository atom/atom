describe "the `syntax` global", ->
  describe ".getProperty(scopeDescriptor)", ->
    it "returns the property with the most specific scope selector", ->
      syntax.addProperties(".source.coffee .string.quoted.double.coffee", foo: bar: baz: 42)
      syntax.addProperties(".source .string.quoted.double", foo: bar: baz: 22)
      syntax.addProperties(".source", foo: bar: baz: 11)
      syntax.addProperties(foo: bar: baz: 1)

      expect(syntax.getProperty([".source.coffee", ".string.quoted.double.coffee"], "foo.bar.baz")).toBe 42
      expect(syntax.getProperty([".source.js", ".string.quoted.double.js"], "foo.bar.baz")).toBe 22
      expect(syntax.getProperty([".source.js", ".variable.assignment.js"], "foo.bar.baz")).toBe 11
      expect(syntax.getProperty([".text"], "foo.bar.baz")).toBe 1
