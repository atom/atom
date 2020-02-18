import Remote, {nullRemote} from '../../lib/models/remote';

describe('Remote', function() {
  it('detects and extracts information from GitHub repository URLs', function() {
    const urls = [
      ['git@github.com:atom/github.git', 'ssh'],
      ['git@github.com:/atom/github.git', 'ssh'],
      ['https://github.com/atom/github.git', 'https'],
      ['https://git:pass@github.com/atom/github.git', 'https'],
      ['ssh+https://github.com/atom/github.git', 'ssh+https'],
      ['git://github.com/atom/github', 'git'],
      ['ssh://git@github.com:atom/github.git', 'ssh'],
      ['ssh://git@github.com:/atom/github.git', 'ssh'],
    ];

    for (const [url, proto] of urls) {
      const remote = new Remote('origin', url);

      assert.isTrue(remote.isPresent());
      assert.strictEqual(remote.getName(), 'origin');
      assert.strictEqual(remote.getNameOr('else'), 'origin');
      assert.strictEqual(remote.getUrl(), url);
      assert.isTrue(remote.isGithubRepo());
      assert.strictEqual(remote.getDomain(), 'github.com');
      assert.strictEqual(remote.getProtocol(), proto);
      assert.strictEqual(remote.getOwner(), 'atom');
      assert.strictEqual(remote.getRepo(), 'github');
      assert.strictEqual(remote.getSlug(), 'atom/github');
    }
  });

  it('detects non-GitHub remotes', function() {
    const urls = [
      'git@gitlab.com:atom/github.git',
      'atom/github',
    ];

    for (const url of urls) {
      const remote = new Remote('origin', url);

      assert.isTrue(remote.isPresent());
      assert.strictEqual(remote.getName(), 'origin');
      assert.strictEqual(remote.getNameOr('else'), 'origin');
      assert.strictEqual(remote.getUrl(), url);
      assert.isFalse(remote.isGithubRepo());
      assert.isNull(remote.getDomain());
      assert.isNull(remote.getOwner());
      assert.isNull(remote.getRepo());
      assert.isNull(remote.getSlug());
    }
  });

  it('may be created without a URL', function() {
    const remote = new Remote('origin');

    assert.isTrue(remote.isPresent());
    assert.strictEqual(remote.getName(), 'origin');
    assert.strictEqual(remote.getNameOr('else'), 'origin');
    assert.isUndefined(remote.getUrl());
    assert.isFalse(remote.isGithubRepo());
    assert.isNull(remote.getDomain());
    assert.isNull(remote.getOwner());
    assert.isNull(remote.getRepo());
    assert.isNull(remote.getSlug());
  });

  it('has a corresponding null object', function() {
    assert.isFalse(nullRemote.isPresent());
    assert.strictEqual(nullRemote.getName(), '');
    assert.strictEqual(nullRemote.getUrl(), '');
    assert.isFalse(nullRemote.isGithubRepo());
    assert.isNull(nullRemote.getDomain());
    assert.isNull(nullRemote.getProtocol());
    assert.isNull(nullRemote.getOwner());
    assert.isNull(nullRemote.getRepo());
    assert.isNull(nullRemote.getSlug());
    assert.strictEqual(nullRemote.getNameOr('else'), 'else');
    assert.isNull(nullRemote.getEndpoint());
  });

  describe('getEndpoint', function() {
    it('accesses an Endpoint for the corresponding GitHub host', function() {
      const remote = new Remote('origin', 'git@github.com:atom/github.git');
      assert.strictEqual(remote.getEndpoint().getGraphQLRoot(), 'https://api.github.com/graphql');
    });

    it('returns null for non-GitHub URLs', function() {
      const elsewhere = new Remote('mirror', 'https://me@bitbucket.org/team/repo.git');
      assert.isNull(elsewhere.getEndpoint());
    });
  });
});
