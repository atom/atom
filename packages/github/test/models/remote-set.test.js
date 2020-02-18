import RemoteSet from '../../lib/models/remote-set';
import Remote from '../../lib/models/remote';

describe('RemoteSet', function() {
  const remotes = [
    new Remote('origin', 'git@github.com:origin/repo.git'),
    new Remote('upstream', 'git@github.com:upstream/repo.git'),
  ];

  it('creates an empty set', function() {
    const set = new RemoteSet();
    assert.isTrue(set.isEmpty());
    assert.strictEqual(set.size(), 0);
  });

  it('creates a set containing one or more Remotes', function() {
    const set = new RemoteSet(remotes);
    assert.isFalse(set.isEmpty());
    assert.strictEqual(set.size(), 2);
  });

  it('retrieves a Remote from the set by name', function() {
    const set = new RemoteSet(remotes);
    const remote = set.withName('upstream');
    assert.strictEqual(remote, remotes[1]);
  });

  it('returns a nullRemote for unknown remote names', function() {
    const set = new RemoteSet(remotes);
    const remote = set.withName('unknown');
    assert.isFalse(remote.isPresent());
  });

  it('iterates over the Remotes', function() {
    const set = new RemoteSet(remotes);
    assert.deepEqual(Array.from(set), remotes);
  });

  it('filters remotes by a predicate', function() {
    const set0 = new RemoteSet(remotes);
    const set1 = set0.filter(remote => remote.getName() === 'upstream');

    assert.notStrictEqual(set0, set1);
    assert.isTrue(set1.withName('upstream').isPresent());
    assert.isFalse(set1.withName('origin1').isPresent());
  });

  it('identifies all remotes that correspond to a GitHub repository', function() {
    const set = new RemoteSet([
      new Remote('no0', 'git@github.com:aaa/bbb.git'),
      new Remote('yes1', 'git@github.com:xxx/yyy.git'),
      new Remote('yes2', 'https://github.com/xxx/yyy.git'),
      new Remote('no3', 'git@github.com:aaa/yyy.git'),
      new Remote('no4', 'git@elsewhere.com:nnn/qqq.git'),
    ]);

    const chosen = set.matchingGitHubRepository('xxx', 'yyy');
    assert.sameMembers(chosen.map(remote => remote.getName()), ['yes1', 'yes2']);

    assert.lengthOf(set.matchingGitHubRepository('no', 'no'), 0);
  });

  describe('the most-used protocol', function() {
    it('defaults to the first option if no remotes are present', function() {
      assert.strictEqual(new RemoteSet().mostUsedProtocol(['https', 'ssh']), 'https');
      assert.strictEqual(new RemoteSet().mostUsedProtocol(['ssh', 'https']), 'ssh');
    });

    it('returns the most frequently occurring protocol', function() {
      const set = new RemoteSet([
        new Remote('one', 'https://github.com/aaa/bbb.git'),
        new Remote('two', 'https://github.com/aaa/ccc.git'),
        new Remote('four', 'git@github.com:aaa/bbb.git'),
        new Remote('five', 'git@github.com:ddd/zzz.git'),
        new Remote('six', 'ssh://git@github.com:aaa/bbb.git'),
      ]);
      assert.strictEqual(set.mostUsedProtocol(['https', 'ssh']), 'ssh');
    });

    it('ignores protocols not in the provided set', function() {
      const set = new RemoteSet([
        new Remote('one', 'http://github.com/aaa/bbb.git'),
        new Remote('two', 'http://github.com/aaa/ccc.git'),
        new Remote('three', 'git@github.com:aaa/bbb.git'),
        new Remote('four', 'git://github.com:aaa/bbb.git'),
        new Remote('five', 'git://github.com:ccc/ddd.git'),
      ]);
      assert.strictEqual(set.mostUsedProtocol(['https', 'ssh']), 'ssh');
    });
  });
});
