import URIPattern from '../../lib/atom/uri-pattern';

describe('URIPattern', function() {
  describe('exact', function() {
    let exact;

    beforeEach(function() {
      exact = new URIPattern('atom-github://exact/match');
    });

    it('matches exact URIs', function() {
      assert.isTrue(exact.matches('atom-github://exact/match').ok());
      assert.isTrue(exact.matches('atom-github://exact/match/').ok());
    });

    it('does not match any other URIs', function() {
      assert.isFalse(exact.matches('atom-github://exactbutnot').ok());
      assert.isFalse(exact.matches('atom-github://exact').ok());
      assert.isFalse(exact.matches('https://exact').ok());
      assert.isFalse(exact.matches('atom-github://exact/but/not').ok());
      assert.isFalse(exact.matches('atom-github://exact/match?no=no').ok());
    });

    it('does not match undefined or null', function() {
      assert.isFalse(exact.matches(undefined).ok());
      assert.isFalse(exact.matches(null).ok());
    });

    it('matches username and password', function() {
      const pattern = new URIPattern('proto://user:pass@host/some/path');
      assert.isTrue(pattern.matches('proto://user:pass@host/some/path').ok());
      assert.isFalse(pattern.matches('proto://other:pass@host/some/path').ok());
      assert.isFalse(pattern.matches('proto://user:wrong@host/some/path').ok());
    });

    it('matches a hash', function() {
      const pattern = new URIPattern('proto://host/foo#exact');
      assert.isTrue(pattern.matches('proto://host/foo#exact').ok());
      assert.isFalse(pattern.matches('proto://host/foo#nope').ok());
    });

    it('escapes and unescapes dashes', function() {
      assert.isTrue(
        new URIPattern('atom-github://with-many-dashes')
          .matches('atom-github://with-many-dashes')
          .ok(),
      );
    });
  });

  describe('parameter placeholders', function() {
    it('matches a protocol placeholder', function() {
      const pattern = new URIPattern('{proto}://host/some/path');

      const m = pattern.matches('something://host/some/path');
      assert.isTrue(m.ok());
      assert.deepEqual(m.getParams(), {proto: 'something'});
    });

    it('matches an auth username placeholder', function() {
      const pattern = new URIPattern('proto://{user}@host/some/path');

      const m = pattern.matches('proto://me@host/some/path');
      assert.isTrue(m.ok());
      assert.deepEqual(m.getParams(), {user: 'me'});
    });

    it('matches an auth password placeholder', function() {
      const pattern = new URIPattern('proto://me:{password}@host/some/path');

      const m = pattern.matches('proto://me:swordfish@host/some/path');
      assert.isTrue(m.ok());
      assert.deepEqual(m.getParams(), {password: 'swordfish'});
    });

    it('matches a hostname placeholder', function() {
      const pattern = new URIPattern('proto://{host}/some/path');

      const m = pattern.matches('proto://somewhere.com/some/path');
      assert.isTrue(m.ok());
      assert.deepEqual(m.getParams(), {host: 'somewhere.com'});
    });

    it('matches each path placeholder to one path segment', function() {
      const pattern = new URIPattern('atom-github://base/exact/{id}');

      const m0 = pattern.matches('atom-github://base/exact/0');
      assert.isTrue(m0.ok());
      assert.deepEqual(m0.getParams(), {id: '0'});

      const m1 = pattern.matches('atom-github://base/exact/1');
      assert.isTrue(m1.ok());
      assert.deepEqual(m1.getParams(), {id: '1'});

      assert.isFalse(pattern.matches('atom-github://base/exact/0/more').ok());
    });

    it('does not match if the expected path segment is absent', function() {
      const pattern = new URIPattern('atom-github://base/exact/{id}');
      assert.isFalse(pattern.matches('atom-github://base/exact/').ok());
    });

    it('matches multiple path segments with a splat', function() {
      const pattern = new URIPattern('proto://host/root/{rest...}');

      const m0 = pattern.matches('proto://host/root');
      assert.isTrue(m0.ok());
      assert.deepEqual(m0.getParams(), {rest: []});

      const m1 = pattern.matches('proto://host/root/a');
      assert.isTrue(m1.ok());
      assert.deepEqual(m1.getParams(), {rest: ['a']});

      const m2 = pattern.matches('proto://host/root/a/b/c');
      assert.isTrue(m2.ok());
      assert.deepEqual(m2.getParams(), {rest: ['a', 'b', 'c']});
    });

    it('matches a query string placeholder', function() {
      const pattern = new URIPattern('proto://host?p0={zero}&p1={one}');

      const m0 = pattern.matches('proto://host?p0=aaa&p1=bbb');
      assert.isTrue(m0.ok());
      assert.deepEqual(m0.getParams(), {zero: 'aaa', one: 'bbb'});

      const m1 = pattern.matches('proto://host?p1=no&p0=yes');
      assert.isTrue(m1.ok());
      assert.deepEqual(m1.getParams(), {zero: 'yes', one: 'no'});

      const m2 = pattern.matches('proto://host?p0=&p1=');
      assert.isTrue(m2.ok());
      assert.deepEqual(m2.getParams(), {zero: '', one: ''});

      assert.isFalse(pattern.matches('proto://host?p0=no').ok());
    });

    it('does not match a single query string parameter against multiple occurrences', function() {
      const pattern = new URIPattern('proto://host?p={single}');
      assert.isFalse(pattern.matches('proto://host?p=0&p=1&p=2').ok());
    });

    it('matches multiple query string parameters with a splat', function() {
      const pattern = new URIPattern('proto://host?ps={multi...}');

      const m0 = pattern.matches('proto://host');
      assert.isTrue(m0.ok());
      assert.deepEqual(m0.getParams(), {multi: []});

      const m1 = pattern.matches('proto://host?ps=0');
      assert.isTrue(m1.ok());
      assert.deepEqual(m1.getParams(), {multi: ['0']});

      const m2 = pattern.matches('proto://host?ps=0&ps=1&ps=2');
      assert.isTrue(m2.ok());
      assert.deepEqual(m2.getParams(), {multi: ['0', '1', '2']});
    });

    it('captures a hash', function() {
      const pattern = new URIPattern('proto://host/root#{hash}');
      const m = pattern.matches('proto://host/root#value');

      assert.isTrue(m.ok());
      assert.deepEqual(m.getParams(), {hash: 'value'});
    });

    it('URI-decodes matched parameters', function() {
      const pattern = new URIPattern('proto://host/root/{child}?q={search}');
      const m = pattern.matches('proto://host/root/hooray%3E%20for%3C%20encodings?q=%3F%26%3F!');

      assert.isTrue(m.ok());
      assert.deepEqual(m.getParams(), {child: 'hooray> for< encodings', search: '?&?!'});
    });

    it('ignores the value of an empty capture', function() {
      const pattern = new URIPattern('proto://host/root/{}?q={}#{}');
      const m = pattern.matches('proto://host/root/anything?q=at#all');

      assert.isTrue(m.ok());
      assert.deepEqual(m.getParams(), {});
    });
  });

  it('prints itself as a string for debugging', function() {
    assert.strictEqual(
      new URIPattern('proto://host/exact').toString(),
      '<URIPattern proto://host/exact>',
    );
    assert.strictEqual(
      new URIPattern('proto://host/{param}?q={value}').toString(),
      '<URIPattern proto://host/{param}?q={value}>',
    );
  });

  describe('match objects', function() {
    it('prints itself as a string for debugging', function() {
      const pattern = new URIPattern('proto://host/exact');
      const m = pattern.matches('proto://host/exact');
      assert.strictEqual(m.toString(), '<URIMatch ok>');
    });

    it('prints captured values', function() {
      const pattern = new URIPattern('proto://host/{capture0}/{capture1}');
      const m = pattern.matches('proto://host/first/and%20escaped');
      assert.strictEqual(m.toString(), '<URIMatch ok capture0="first" capture1="and escaped">');
    });

    it('remembers the matched URI', function() {
      const pattern = new URIPattern('proto://host/{capture0}/{capture1}');
      const m = pattern.matches('proto://host/first/and%20escaped');
      assert.strictEqual(m.getURI(), 'proto://host/first/and%20escaped');
    });

    it('behaves like a nonURIMatch', function() {
      const pattern = new URIPattern('proto://yes');
      const m = pattern.matches('proto://no');
      assert.isFalse(m.ok());
      assert.isUndefined(m.getURI());
      assert.deepEqual(m.getParams(), {});
      assert.strictEqual(m.toString(), '<nonURIMatch>');
    });
  });
});
