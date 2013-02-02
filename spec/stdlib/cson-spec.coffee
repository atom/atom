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

    describe "when formatting an empty object", ->
      it "returns the empty string", ->
      expect(CSON.stringify({})).toBe ""

    describe "when formatting a string", ->
      it "returns formatted CSON", ->
        expect(CSON.stringify(a: 'b')).toBe "'a': 'b'"

      it "escapes single quotes", ->
        expect(CSON.stringify(a: "'b'")).toBe "'a': '\\\'b\\\''"

      it "doesn't escape double quotes", ->
        expect(CSON.stringify(a: '"b"')).toBe "'a': '\"b\"'"

    describe "when formatting a boolean", ->
      it "returns formatted CSON", ->
        expect(CSON.stringify(a: true)).toBe "'a': true"
        expect(CSON.stringify(a: false)).toBe "'a': false"

    describe "when formatting a number", ->
      it "returns formatted CSON", ->
        expect(CSON.stringify(a: 14)).toBe "'a': 14"
        expect(CSON.stringify(a: 1.23)).toBe "'a': 1.23"

    describe "when formatting null", ->
      it "returns formatted CSON", ->
        expect(CSON.stringify(a: null)).toBe "'a': null"

    describe "when formatting an array", ->
      describe "when the array is empty", ->
        it "puts the array on a single line", ->
          expect(CSON.stringify([])).toBe "[]"

      it "returns formatted CSON", ->
        expect(CSON.stringify(a: ['b'])).toBe "'a': [\n  'b'\n]"
        expect(CSON.stringify(a: ['b', 4])).toBe "'a': [\n  'b'\n  4\n]"

    describe "when formatting an object", ->
      it "returns formatted CSON", ->
        expect(CSON.stringify(a: {b: 'c'})).toBe "'a':\n  'b': 'c'"
