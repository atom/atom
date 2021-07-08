const SyntaxScopeMap = require('../src/syntax-scope-map');

describe('SyntaxScopeMap', () => {
  it('can match immediate child selectors', () => {
    const map = new SyntaxScopeMap({
      'a > b > c': 'x',
      'b > c': 'y',
      c: 'z'
    });

    expect(map.get(['a', 'b', 'c'], [0, 0, 0])).toEqual(['z', 'y', 'x']);
    expect(map.get(['d', 'b', 'c'], [0, 0, 0])).toEqual(['z', 'y']);
    expect(map.get(['d', 'e', 'c'], [0, 0, 0])).toEqual(['z']);
    expect(map.get(['e', 'c'], [0, 0, 0])).toEqual(['z']);
    expect(map.get(['c'], [0, 0, 0])).toEqual(['z']);
    expect(map.get(['d'], [0, 0, 0])).toBe(undefined);
  });

  it('can match :nth-child pseudo-selectors on leaves', () => {
    const map = new SyntaxScopeMap({
      'a > b': 'w',
      'a > b:nth-child(1)': 'x',
      b: 'y',
      'b:nth-child(2)': 'z'
    });

    expect(map.get(['a', 'b'], [0, 0])).toEqual(['y', 'w']);
    expect(map.get(['a', 'b'], [0, 1])).toEqual(['y', 'w', 'x']);
    expect(map.get(['a', 'b'], [0, 2])).toEqual(['y', 'z', 'w']);
    expect(map.get(['b'], [0])).toEqual(['y']);
    expect(map.get(['b'], [1])).toEqual(['y']);
    expect(map.get(['b'], [2])).toEqual(['y', 'z']);
  });

  it('can match :nth-child pseudo-selectors on interior nodes', () => {
    const map = new SyntaxScopeMap({
      'b:nth-child(1) > c': 'w',
      'a > b > c': 'x',
      'a > b:nth-child(2) > c': 'y'
    });

    expect(map.get(['b', 'c'], [0, 0])).toBe(undefined);
    expect(map.get(['b', 'c'], [1, 0])).toEqual(['w']);
    expect(map.get(['a', 'b', 'c'], [1, 0, 0])).toEqual(['x']);
    expect(map.get(['a', 'b', 'c'], [1, 1, 0])).toEqual(['w', 'x']);
    expect(map.get(['a', 'b', 'c'], [1, 2, 0])).toEqual(['x', 'y']);
  });

  it('allows anonymous tokens to be referred to by their string value', () => {
    const map = new SyntaxScopeMap({
      '"b"': 'w',
      'a > "b"': 'x',
      'a > "b":nth-child(1)': 'y',
      '"\\""': 'z'
    });

    expect(map.get(['b'], [0], true)).toBe(undefined);
    expect(map.get(['b'], [0], false)).toEqual(['w']);
    expect(map.get(['a', 'b'], [0, 0], false)).toEqual(['w', 'x']);
    expect(map.get(['a', 'b'], [0, 1], false)).toEqual(['w', 'x', 'y']);
    expect(map.get(['a', '"'], [0, 1], false)).toEqual(['z']);
  });

  it('supports the wildcard selector', () => {
    const map = new SyntaxScopeMap({
      '*': 'w',
      'a > *': 'x',
      'a > *:nth-child(1)': 'y',
      'a > *:nth-child(1) > b': 'z'
    });

    expect(map.get(['b'], [0])).toEqual(['w']);
    expect(map.get(['c'], [0])).toEqual(['w']);
    expect(map.get(['a', 'b'], [0, 0])).toEqual(['w', 'x']);
    expect(map.get(['a', 'b'], [0, 1])).toEqual(['w', 'x', 'y']);
    expect(map.get(['a', 'c'], [0, 1])).toEqual(['w', 'x', 'y']);
    expect(map.get(['a', 'c', 'b'], [0, 2, 1])).toEqual(['w']);
    expect(map.get(['a', 'c', 'b'], [0, 1, 1])).toEqual(['w', 'z']);
    expect(map.get(['a', 'a', 'b'], [0, 2, 1])).toEqual(['w', 'x', 'y']);
    expect(map.get(['a', 'a', 'b'], [0, 1, 1])).toEqual(['w', 'x', 'y', 'z']);
  });

  it('distinguishes between an anonymous token and the wildcard selector', () => {
    const map = new SyntaxScopeMap({
      '*': 's',
      b: 't',
      '"*"': 'u',
      '"b"': 'v',
      'a > *': 'w',
      'a > b': 'x',
      'a > "*"': 'y',
      'a > "b"': 'z'
    });

    expect(map.get(['*'], [0])).toEqual(['s']);
    expect(map.get(['b'], [0])).toEqual(['s', 't']);
    expect(map.get(['*'], [0], false)).toEqual(['s', 'u']);
    expect(map.get(['b'], [0], false)).toEqual(['s', 'v']);
    expect(map.get(['a', '*'], [0, 0])).toEqual(['s', 'w']);
    expect(map.get(['a', 'b'], [0, 0])).toEqual(['s', 't', 'w', 'x']);
    expect(map.get(['a', '*'], [0, 0], false)).toEqual(['s', 'u', 'w', 'y']);
    expect(map.get(['a', 'b'], [0, 0], false)).toEqual(['s', 'v', 'w', 'z']);
    expect(map.get(['a', 'b', '*'], [0, 0, 0])).toEqual(['s']);
    expect(map.get(['a', 'b', 'b'], [0, 0, 0])).toEqual(['s', 't']);
    expect(map.get(['a', 'b', '*'], [0, 0, 0], false)).toEqual(['s', 'u']);
    expect(map.get(['a', 'b', 'b'], [0, 0, 0], false)).toEqual(['s', 'v']);
  });

  it('understands adjacent wildcards', () => {
    const map = new SyntaxScopeMap({
      '* > *': 'w',
      '* > * > * > d': 'x',
      'a > * > * > *': 'y',
      'a > * > * > d': 'z'
    });

    expect(map.get(['a'], [0])).toBe(undefined);
    expect(map.get(['d'], [0])).toBe(undefined);
    expect(map.get(['a', 'd'], [0, 0])).toEqual(['w']);
    expect(map.get(['a', 'b', 'd'], [0, 0])).toEqual(['w']);
    expect(map.get(['a', 'b', 'c', 'c'], [0, 0])).toEqual(['w', 'y']);
    expect(map.get(['b', 'b', 'c', 'd'], [0, 0])).toEqual(['w', 'x']);
    expect(map.get(['a', 'b', 'c', 'd'], [0, 0])).toEqual(['w', 'x', 'y', 'z']);
  });

  it('sorts selectors by specificity', () => {
    const map = new SyntaxScopeMap({
      c: 'j',
      '* > c': 'k',
      '* > c:nth-child(1)': 'l',
      'b > *': 'm',
      'b > c': 'n',
      'b > c:nth-child(1)': 'o',
      'b:nth-child(1) > *': 'p',
      'b:nth-child(1) > c': 'q',
      'b:nth-child(1) > c:nth-child(1)': 'r',
      '* > b > c': 's',
      'a > * > *': 't',
      'a > * > c:nth-child(1)': 'u',
      'a > b > *': 'v',
      'a > b > c': 'w',
      'a > b > c:nth-child(1)': 'x',
      'a:nth-child(1) > * > c': 'y',
      'a:nth-child(1) > b:nth-child(1) > c': 'z'
    });

    expect(map.get(['a', 'b', 'c'], [0, 0, 0])).toEqual([
      'j',
      'k',
      'm',
      'n',
      's',
      't',
      'v',
      'w'
    ]);
    expect(map.get(['a', 'b', 'c'], [0, 0, 1])).toEqual([
      'j',
      'k',
      'l',
      'm',
      'n',
      'o',
      's',
      't',
      'u',
      'v',
      'w',
      'x'
    ]);
    expect(map.get(['a', 'b', 'c'], [0, 1, 0])).toEqual([
      'j',
      'k',
      'm',
      'n',
      'p',
      'q',
      's',
      't',
      'v',
      'w'
    ]);
    expect(map.get(['a', 'b', 'c'], [0, 1, 1])).toEqual([
      'j',
      'k',
      'l',
      'm',
      'n',
      'o',
      'p',
      'q',
      'r',
      's',
      't',
      'u',
      'v',
      'w',
      'x'
    ]);
    expect(map.get(['a', 'b', 'c'], [1, 0, 0])).toEqual([
      'j',
      'k',
      'm',
      'n',
      's',
      't',
      'v',
      'w',
      'y'
    ]);
    expect(map.get(['a', 'b', 'c'], [1, 0, 1])).toEqual([
      'j',
      'k',
      'l',
      'm',
      'n',
      'o',
      's',
      't',
      'u',
      'v',
      'w',
      'x',
      'y'
    ]);
    expect(map.get(['a', 'b', 'c'], [1, 1, 0])).toEqual([
      'j',
      'k',
      'm',
      'n',
      'p',
      'q',
      's',
      't',
      'v',
      'w',
      'y',
      'z'
    ]);
    expect(map.get(['a', 'b', 'c'], [1, 1, 1])).toEqual([
      'j',
      'k',
      'l',
      'm',
      'n',
      'o',
      'p',
      'q',
      'r',
      's',
      't',
      'u',
      'v',
      'w',
      'x',
      'y',
      'z'
    ]);
  });

  it('throws an error for invalid selectors', () => {
    const invalid = [
      { 'a > b >': '' },
      { 'a >:nth-child(1) b': '' },
      { 'a > b:last-of-type': '' },
      { 'a:nth-child(1):nth-child(2)': '' }
    ];

    expect(() => new SyntaxScopeMap(invalid[0])).toThrow(
      "Unsupported selector 'a > b >'"
    );
    expect(() => new SyntaxScopeMap(invalid[1])).toThrow(
      "Unsupported selector 'a >:nth-child(1) b'"
    );
    expect(() => new SyntaxScopeMap(invalid[2])).toThrow(
      "Unsupported selector 'a > b:last-of-type'"
    );
    expect(() => new SyntaxScopeMap(invalid[3])).toThrow(
      "Unsupported selector 'a:nth-child(1):nth-child(2)'"
    );
  });
});
