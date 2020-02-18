import Remote, {nullRemote} from '../../lib/models/remote';

import Search from '../../lib/models/search';

describe('Search', function() {
  const origin = new Remote('origin', 'git@github.com:atom/github.git');

  it('generates a dotcom URL', function() {
    const s = new Search('foo', 'repo:smashwilson/remote-repo type:pr something with spaces');
    assert.strictEqual(
      s.getWebURL(origin),
      'https://github.com/search?q=repo%3Asmashwilson%2Fremote-repo%20type%3Apr%20something%20with%20spaces',
    );
  });

  it('throws an error when attempting to generate a dotcom URL from a non-dotcom remote', function() {
    const nonDotCom = new Remote('elsewhere', 'git://git.gnupg.org/gnupg.git');

    const s = new Search('zzz', 'type:pr is:open');
    assert.throws(() => s.getWebURL(nonDotCom), /non-GitHub remote/);
  });

  describe('when scoped to a remote', function() {
    it('is a null search when the remote is not present', function() {
      const s = Search.inRemote(nullRemote, 'name', 'query');
      assert.isTrue(s.isNull());
      assert.strictEqual(s.getName(), 'name');
    });

    it('prepends a repo: criteria to the search query', function() {
      const s = Search.inRemote(origin, 'name', 'query');
      assert.isFalse(s.isNull());
      assert.strictEqual(s.getName(), 'name');
      assert.strictEqual(s.createQuery(), 'repo:atom/github query');
    });

    it('uses a default empty list tile', function() {
      assert.isFalse(Search.inRemote(origin, 'name', 'query').showCreateOnEmpty());
    });
  });
});
