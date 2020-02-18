import React from 'react';
import {shallow} from 'enzyme';
import fs from 'fs-extra';
import temp from 'temp';

import CreateDialog, {createRepository, publishRepository} from '../../lib/views/create-dialog';
import CreateDialogContainer from '../../lib/containers/create-dialog-container';
import {dialogRequests} from '../../lib/controllers/dialogs-controller';
import {InMemoryStrategy} from '../../lib/shared/keytar-strategy';
import GithubLoginModel from '../../lib/models/github-login-model';
import RelayNetworkLayerManager, {expectRelayQuery} from '../../lib/relay-network-layer-manager';
import {getEndpoint} from '../../lib/models/endpoint';
import {relayResponseBuilder} from '../builder/graphql/query';
import {cloneRepository, buildRepository} from '../helpers';

import createRepositoryQuery from '../../lib/mutations/__generated__/createRepositoryMutation.graphql';

const CREATED_REMOTE = Symbol('created-remote');

describe('CreateDialog', function() {
  let atomEnv, relayEnvironment;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    relayEnvironment = RelayNetworkLayerManager.getEnvironmentForHost(getEndpoint('github.com'), 'good-token');
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  it('passes everything to the CreateDialogContainer', function() {
    const request = dialogRequests.create();
    const loginModel = new GithubLoginModel(InMemoryStrategy);

    const wrapper = shallow(
      <CreateDialog
        loginModel={loginModel}
        request={request}
        inProgress={false}
        currentWindow={atomEnv.getCurrentWindow()}
        workspace={atomEnv.workspace}
        commands={atomEnv.commands}
        config={atomEnv.config}
      />,
    );

    const container = wrapper.find(CreateDialogContainer);
    assert.strictEqual(container.prop('loginModel'), loginModel);
    assert.strictEqual(container.prop('request'), request);
    assert.isFalse(container.prop('inProgress'));
    assert.strictEqual(container.prop('currentWindow'), atomEnv.getCurrentWindow());
    assert.strictEqual(container.prop('workspace'), atomEnv.workspace);
    assert.strictEqual(container.prop('commands'), atomEnv.commands);
    assert.strictEqual(container.prop('config'), atomEnv.config);
  });

  describe('createRepository', function() {
    it('successfully creates a locally cloned GitHub repository', async function() {
      expectRelayQuery({
        name: createRepositoryQuery.operation.name,
        variables: {input: {name: 'repo-name', ownerId: 'user0', visibility: 'PUBLIC'}},
      }, op => {
        return relayResponseBuilder(op)
          .createRepository(m => {
            m.repository(r => {
              r.sshUrl('ssh@github.com:user0/repo-name.git');
              r.url('https://github.com/user0/repo-name');
            });
          })
          .build();
      }).resolve();

      const localPath = temp.path({prefix: 'createrepo-'});
      const clone = sinon.stub().resolves();

      await createRepository({
        ownerID: 'user0',
        name: 'repo-name',
        visibility: 'PUBLIC',
        localPath,
        protocol: 'https',
        sourceRemoteName: 'home',
      }, {clone, relayEnvironment});

      const localStat = await fs.stat(localPath);
      assert.isTrue(localStat.isDirectory());
      assert.isTrue(clone.calledWith('https://github.com/user0/repo-name', localPath, 'home'));
    });

    it('clones with ssh when requested', async function() {
      expectRelayQuery({
        name: createRepositoryQuery.operation.name,
        variables: {input: {name: 'repo-name', ownerId: 'user0', visibility: 'PRIVATE'}},
      }, op => {
        return relayResponseBuilder(op)
          .createRepository(m => {
            m.repository(r => {
              r.sshUrl('ssh@github.com:user0/repo-name.git');
              r.url('https://github.com/user0/repo-name');
            });
          })
          .build();
      }).resolve();

      const localPath = temp.path({prefix: 'createrepo-'});
      const clone = sinon.stub().resolves();

      await createRepository({
        ownerID: 'user0',
        name: 'repo-name',
        visibility: 'PRIVATE',
        localPath,
        protocol: 'ssh',
        sourceRemoteName: 'origin',
      }, {clone, relayEnvironment});

      assert.isTrue(clone.calledWith('ssh@github.com:user0/repo-name.git', localPath, 'origin'));
    });

    it('fails fast if the local path cannot be created', async function() {
      const clone = sinon.stub().resolves();

      await assert.isRejected(createRepository({
        ownerID: 'user0',
        name: 'repo-name',
        visibility: 'PUBLIC',
        localPath: __filename,
        protocol: 'https',
        sourceRemoteName: 'origin',
      }, {clone, relayEnvironment}));

      assert.isFalse(clone.called);
    });

    it('fails if the mutation fails', async function() {
      expectRelayQuery({
        name: createRepositoryQuery.operation.name,
        variables: {input: {name: 'repo-name', ownerId: 'user0', visibility: 'PRIVATE'}},
      }, op => {
        return relayResponseBuilder(op)
          .addError('oh no')
          .build();
      }).resolve();

      const clone = sinon.stub().resolves();

      await assert.isRejected(createRepository({
        ownerID: 'user0',
        name: 'already-exists',
        visibility: 'PRIVATE',
        localPath: __filename,
        protocol: 'https',
        sourceRemoteName: 'origin',
      }, {clone, relayEnvironment}));

      assert.isFalse(clone.called);
    });
  });

  describe('publishRepository', function() {
    let repository;

    beforeEach(async function() {
      repository = await buildRepository(await cloneRepository('multiple-commits'));
    });

    it('successfully publishes an existing local repository', async function() {
      expectRelayQuery({
        name: createRepositoryQuery.operation.name,
        variables: {input: {name: 'repo-name', ownerId: 'user0', visibility: 'PUBLIC'}},
      }, op => {
        return relayResponseBuilder(op)
          .createRepository(m => {
            m.repository(r => {
              r.sshUrl('ssh@github.com:user0/repo-name.git');
              r.url('https://github.com/user0/repo-name');
            });
          })
          .build();
      }).resolve();

      sinon.stub(repository, 'addRemote').resolves(CREATED_REMOTE);
      sinon.stub(repository, 'push');

      await publishRepository({
        ownerID: 'user0',
        name: 'repo-name',
        visibility: 'PUBLIC',
        protocol: 'https',
        sourceRemoteName: 'origin',
      }, {repository, relayEnvironment});

      assert.isTrue(repository.addRemote.calledWith('origin', 'https://github.com/user0/repo-name'));
      assert.isTrue(repository.push.calledWith('master', {remote: CREATED_REMOTE, setUpstream: true}));
    });

    it('constructs an ssh remote URL when requested', async function() {
      expectRelayQuery({
        name: createRepositoryQuery.operation.name,
        variables: {input: {name: 'repo-name', ownerId: 'user0', visibility: 'PUBLIC'}},
      }, op => {
        return relayResponseBuilder(op)
          .createRepository(m => {
            m.repository(r => {
              r.sshUrl('ssh@github.com:user0/repo-name.git');
              r.url('https://github.com/user0/repo-name');
            });
          })
          .build();
      }).resolve();

      sinon.stub(repository, 'addRemote').resolves(CREATED_REMOTE);
      sinon.stub(repository, 'push');

      await publishRepository({
        ownerID: 'user0',
        name: 'repo-name',
        visibility: 'PUBLIC',
        protocol: 'ssh',
        sourceRemoteName: 'upstream',
      }, {repository, relayEnvironment});

      assert.isTrue(repository.addRemote.calledWith('upstream', 'ssh@github.com:user0/repo-name.git'));
      assert.isTrue(repository.push.calledWith('master', {remote: CREATED_REMOTE, setUpstream: true}));
    });

    it('uses "master" as the default branch if present, even if not checked out', async function() {
      expectRelayQuery({
        name: createRepositoryQuery.operation.name,
        variables: {input: {name: 'repo-name', ownerId: 'user0', visibility: 'PUBLIC'}},
      }, op => {
        return relayResponseBuilder(op)
          .createRepository(m => {
            m.repository(r => {
              r.sshUrl('ssh@github.com:user0/repo-name.git');
              r.url('https://github.com/user0/repo-name');
            });
          })
          .build();
      }).resolve();

      await repository.checkout('other-branch', {createNew: true});

      sinon.stub(repository, 'addRemote').resolves(CREATED_REMOTE);
      sinon.stub(repository, 'push');

      await publishRepository({
        ownerID: 'user0',
        name: 'repo-name',
        visibility: 'PUBLIC',
        protocol: 'https',
        sourceRemoteName: 'origin',
      }, {repository, relayEnvironment});

      assert.isTrue(repository.addRemote.calledWith('origin', 'https://github.com/user0/repo-name'));
      assert.isTrue(repository.push.calledWith('master', {remote: CREATED_REMOTE, setUpstream: true}));
    });

    it('uses HEAD as the default branch if master is not present', async function() {
      expectRelayQuery({
        name: createRepositoryQuery.operation.name,
        variables: {input: {name: 'repo-name', ownerId: 'user0', visibility: 'PUBLIC'}},
      }, op => {
        return relayResponseBuilder(op)
          .createRepository(m => {
            m.repository(r => {
              r.sshUrl('ssh@github.com:user0/repo-name.git');
              r.url('https://github.com/user0/repo-name');
            });
          })
          .build();
      }).resolve();

      await repository.checkout('non-head-branch', {createNew: true});
      await repository.checkout('other-branch', {createNew: true});
      await repository.git.deleteRef('refs/heads/master');
      repository.refresh();

      sinon.stub(repository, 'addRemote').resolves(CREATED_REMOTE);
      sinon.stub(repository, 'push');

      await publishRepository({
        ownerID: 'user0',
        name: 'repo-name',
        visibility: 'PUBLIC',
        protocol: 'https',
        sourceRemoteName: 'origin',
      }, {repository, relayEnvironment});

      assert.isTrue(repository.addRemote.calledWith('origin', 'https://github.com/user0/repo-name'));
      assert.isTrue(repository.push.calledWith('other-branch', {remote: CREATED_REMOTE, setUpstream: true}));
    });

    it('initializes an empty repository', async function() {
      expectRelayQuery({
        name: createRepositoryQuery.operation.name,
        variables: {input: {name: 'repo-name', ownerId: 'user0', visibility: 'PUBLIC'}},
      }, op => {
        return relayResponseBuilder(op)
          .createRepository(m => {
            m.repository(r => {
              r.sshUrl('ssh@github.com:user0/repo-name.git');
              r.url('https://github.com/user0/repo-name');
            });
          })
          .build();
      }).resolve();

      const empty = await buildRepository(temp.mkdirSync());
      assert.isTrue(empty.isEmpty());

      sinon.stub(empty, 'addRemote').resolves(CREATED_REMOTE);
      sinon.stub(empty, 'push');

      await publishRepository({
        ownerID: 'user0',
        name: 'repo-name',
        visibility: 'PUBLIC',
        protocol: 'https',
        sourceRemoteName: 'origin',
      }, {repository: empty, relayEnvironment});

      assert.isTrue(empty.isPresent());
      assert.isTrue(empty.addRemote.calledWith('origin', 'https://github.com/user0/repo-name'));
      assert.isFalse(empty.push.called);
    });

    it('fails if the source repository has no "master" or current branches', async function() {
      await repository.checkout('other-branch', {createNew: true});
      await repository.checkout('HEAD^');
      await repository.git.deleteRef('refs/heads/master');
      repository.refresh();

      await assert.isRejected(publishRepository({
        ownerID: 'user0',
        name: 'repo-name',
        visibility: 'PUBLIC',
        protocol: 'https',
        sourceRemoteName: 'origin',
      }, {repository, relayEnvironment}));
    });

    it('fails if the mutation fails', async function() {
      expectRelayQuery({
        name: createRepositoryQuery.operation.name,
        variables: {input: {name: 'repo-name', ownerId: 'user0', visibility: 'PRIVATE'}},
      }, op => {
        return relayResponseBuilder(op)
          .addError('oh no')
          .build();
      }).resolve();

      await assert.isRejected(publishRepository({
        ownerID: 'user0',
        name: 'repo-name',
        visibility: 'PRIVATE',
        protocol: 'https',
        sourceRemoteName: 'origin',
      }, {repository, relayEnvironment}));
    });
  });
});
