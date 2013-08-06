TextMateScopeSelector = require 'text-mate-scope-selector'

describe "TextMateScopeSelector", ->
  describe ".matches(scopes)", ->
    it "matches the asterix", ->
      expect(new TextMateScopeSelector('*').matches(['a'])).toBeTruthy()
      expect(new TextMateScopeSelector('*').matches(['b', 'c'])).toBeTruthy()
      expect(new TextMateScopeSelector('a.*.c').matches(['a.b.c'])).toBeTruthy()
      expect(new TextMateScopeSelector('a.*.c').matches(['a.b.c.d'])).toBeTruthy()
      expect(new TextMateScopeSelector('a.*.c').matches(['a.b.d.c'])).toBeFalsy()

    it "matches prefixes", ->
      expect(new TextMateScopeSelector('a').matches(['a'])).toBeTruthy()
      expect(new TextMateScopeSelector('a').matches(['a.b'])).toBeTruthy()
      expect(new TextMateScopeSelector('a.b').matches(['a.b.c'])).toBeTruthy()
      expect(new TextMateScopeSelector('a').matches(['abc'])).toBeFalsy()
      expect(new TextMateScopeSelector('a.b-c').matches(['a.b-c.d'])).toBeTruthy()
      expect(new TextMateScopeSelector('a.b').matches(['a.b-d'])).toBeFalsy()
      expect(new TextMateScopeSelector('c++').matches(['c++'])).toBeTruthy()
      expect(new TextMateScopeSelector('c++').matches(['c'])).toBeFalsy()
      expect(new TextMateScopeSelector('a_b_c').matches(['a_b_c'])).toBeTruthy()
      expect(new TextMateScopeSelector('a_b_c').matches(['a_b'])).toBeFalsy()

    it "matches disjunction", ->
      expect(new TextMateScopeSelector('a | b').matches(['b'])).toBeTruthy()
      expect(new TextMateScopeSelector('a|b|c').matches(['c'])).toBeTruthy()
      expect(new TextMateScopeSelector('a|b|c').matches(['d'])).toBeFalsy()

    it "matches negation", ->
      expect(new TextMateScopeSelector('a - c').matches(['a', 'b'])).toBeTruthy()
      expect(new TextMateScopeSelector('a-b').matches(['a', 'b'])).toBeFalsy()
      expect(new TextMateScopeSelector('a -b').matches(['a', 'b'])).toBeFalsy()
      expect(new TextMateScopeSelector('a -c').matches(['a', 'b'])).toBeTruthy()
      expect(new TextMateScopeSelector('a-c').matches(['a', 'b'])).toBeFalsy()

    it "matches conjunction", ->
      expect(new TextMateScopeSelector('a & b').matches(['b', 'a'])).toBeTruthy()
      expect(new TextMateScopeSelector('a&b&c').matches(['c'])).toBeFalsy()
      expect(new TextMateScopeSelector('a&b&c').matches(['a', 'b', 'd'])).toBeFalsy()

    it "matches composites", ->
      expect(new TextMateScopeSelector('a,b,c').matches(['b', 'c'])).toBeTruthy()
      expect(new TextMateScopeSelector('a, b, c').matches(['d', 'e'])).toBeFalsy()
      expect(new TextMateScopeSelector('a, b, c').matches(['d', 'c.e'])).toBeTruthy()
      expect(new TextMateScopeSelector('a,').matches(['a', 'c'])).toBeTruthy()
      expect(new TextMateScopeSelector('a,').matches(['b', 'c'])).toBeFalsy()

    it "matches groups", ->
      expect(new TextMateScopeSelector('(a,b) | (c, d)').matches(['a'])).toBeTruthy()
      expect(new TextMateScopeSelector('(a,b) | (c, d)').matches(['b'])).toBeTruthy()
      expect(new TextMateScopeSelector('(a,b) | (c, d)').matches(['c'])).toBeTruthy()
      expect(new TextMateScopeSelector('(a,b) | (c, d)').matches(['d'])).toBeTruthy()
      expect(new TextMateScopeSelector('(a,b) | (c, d)').matches(['e'])).toBeFalsy()

    it "matches paths", ->
      expect(new TextMateScopeSelector('a b').matches(['a', 'b'])).toBeTruthy()
      expect(new TextMateScopeSelector('a b').matches(['b', 'a'])).toBeFalsy()
      expect(new TextMateScopeSelector('a c').matches(['a', 'b', 'c', 'd', 'e'])).toBeTruthy()
      expect(new TextMateScopeSelector('a b e').matches(['a', 'b', 'c', 'd', 'e'])).toBeTruthy()

  describe ".toCssSelector()", ->
    it "converts the TextMate scope selector to a CSS selector", ->
      expect(new TextMateScopeSelector('a b c').toCssSelector()).toBe '.a .b .c'
      expect(new TextMateScopeSelector('a.b.c').toCssSelector()).toBe '.a.b.c'
      expect(new TextMateScopeSelector('*').toCssSelector()).toBe '*'
      expect(new TextMateScopeSelector('a - b').toCssSelector()).toBe '.a :not(.b)'
      expect(new TextMateScopeSelector('a & b').toCssSelector()).toBe '.a .b'
      expect(new TextMateScopeSelector('a | b').toCssSelector()).toBe '.a .b'
      expect(new TextMateScopeSelector('a - (b.c d)').toCssSelector()).toBe '.a :not(.b.c .d)'
