import dedent from 'dedent-js';

import UserStore, {source} from '../../lib/models/user-store';
import Author, {nullAuthor} from '../../lib/models/author';
import GithubLoginModel from '../../lib/models/github-login-model';
import {InMemoryStrategy, UNAUTHENTICATED} from '../../lib/shared/keytar-strategy';
import {expectRelayQuery} from '../../lib/relay-network-layer-manager';
import {cloneRepository, buildRepository, FAKE_USER} from '../helpers';

describe('UserStore', function() {
  let login, atomEnv, config, store;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    config = atomEnv.config;

    login = new GithubLoginModel(InMemoryStrategy);
    sinon.stub(login, 'getScopes').returns(Promise.resolve(GithubLoginModel.REQUIRED_SCOPES));
  });

  afterEach(function() {
    if (store) {
      store.dispose();
    }
    atomEnv.destroy();
  });

  function nextUpdatePromise() {
    return new Promise(resolve => {
      const sub = store.onDidUpdate(() => {
        sub.dispose();
        resolve();
      });
    });
  }

  function expectPagedRelayQueries(options, ...pages) {
    const opts = {
      owner: 'me',
      name: 'stuff',
      repositoryFound: true,
      ...options,
    };

    let lastCursor = null;
    return pages.map((page, index) => {
      const isLast = index === pages.length - 1;
      const nextCursor = isLast ? null : `page-${index + 1}`;

      const result = expectRelayQuery({
        name: 'GetMentionableUsers',
        variables: {owner: opts.owner, name: opts.name, first: 100, after: lastCursor},
      }, {
        repository: !opts.repositoryFound ? null : {
          mentionableUsers: {
            nodes: page,
            pageInfo: {
              hasNextPage: !isLast,
              endCursor: nextCursor,
            },
          },
        },
      });

      lastCursor = nextCursor;
      return result;
    });
  }

  async function commitAs(repository, ...accounts) {
    const committerName = await repository.getConfig('user.name');
    const committerEmail = await repository.getConfig('user.email');

    for (const {name, email} of accounts) {
      await repository.setConfig('user.name', name);
      await repository.setConfig('user.email', email);
      await repository.commit('message', {allowEmpty: true});
    }

    await repository.setConfig('user.name', committerName);
    await repository.setConfig('user.email', committerEmail);
  }

  it('loads store with local git users and committer in a repo with no GitHub remote', async function() {
    const workdirPath = await cloneRepository('multiple-commits');
    const repository = await buildRepository(workdirPath);
    store = new UserStore({repository, config});

    assert.deepEqual(store.getUsers(), []);
    assert.strictEqual(store.committer, nullAuthor);

    // Store is populated asynchronously
    await nextUpdatePromise();
    assert.deepEqual(store.getUsers(), [
      new Author('kuychaco@github.com', 'Katrina Uychaco'),
    ]);
    assert.deepEqual(store.committer, new Author(FAKE_USER.email, FAKE_USER.name));
  });

  it('falls back to local git users and committers if loadMentionableUsers cannot load any user for whatever reason', async function() {
    const workdirPath = await cloneRepository('multiple-commits');
    const repository = await buildRepository(workdirPath);

    store = new UserStore({repository, config});
    sinon.stub(store, 'loadMentionableUsers').returns(undefined);

    await store.loadUsers();
    await nextUpdatePromise();

    assert.deepEqual(store.getUsers(), [
      new Author('kuychaco@github.com', 'Katrina Uychaco'),
    ]);
  });

  it('loads store with mentionable users from the GitHub API in a repo with a GitHub remote', async function() {
    await login.setToken('https://api.github.com', '1234');

    const workdirPath = await cloneRepository('multiple-commits');
    const repository = await buildRepository(workdirPath);

    await repository.setConfig('remote.origin.url', 'git@github.com:me/stuff.git');
    await repository.setConfig('remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*');
    await repository.setConfig('remote.old.url', 'git@sourceforge.com:me/stuff.git');
    await repository.setConfig('remote.old.fetch', '+refs/heads/*:refs/remotes/old/*');

    const [{resolve}] = expectPagedRelayQueries({}, [
      {login: 'annthurium', email: 'annthurium@github.com', name: 'Tilde Ann Thurium'},
      {login: 'octocat', email: 'mona@lisa.com', name: 'Mona Lisa'},
      {login: 'smashwilson', email: 'smashwilson@github.com', name: 'Ash Wilson'},
    ]);

    store = new UserStore({repository, login, config});
    await nextUpdatePromise();

    resolve();
    await nextUpdatePromise();

    assert.deepEqual(store.getUsers(), [
      new Author('smashwilson@github.com', 'Ash Wilson', 'smashwilson'),
      new Author('mona@lisa.com', 'Mona Lisa', 'octocat'),
      new Author('annthurium@github.com', 'Tilde Ann Thurium', 'annthurium'),
    ]);
  });

  it('loads users from multiple pages from the GitHub API', async function() {
    await login.setToken('https://api.github.com', '1234');

    const workdirPath = await cloneRepository('multiple-commits');
    const repository = await buildRepository(workdirPath);

    await repository.setConfig('remote.origin.url', 'git@github.com:me/stuff.git');
    await repository.setConfig('remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*');

    const [{resolve: resolve0}, {resolve: resolve1}] = expectPagedRelayQueries({},
      [
        {login: 'annthurium', email: 'annthurium@github.com', name: 'Tilde Ann Thurium'},
        {login: 'octocat', email: 'mona@lisa.com', name: 'Mona Lisa'},
        {login: 'smashwilson', email: 'smashwilson@github.com', name: 'Ash Wilson'},
      ],
      [
        {login: 'zzz', email: 'zzz@github.com', name: 'Zzzzz'},
        {login: 'aaa', email: 'aaa@github.com', name: 'Aahhhhh'},
      ],
    );

    store = new UserStore({repository, login, config});

    await nextUpdatePromise();
    assert.deepEqual(store.getUsers(), []);

    resolve0();
    await nextUpdatePromise();

    assert.deepEqual(store.getUsers(), [
      new Author('smashwilson@github.com', 'Ash Wilson', 'smashwilson'),
      new Author('mona@lisa.com', 'Mona Lisa', 'octocat'),
      new Author('annthurium@github.com', 'Tilde Ann Thurium', 'annthurium'),
    ]);

    resolve1();
    await nextUpdatePromise();

    assert.deepEqual(store.getUsers(), [
      new Author('aaa@github.com', 'Aahhhhh', 'aaa'),
      new Author('smashwilson@github.com', 'Ash Wilson', 'smashwilson'),
      new Author('mona@lisa.com', 'Mona Lisa', 'octocat'),
      new Author('annthurium@github.com', 'Tilde Ann Thurium', 'annthurium'),
      new Author('zzz@github.com', 'Zzzzz', 'zzz'),
    ]);
  });

  it('skips GitHub remotes that no longer exist', async function() {
    await login.setToken('https://api.github.com', '1234');

    const workdirPath = await cloneRepository('multiple-commits');
    const repository = await buildRepository(workdirPath);

    await repository.setConfig('remote.origin.url', 'git@github.com:me/stuff.git');
    await repository.setConfig('remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*');

    const [{resolve, promise}] = expectPagedRelayQueries({repositoryFound: false}, []);

    store = new UserStore({repository, login, config});
    await nextUpdatePromise();

    resolve();
    // nextUpdatePromise will not fire because the update is empty
    await promise;

    assert.deepEqual(store.getUsers(), []);
  });

  it('infers no-reply emails for users without a public email address', async function() {
    await login.setToken('https://api.github.com', '1234');

    const workdirPath = await cloneRepository('multiple-commits');
    const repository = await buildRepository(workdirPath);

    await repository.setConfig('remote.origin.url', 'git@github.com:me/stuff.git');
    await repository.setConfig('remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*');

    const [{resolve}] = expectPagedRelayQueries({}, [
      {login: 'simurai', email: '', name: 'simurai'},
    ]);

    store = new UserStore({repository, login, config});
    await nextUpdatePromise();

    resolve();
    await nextUpdatePromise();

    assert.deepEqual(store.getUsers(), [
      new Author('simurai@users.noreply.github.com', 'simurai', 'simurai'),
    ]);
  });

  it('excludes committer and no reply user from `getUsers`', async function() {
    const workdirPath = await cloneRepository('multiple-commits');
    const repository = await buildRepository(workdirPath);
    store = new UserStore({repository, config});
    sinon.spy(store, 'addUsers');
    await assert.async.lengthOf(store.getUsers(), 1);
    await assert.async.equal(store.addUsers.callCount, 1);

    // make a commit with FAKE_USER as committer
    await repository.commit('made a new commit', {allowEmpty: true});

    // verify that FAKE_USER is in commit history
    const lastCommit = await repository.getLastCommit();
    assert.strictEqual(lastCommit.getAuthorEmail(), FAKE_USER.email);

    // verify that FAKE_USER is not in users returned from `getUsers`
    const users = store.getUsers();
    assert.isFalse(users.some(user => user.getEmail() === FAKE_USER.email));

    // verify that no-reply email address is not in users array
    assert.isFalse(users.some(user => user.isNoReply()));
  });

  describe('addUsers', function() {
    it('adds specified users and does not overwrite existing users', async function() {
      const workdirPath = await cloneRepository('multiple-commits');
      const repository = await buildRepository(workdirPath);
      store = new UserStore({repository, config});
      await nextUpdatePromise();

      assert.lengthOf(store.getUsers(), 1);

      store.addUsers([
        new Author('mona@lisa.com', 'Mona Lisa'),
        new Author('hubot@github.com', 'Hubot Robot'),
      ], source.GITLOG);

      assert.deepEqual(store.getUsers(), [
        new Author('hubot@github.com', 'Hubot Robot'),
        new Author('kuychaco@github.com', 'Katrina Uychaco'),
        new Author('mona@lisa.com', 'Mona Lisa'),
      ]);
    });
  });

  it('refetches committer when config changes', async function() {
    const workdirPath = await cloneRepository('multiple-commits');
    const repository = await buildRepository(workdirPath);

    store = new UserStore({repository, config});
    await nextUpdatePromise();
    assert.deepEqual(store.committer, new Author(FAKE_USER.email, FAKE_USER.name));

    const newEmail = 'foo@bar.com';
    const newName = 'Foo Bar';

    await repository.setConfig('user.email', newEmail);
    await repository.setConfig('user.name', newName);
    repository.refresh();
    await nextUpdatePromise();

    assert.deepEqual(store.committer, new Author(newEmail, newName));
  });

  it('refetches users when HEAD changes', async function() {
    const workdirPath = await cloneRepository('multiple-commits');
    const repository = await buildRepository(workdirPath);
    await repository.checkout('new-branch', {createNew: true});
    await repository.commit('commit 1', {allowEmpty: true});
    await repository.commit('commit 2', {allowEmpty: true});
    await repository.checkout('master');

    store = new UserStore({repository, config});
    await nextUpdatePromise();
    assert.deepEqual(store.getUsers(), [
      new Author('kuychaco@github.com', 'Katrina Uychaco'),
    ]);

    sinon.spy(store, 'addUsers');

    // Head changes due to new commit
    await repository.commit(dedent`
      New commit

      Co-authored-by: New Author <new-author@email.com>
    `, {allowEmpty: true});

    repository.refresh();
    await nextUpdatePromise();

    await assert.strictEqual(store.addUsers.callCount, 1);
    assert.isTrue(store.getUsers().some(user => {
      return user.getFullName() === 'New Author' && user.getEmail() === 'new-author@email.com';
    }));

    // Change head due to branch checkout
    await repository.checkout('new-branch');
    repository.refresh();

    await assert.async.strictEqual(store.addUsers.callCount, 2);
  });

  it('refetches users when a token becomes available', async function() {
    const workdirPath = await cloneRepository('multiple-commits');
    const repository = await buildRepository(workdirPath);

    const gitAuthors = [
      new Author('kuychaco@github.com', 'Katrina Uychaco'),
    ];

    const graphqlAuthors = [
      new Author('smashwilson@github.com', 'Ash Wilson', 'smashwilson'),
      new Author('mona@lisa.com', 'Mona Lisa', 'octocat'),
      new Author('annthurium@github.com', 'Tilde Ann Thurium', 'annthurium'),
    ];

    const [{resolve}] = expectPagedRelayQueries({}, [
      {login: 'annthurium', email: 'annthurium@github.com', name: 'Tilde Ann Thurium'},
      {login: 'octocat', email: 'mona@lisa.com', name: 'Mona Lisa'},
      {login: 'smashwilson', email: 'smashwilson@github.com', name: 'Ash Wilson'},
    ]);
    resolve();

    store = new UserStore({repository, login, config});
    await nextUpdatePromise();

    assert.deepEqual(store.getUsers(), gitAuthors);

    await repository.setConfig('remote.origin.url', 'git@github.com:me/stuff.git');
    await repository.setConfig('remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*');

    repository.refresh();

    // Token is not available, so authors are still queried from git
    assert.deepEqual(store.getUsers(), gitAuthors);

    await login.setToken('https://api.github.com', '1234');

    await nextUpdatePromise();
    assert.deepEqual(store.getUsers(), graphqlAuthors);
  });

  it('refetches users when the repository changes', async function() {
    const workdirPath0 = await cloneRepository('multiple-commits');
    const repository0 = await buildRepository(workdirPath0);
    await commitAs(repository0, {name: 'committer0', email: 'committer0@github.com'});

    const workdirPath1 = await cloneRepository('multiple-commits');
    const repository1 = await buildRepository(workdirPath1);
    await commitAs(repository1, {name: 'committer1', email: 'committer1@github.com'});

    store = new UserStore({repository: repository0, config});
    await nextUpdatePromise();

    assert.deepEqual(store.getUsers(), [
      new Author('kuychaco@github.com', 'Katrina Uychaco'),
      new Author('committer0@github.com', 'committer0'),
    ]);

    store.setRepository(repository1);
    await nextUpdatePromise();

    assert.deepEqual(store.getUsers(), [
      new Author('kuychaco@github.com', 'Katrina Uychaco'),
      new Author('committer1@github.com', 'committer1'),
    ]);
  });

  describe('getToken', function() {
    let repository, workdirPath;
    beforeEach(async function() {
      workdirPath = await cloneRepository('multiple-commits');
      repository = await buildRepository(workdirPath);
    });
    it('returns null if loginModel is falsy', async function() {
      store = new UserStore({repository, login, config});
      const token = await store.getToken(undefined, 'https://api.github.com');
      assert.isNull(token);
    });

    it('returns null if token is INSUFFICIENT', async function() {
      const loginModel = new GithubLoginModel(InMemoryStrategy);
      sinon.stub(loginModel, 'getScopes').returns(Promise.resolve(['repo', 'read:org']));

      await loginModel.setToken('https://api.github.com', '1234');
      store = new UserStore({repository, loginModel, config});
      const token = await store.getToken(loginModel, 'https://api.github.com');
      assert.isNull(token);
    });

    it('returns null if token is UNAUTHENTICATED', async function() {
      const loginModel = new GithubLoginModel(InMemoryStrategy);
      sinon.stub(loginModel, 'getToken').returns(Promise.resolve(UNAUTHENTICATED));

      store = new UserStore({repository, loginModel, config});
      const getToken = await store.getToken(loginModel, 'https://api.github.com');
      assert.isNull(getToken);
    });

    it('returns null if network is offline', async function() {
      const loginModel = new GithubLoginModel(InMemoryStrategy);
      const e = new Error('eh');
      sinon.stub(loginModel, 'getToken').returns(Promise.resolve(e));

      store = new UserStore({repository, loginModel, config});
      const getToken = await store.getToken(loginModel, 'https://api.github.com');
      assert.isNull(getToken);
    });

    it('return token if token is sufficient and model is truthy', async function() {
      const loginModel = new GithubLoginModel(InMemoryStrategy);
      sinon.stub(loginModel, 'getScopes').returns(Promise.resolve(['repo', 'read:org', 'user:email']));

      const expectedToken = '1234';
      await loginModel.setToken('https://api.github.com', expectedToken);
      store = new UserStore({repository, loginModel, config});
      const actualToken = await store.getToken(loginModel, 'https://api.github.com');
      assert.strictEqual(expectedToken, actualToken);
    });
  });

  describe('loadMentionableUsers', function() {
    it('returns undefined if token is null', async function() {
      const workdirPath = await cloneRepository('multiple-commits');
      const repository = await buildRepository(workdirPath);

      await repository.setConfig('remote.origin.url', 'git@github.com:me/stuff.git');

      store = new UserStore({repository, login, config});
      sinon.stub(store, 'getToken').returns(null);

      const remoteSet = await repository.getRemotes();
      const remote = remoteSet.byDotcomRepo.get('me/stuff')[0];

      const users = await store.loadMentionableUsers(remote);
      assert.notOk(users);
    });
  });

  describe('GraphQL response caching', function() {
    it('caches mentionable users acquired from GraphQL', async function() {
      await login.setToken('https://api.github.com', '1234');

      const workdirPath = await cloneRepository('multiple-commits');
      const repository = await buildRepository(workdirPath);

      await repository.setConfig('remote.origin.url', 'git@github.com:me/stuff.git');
      await repository.setConfig('remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*');

      const [{resolve, disable}] = expectPagedRelayQueries({}, [
        {login: 'annthurium', email: 'annthurium@github.com', name: 'Tilde Ann Thurium'},
        {login: 'octocat', email: 'mona@lisa.com', name: 'Mona Lisa'},
        {login: 'smashwilson', email: 'smashwilson@github.com', name: 'Ash Wilson'},
      ]);
      resolve();

      store = new UserStore({repository, login, config});
      sinon.spy(store, 'loadUsers');
      sinon.spy(store, 'getToken');

      // The first update is triggered by the committer, the second from GraphQL results arriving.
      await nextUpdatePromise();
      await nextUpdatePromise();

      disable();

      repository.refresh();

      await assert.async.strictEqual(store.loadUsers.callCount, 2);
      await store.loadUsers.returnValues[1];

      await assert.async.strictEqual(store.getToken.callCount, 1);

      assert.deepEqual(store.getUsers(), [
        new Author('smashwilson@github.com', 'Ash Wilson', 'smashwilson'),
        new Author('mona@lisa.com', 'Mona Lisa', 'octocat'),
        new Author('annthurium@github.com', 'Tilde Ann Thurium', 'annthurium'),
      ]);
    });

    it('re-uses cached users per repository', async function() {
      await login.setToken('https://api.github.com', '1234');

      const workdirPath0 = await cloneRepository('multiple-commits');
      const repository0 = await buildRepository(workdirPath0);
      await repository0.setConfig('remote.origin.url', 'git@github.com:me/zero.git');
      await repository0.setConfig('remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*');

      const workdirPath1 = await cloneRepository('multiple-commits');
      const repository1 = await buildRepository(workdirPath1);
      await repository1.setConfig('remote.origin.url', 'git@github.com:me/one.git');
      await repository1.setConfig('remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*');

      const results = id => [
        {login: 'aaa', email: `aaa-${id}@a.com`, name: 'AAA'},
        {login: 'bbb', email: `bbb-${id}@b.com`, name: 'BBB'},
        {login: 'ccc', email: `ccc-${id}@c.com`, name: 'CCC'},
      ];
      const [{resolve: resolve0, disable: disable0}] = expectPagedRelayQueries({name: 'zero'}, results('0'));
      const [{resolve: resolve1, disable: disable1}] = expectPagedRelayQueries({name: 'one'}, results('1'));
      resolve0();
      resolve1();

      store = new UserStore({repository: repository0, login, config});
      await nextUpdatePromise();
      await nextUpdatePromise();

      store.setRepository(repository1);
      await nextUpdatePromise();

      sinon.spy(store, 'loadUsers');
      disable0();
      disable1();

      store.setRepository(repository0);
      await nextUpdatePromise();

      assert.deepEqual(store.getUsers(), [
        new Author('aaa-0@a.com', 'AAA', 'aaa'),
        new Author('bbb-0@b.com', 'BBB', 'bbb'),
        new Author('ccc-0@c.com', 'CCC', 'ccc'),
      ]);
    });
  });

  describe('excluded users', function() {
    it('do not appear in the list from git', async function() {
      config.set('github.excludedUsers', 'evil@evilcorp.org');

      const workdirPath = await cloneRepository('multiple-commits');
      const repository = await buildRepository(workdirPath);
      await commitAs(repository,
        {name: 'evil0', email: 'evil@evilcorp.org'},
        {name: 'ok', email: 'ok@somewhere.net'},
        {name: 'evil1', email: 'evil@evilcorp.org'},
      );

      store = new UserStore({repository, config});
      await nextUpdatePromise();

      assert.deepEqual(store.getUsers(), [
        new Author('kuychaco@github.com', 'Katrina Uychaco'),
        new Author('ok@somewhere.net', 'ok'),
      ]);
    });

    it('do not appear in the list from GraphQL', async function() {
      config.set('github.excludedUsers', 'evil@evilcorp.org, other@evilcorp.org');
      await login.setToken('https://api.github.com', '1234');

      const workdirPath = await cloneRepository('multiple-commits');
      const repository = await buildRepository(workdirPath);
      await repository.setConfig('remote.origin.url', 'git@github.com:me/stuff.git');
      await repository.setConfig('remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*');

      const [{resolve}] = expectPagedRelayQueries({}, [
        {login: 'evil0', email: 'evil@evilcorp.org', name: 'evil0'},
        {login: 'octocat', email: 'mona@lisa.com', name: 'Mona Lisa'},
      ]);
      resolve();

      store = new UserStore({repository, login, config});
      await nextUpdatePromise();
      await nextUpdatePromise();

      assert.deepEqual(store.getUsers(), [
        new Author('mona@lisa.com', 'Mona Lisa', 'octocat'),
      ]);
    });

    it('are updated when the config option changes', async function() {
      config.set('github.excludedUsers', 'evil0@evilcorp.org');

      const workdirPath = await cloneRepository('multiple-commits');
      const repository = await buildRepository(workdirPath);
      await commitAs(repository,
        {name: 'evil0', email: 'evil0@evilcorp.org'},
        {name: 'ok', email: 'ok@somewhere.net'},
        {name: 'evil1', email: 'evil1@evilcorp.org'},
      );

      store = new UserStore({repository, config});
      await nextUpdatePromise();

      assert.deepEqual(store.getUsers(), [
        new Author('kuychaco@github.com', 'Katrina Uychaco'),
        new Author('evil1@evilcorp.org', 'evil1'),
        new Author('ok@somewhere.net', 'ok'),
      ]);

      config.set('github.excludedUsers', 'evil0@evilcorp.org, evil1@evilcorp.org');

      assert.deepEqual(store.getUsers(), [
        new Author('kuychaco@github.com', 'Katrina Uychaco'),
        new Author('ok@somewhere.net', 'ok'),
      ]);
    });
  });
});
