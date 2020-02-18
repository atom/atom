import GithubLoginModel from '../../lib/models/github-login-model';
import {
  KeytarStrategy,
  SecurityBinaryStrategy,
  InMemoryStrategy,
  UNAUTHENTICATED,
  INSUFFICIENT,
  UNAUTHORIZED,
} from '../../lib/shared/keytar-strategy';

describe('GithubLoginModel', function() {
  [null, KeytarStrategy, SecurityBinaryStrategy, InMemoryStrategy].forEach(function(Strategy) {
    describe((Strategy && Strategy.name) || 'default strategy', function() {
      // NOTE: This test does not pass on VSTS macOS builds.  It will be re-enabled
      // once the underlying problem is solved.  See atom/github#1568 for details.
      if (process.env.CI_PROVIDER === 'VSTS') { return; }

      // NOTE: Native modules, including keytar, are not currently building correctly on
      // AppVeyor. Re-enable these once the underlying problem is solved.
      if (process.env.APPVEYOR === 'True') { return; }

      it('manages passwords', async function() {
        if (!Strategy || await Strategy.isValid()) {
          const loginModel = new GithubLoginModel(Strategy);
          const callback = sinon.stub();
          loginModel.onDidUpdate(callback);
          const TOKEN = 'TOKEN';

          await loginModel.setToken('test-account', TOKEN);
          assert.equal(callback.callCount, 1);
          assert.equal(await loginModel.getToken('test-account'), TOKEN);
          await loginModel.removeToken('test-account');
          assert.equal(await loginModel.getToken('test-account'), UNAUTHENTICATED);
        } else {
          // eslint-disable-next-line no-console
          console.warn(`Skipping tests for ${Strategy.name} as they are not supported on this platform (or maybe your Atom is unsigned?)`);
        }
      });
    });
  });

  describe('required OAuth scopes', function() {
    let loginModel;

    beforeEach(async function() {
      loginModel = new GithubLoginModel(InMemoryStrategy);
      await loginModel.setToken('https://api.github.com', '1234');
    });

    it('returns INSUFFICIENT if scopes are present', async function() {
      sinon.stub(loginModel, 'getScopes').resolves(['repo', 'read:org']);

      assert.strictEqual(await loginModel.getToken('https://api.github.com'), INSUFFICIENT);
    });

    it('returns the token if at least the required scopes are present', async function() {
      sinon.stub(loginModel, 'getScopes').resolves(['repo', 'read:org', 'user:email', 'extra']);

      assert.strictEqual(await loginModel.getToken('https://api.github.com'), '1234');
    });

    it('caches checked tokens', async function() {
      sinon.stub(loginModel, 'getScopes').resolves(['repo', 'read:org', 'user:email']);

      assert.strictEqual(await loginModel.getToken('https://api.github.com'), '1234');
      assert.strictEqual(loginModel.getScopes.callCount, 1);

      assert.strictEqual(await loginModel.getToken('https://api.github.com'), '1234');
      assert.strictEqual(loginModel.getScopes.callCount, 1);
    });

    it('caches tokens that failed to authenticate correctly', async function() {
      sinon.stub(loginModel, 'getScopes').resolves(UNAUTHORIZED);

      assert.strictEqual(await loginModel.getToken('https://api.github.com'), UNAUTHENTICATED);
      assert.strictEqual(loginModel.getScopes.callCount, 1);

      assert.strictEqual(await loginModel.getToken('https://api.github.com'), UNAUTHENTICATED);
      assert.strictEqual(loginModel.getScopes.callCount, 1);
    });

    it('caches tokens that had insufficient scopes', async function() {
      sinon.stub(loginModel, 'getScopes').resolves(['repo', 'read:org']);

      assert.strictEqual(await loginModel.getToken('https://api.github.com'), INSUFFICIENT);
      assert.strictEqual(loginModel.getScopes.callCount, 1);

      assert.strictEqual(await loginModel.getToken('https://api.github.com'), INSUFFICIENT);
      assert.strictEqual(loginModel.getScopes.callCount, 1);
    });

    it('detects and reports network errors', async function() {
      const e = new Error('You unplugged your ethernet cable');
      sinon.stub(loginModel, 'getScopes').rejects(e);
      assert.strictEqual(await loginModel.getToken('https://api.github.com'), e);
    });

    it('does not cache network errors', async function() {
      const e = new Error('You unplugged your ethernet cable');
      sinon.stub(loginModel, 'getScopes').rejects(e);

      assert.strictEqual(await loginModel.getToken('https://api.github.com'), e);
      assert.strictEqual(loginModel.getScopes.callCount, 1);

      assert.strictEqual(await loginModel.getToken('https://api.github.com'), e);
      assert.strictEqual(loginModel.getScopes.callCount, 2);
    });
  });
});
