const SyntaxScopeMap = require('../src/syntax-scope-map');

describe('SyntaxScopeMap', () => {
  it('can match immediate child selectors', () => {
    const map = new SyntaxScopeMap({
      'a > b > c': 'x',
      'b > c': 'y',
      c: 'z'
    });

    expect(map.get(['a', 'b', 'c'], [0, 0, 0])).toBe('x');
    expect(map.get(['d', 'b', 'c'], [0, 0, 0])).toBe('y');
    expect(map.get(['d', 'e', 'c'], [0, 0, 0])).toBe('z');
    expect(map.get(['e', 'c'], [0, 0, 0])).toBe('z');
    expect(map.get(['c'], [0, 0, 0])).toBe('z');
    expect(map.get(['d'], [0, 0, 0])).toBe(undefined);
  });

  it('can match :nth-child pseudo-selectors on leaves', () => {
    const map = new SyntaxScopeMap({
      'a > b': 'w',
      'a > b:nth-child(1)': 'x',
      b: 'y',
      'b:nth-child(2)': 'z'
    });

    expect(map.get(['a', 'b'], [0, 0])).toBe('w');
    expect(map.get(['a', 'b'], [0, 1])).toBe('x');
    expect(map.get(['a', 'b'], [0, 2])).toBe('w');
    expect(map.get(['b'], [0])).toBe('y');
    expect(map.get(['b'], [1])).toBe('y');
    expect(map.get(['b'], [2])).toBe('z');
  });

  it('can match :nth-child pseudo-selectors on interior nodes', () => {
    const map = new SyntaxScopeMap({
      'b:nth-child(1) > c': 'w',
      'a > b > c': 'x',
      'a > b:nth-child(2) > c': 'y'
    });

    expect(map.get(['b', 'c'], [0, 0])).toBe(undefined);
    expect(map.get(['b', 'c'], [1, 0])).toBe('w');
    expect(map.get(['a', 'b', 'c'], [1, 0, 0])).toBe('x');
    expect(map.get(['a', 'b', 'c'], [1, 2, 0])).toBe('y');
  });

  it('allows anonymous tokens to be referred to by their string value', () => {
    const map = new SyntaxScopeMap({
      '"b"': 'w',
      'a > "b"': 'x',
      'a > "b":nth-child(1)': 'y',
      '"\\""': 'z'
    });

    expect(map.get(['b'], [0], true)).toBe(undefined);
    expect(map.get(['b'], [0], false)).toBe('w');
    expect(map.get(['a', 'b'], [0, 0], false)).toBe('x');
    expect(map.get(['a', 'b'], [0, 1], false)).toBe('y');
    expect(map.get(['a', '"'], [0, 1], false)).toBe('z');
  });

  it('supports the wildcard selector', () => {
    const map = new SyntaxScopeMap({
      '*': 'w',
      'a > *': 'x',
      'a > *:nth-child(1)': 'y',
      'a > *:nth-child(1) > b': 'z'
    });

    expect(map.get(['b'], [0])).toBe('w');
    expect(map.get(['c'], [0])).toBe('w');
    expect(map.get(['a', 'b'], [0, 0])).toBe('x');
    expect(map.get(['a', 'b'], [0, 1])).toBe('y');
    expect(map.get(['a', 'c'], [0, 1])).toBe('y');
    expect(map.get(['a', 'c', 'b'], [0, 1, 1])).toBe('z');
    expect(map.get(['a', 'c', 'b'], [0, 2, 1])).toBe('w');
  });

  it('distinguishes between an anonymous * token and the wildcard selector', () => {
    const map = new SyntaxScopeMap({
      '"*"': 'x',
      'a > "b"': 'y'
    });

    expect(map.get(['b'], [0], false)).toBe(undefined);
    expect(map.get(['*'], [0], false)).toBe('x');
  });
});
