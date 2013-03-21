CSON = require 'cson'

describe "CSON", ->
  describe "@stringify(object)", ->
    describe "when the object is undefined", ->
      it "throws an exception", ->
        expect(-> CSON.stringify()).toThrow()

    describe "when the object is a function", ->
      it "throws an exception", ->
        expect(-> CSON.stringify(-> 'function')).toThrow()

    describe "when the object contains a function", ->
      it "throws an exception", ->
        expect(-> CSON.stringify(a:  -> 'function')).toThrow()

    describe "when formatting an undefined key", ->
      it "does not include the key in the formatted CSON", ->
        expect(CSON.stringify(b: 1, c: undefined)).toBe "'b': 1"

    describe "when formatting a string", ->
      it "returns formatted CSON", ->
        expect(CSON.stringify(a: 'b')).toBe "'a': 'b'"

      it "escapes single quotes", ->
        expect(CSON.stringify(a: "'b'")).toBe "'a': '\\\'b\\\''"

      it "doesn't escape double quotes", ->
        expect(CSON.stringify(a: '"b"')).toBe "'a': '\"b\"'"

      it "escapes newlines", ->
        expect(CSON.stringify("a\nb")).toBe "'a\\nb'"

    describe "when formatting a boolean", ->
      it "returns formatted CSON", ->
        expect(CSON.stringify(true)).toBe 'true'
        expect(CSON.stringify(false)).toBe 'false'
        expect(CSON.stringify(a: true)).toBe "'a': true"
        expect(CSON.stringify(a: false)).toBe "'a': false"

    describe "when formatting a number", ->
      it "returns formatted CSON", ->
        expect(CSON.stringify(54321.012345)).toBe '54321.012345'
        expect(CSON.stringify(a: 14)).toBe "'a': 14"
        expect(CSON.stringify(a: 1.23)).toBe "'a': 1.23"

    describe "when formatting null", ->
      it "returns formatted CSON", ->
        expect(CSON.stringify(null)).toBe 'null'
        expect(CSON.stringify(a: null)).toBe "'a': null"

    describe "when formatting an array", ->
      describe "when the array is empty", ->
        it "puts the array on a single line", ->
          expect(CSON.stringify([])).toBe "[]"

      it "returns formatted CSON", ->
        expect(CSON.stringify(a: ['b'])).toBe "'a': [\n  'b'\n]"
        expect(CSON.stringify(a: ['b', 4])).toBe "'a': [\n  'b'\n  4\n]"

      describe "when the array has an undefined value", ->
        it "formats the undefined value as null", ->
          expect(CSON.stringify(['a', undefined, 'b'])).toBe "[\n  'a'\n  null\n  'b'\n]"

      describe "when the array contains an object", ->
        it "wraps the object in {}", ->
          expect(CSON.stringify([{a:'b', a1: 'b1'}, {c: 'd'}])).toBe "[\n  {\n    'a': 'b'\n    'a1': 'b1'\n  }\n  {\n    'c': 'd'\n  }\n]"

    describe "when formatting an object", ->
      describe "when the object is empty", ->
        it "returns {}", ->
          expect(CSON.stringify({})).toBe "{}"

      it "returns formatted CSON", ->
        expect(CSON.stringify(a: {b: 'c'})).toBe "'a':\n  'b': 'c'"

  describe "when converting back to an object", ->
    it "produces the original object", ->
      object =
        showInvisibles: true
        fontSize: 20
        core:
          themes: ['a', 'b']
        stripTrailingWhitespace:
          singleTrailingNewline: true

      cson = CSON.stringify(object)
      CoffeeScript = require 'coffee-script'
      evaledObject = CoffeeScript.eval(cson, bare: true)
      expect(evaledObject).toEqual object
