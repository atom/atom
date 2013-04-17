TextMateScopeSelector = require 'text-mate-scope-selector'

describe "TextMateScopeSelector", ->
  it "matches the asterix", ->
    expect(new TextMateScopeSelector('*').matches(['a'])).toBeTruthy()
    expect(new TextMateScopeSelector('*').matches(['b', 'c'])).toBeTruthy()
    expect(new TextMateScopeSelector('a.*.c').matches(['a.b.c'])).toBeTruthy()
    expect(new TextMateScopeSelector('a.*.c').matches(['a.b.c.d'])).toBeTruthy()
    expect(new TextMateScopeSelector('a.*.c').matches(['a.b.d.c'])).toBeFalsy()

  it "matches prefixes", ->
    expect(new TextMateScopeSelector('a').matches(['a'])).toBeTruthy()
    expect(new TextMateScopeSelector('a').matches(['a.b'])).toBeTruthy()
    expect(new TextMateScopeSelector('a').matches(['abc'])).toBeFalsy()

  it "matches alternation", ->
    expect(new TextMateScopeSelector('a | b').matches(['b'])).toBeTruthy()
    expect(new TextMateScopeSelector('a|b|c').matches(['c'])).toBeTruthy()
    expect(new TextMateScopeSelector('a|b|c').matches(['d'])).toBeFalsy()

  it "matches negation", ->
    expect(new TextMateScopeSelector('a - c').matches(['a', 'b'])).toBeTruthy()
    expect(new TextMateScopeSelector('a-b').matches(['a', 'b'])).toBeFalsy()

  it "matches composites", ->
    expect(new TextMateScopeSelector('a,b,c').matches(['b', 'c'])).toBeTruthy()
    expect(new TextMateScopeSelector('a, b, c').matches(['d', 'e'])).toBeFalsy()
    expect(new TextMateScopeSelector('a, b, c').matches(['d', 'c.e'])).toBeTruthy()

  it "matches groups", ->
    expect(new TextMateScopeSelector('(a,b) | (c, d)').matches(['a'])).toBeTruthy()
    expect(new TextMateScopeSelector('(a,b) | (c, d)').matches(['b'])).toBeTruthy()
    expect(new TextMateScopeSelector('(a,b) | (c, d)').matches(['c'])).toBeTruthy()
    expect(new TextMateScopeSelector('(a,b) | (c, d)').matches(['d'])).toBeTruthy()
    expect(new TextMateScopeSelector('(a,b) | (c, d)').matches(['e'])).toBeFalsy()
