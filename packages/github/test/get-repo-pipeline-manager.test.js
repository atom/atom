import {cloneRepository, buildRepositoryWithPipeline} from './helpers';
import {GitError} from '../lib/git-shell-out-strategy';


describe('getRepoPipelineManager()', function() {

  let atomEnv, workspace, notificationManager, repo, pipelineManager, confirm;

  const getPipeline = (pm, actionName) => {
    const actionKey = pm.actionKeys[actionName];
    return pm.getPipeline(actionKey);
  };

  const buildRepo = (workdir, override = {}) => {
    const option = {
      confirm,
      notificationManager,
      workspace,
      ...override,
    };
    return buildRepositoryWithPipeline(workdir, option);
  };

  const gitErrorStub = (stdErr = '', stdOut = '') => {
    return sinon.stub().throws(() => {
      const err = new GitError();
      err.stdErr = stdErr;
      err.stdOut = stdOut;
      return err;
    });
  };

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    workspace = atomEnv.workspace;
    notificationManager = atomEnv.notifications;
    confirm = sinon.stub(atomEnv, 'confirm');

    const workdir = await cloneRepository('multiple-commits');
    repo = await buildRepo(workdir);
    pipelineManager = repo.pipelineManager;
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  it('has all the action pipelines', function() {
    const expectedActions = ['PUSH', 'PULL', 'FETCH', 'COMMIT', 'CHECKOUT', 'ADDREMOTE'];
    for (const actionName of expectedActions) {
      assert.ok(getPipeline(pipelineManager, actionName));
    }
  });

  describe('PUSH pipeline', function() {

    it('confirm-force-push', function() {
      it('before confirming', function() {
        const pushPipeline = getPipeline(pipelineManager, 'PUSH');
        const pushStub = sinon.stub();
        sinon.spy(notificationManager, 'addError');
        pushPipeline.run(pushStub, repo, '', {force: true});
        assert.isTrue(confirm.calledWith({
          message: 'Are you sure you want to force push?',
          detailedMessage: 'This operation could result in losing data on the remote.',
          buttons: ['Force Push', 'Cancel'],
        }));
        assert.isTrue(pushStub.called());
      });

      it('after confirming', async function() {
        const nWorkdir = await cloneRepository('multiple-commits');
        const confirmStub = sinon.stub(atomEnv, 'confirm').return(0);
        const nRepo = buildRepo(nWorkdir, {confirm: confirmStub});
        const pushPipeline = getPipeline(nRepo.pipelineManager, 'PUSH');
        const pushStub = sinon.stub();
        sinon.spy(notificationManager, 'addError');

        pushPipeline.run(pushStub, repo, '', {force: true});
        assert.isFalse(confirm.called);
        assert.isFalse(pushStub.called);
      });
    });

    it('set-push-in-progress', async function() {
      const pushPipeline = getPipeline(pipelineManager, 'PUSH');
      const pushStub = sinon.stub().callsFake(() => {
        assert.isTrue(repo.getOperationStates().isPushInProgress());
        return Promise.resolve();
      });
      pushPipeline.run(pushStub, repo, '', {});
      assert.isTrue(pushStub.called);
      await assert.async.isFalse(repo.getOperationStates().isPushInProgress());
    });

    it('failed-to-push-error', function() {
      const pushPipeline = getPipeline(pipelineManager, 'PUSH');
      sinon.spy(notificationManager, 'addError');


      pushPipeline.run(gitErrorStub('rejected failed to push'), repo, '', {});
      assert.isTrue(notificationManager.addError.calledWithMatch('Push rejected', {dismissable: true}));

      pushPipeline.run(gitErrorStub('something else'), repo, '', {});
      assert.isTrue(notificationManager.addError.calledWithMatch('Unable to push', {dismissable: true}));
    });
  });

  describe('PULL pipeline', function() {
    it('set-pull-in-progress', async function() {
      const pull = getPipeline(pipelineManager, 'PULL');
      const pullStub = sinon.stub().callsFake(() => {
        assert.isTrue(repo.getOperationStates().isPullInProgress());
        return Promise.resolve();
      });
      pull.run(pullStub, repo, '', {});
      assert.isTrue(pullStub.called);
      await assert.async.isFalse(repo.getOperationStates().isPullInProgress());
    });

    it('failed-to-pull-error', function() {
      const pullPipeline = getPipeline(pipelineManager, 'PULL');
      sinon.spy(notificationManager, 'addError');
      sinon.spy(notificationManager, 'addWarning');

      pullPipeline.run(gitErrorStub('error: Your local changes to the following files would be overwritten by merge:\n\ta.txt\n\tb.txt'), repo, '', {});
      assert.isTrue(notificationManager.addError.calledWithMatch('Pull aborted', {dismissable: true}));

      pullPipeline.run(gitErrorStub('', 'Automatic merge failed; fix conflicts and then commit the result.'), repo, '', {});
      assert.isTrue(notificationManager.addWarning.calledWithMatch('Merge conflicts', {dismissable: true}));

      pullPipeline.run(gitErrorStub('fatal: Not possible to fast-forward, aborting.'), repo, '', {});
      assert.isTrue(notificationManager.addWarning.calledWithMatch('Unmerged changes', {dismissable: true}));

      pullPipeline.run(gitErrorStub('something else'), repo, '', {});
      assert.isTrue(notificationManager.addError.calledWithMatch('Unable to pull', {dismissable: true}));
    });
  });

  describe('FETCH pipeline', function() {
    let fetchPipeline;

    beforeEach(function() {
      fetchPipeline = getPipeline(pipelineManager, 'FETCH');
    });

    it('set-fetch-in-progress', async function() {
      const fetchStub = sinon.stub().callsFake(() => {
        assert.isTrue(repo.getOperationStates().isFetchInProgress());
        return Promise.resolve();
      });
      fetchPipeline.run(fetchStub, repo, '', {});
      assert.isTrue(fetchStub.called);
      await assert.async.isFalse(repo.getOperationStates().isFetchInProgress());
    });

    it('failed-to-fetch-error', function() {
      sinon.spy(notificationManager, 'addError');

      fetchPipeline.run(gitErrorStub('this is a nice error msg'), repo, '', {});
      assert.isTrue(notificationManager.addError.calledWithMatch('Unable to fetch', {
        detail: 'this is a nice error msg',
        dismissable: true,
      }));
    });
  });

  describe('CHECKOUT pipeline', function() {
    let checkoutPipeline;

    beforeEach(function() {
      checkoutPipeline = getPipeline(pipelineManager, 'CHECKOUT');
    });

    it('set-checkout-in-progress', async function() {
      const checkoutStub = sinon.stub().callsFake(() => {
        assert.isTrue(repo.getOperationStates().isCheckoutInProgress());
        return Promise.resolve();
      });
      checkoutPipeline.run(checkoutStub, repo, '', {});
      assert.isTrue(checkoutStub.called);
      await assert.async.isFalse(repo.getOperationStates().isCheckoutInProgress());
    });

    it('failed-to-checkout-error', function() {
      sinon.spy(notificationManager, 'addError');

      checkoutPipeline.run(gitErrorStub('local changes would be overwritten: \n\ta.txt\n\tb.txt'), repo, '', {createNew: false});
      assert.isTrue(notificationManager.addError.calledWithMatch('Checkout aborted', {dismissable: true}));

      checkoutPipeline.run(gitErrorStub('branch x already exists'), repo, '', {createNew: false});
      assert.isTrue(notificationManager.addError.calledWithMatch('Checkout aborted', {dismissable: true}));

      checkoutPipeline.run(gitErrorStub('error: you need to resolve your current index first'), repo, '', {createNew: false});
      assert.isTrue(notificationManager.addError.calledWithMatch('Checkout aborted', {dismissable: true}));

      checkoutPipeline.run(gitErrorStub('something else'), repo, '', {createNew: true});
      assert.isTrue(notificationManager.addError.calledWithMatch('Cannot create branch', {detail: 'something else', dismissable: true}));
    });
  });

  describe('COMMIT pipeline', function() {
    let commitPipeline;

    beforeEach(function() {
      commitPipeline = getPipeline(pipelineManager, 'COMMIT');
    });

    it('set-commit-in-progress', async function() {
      const commitStub = sinon.stub().callsFake(() => {
        assert.isTrue(repo.getOperationStates().isCommitInProgress());
        return Promise.resolve();
      });
      commitPipeline.run(commitStub, repo, '', {});
      assert.isTrue(commitStub.called);
      await assert.async.isFalse(repo.getOperationStates().isCommitInProgress());
    });

    it('failed-to-commit-error', function() {
      sinon.spy(notificationManager, 'addError');

      commitPipeline.run(gitErrorStub('a nice msg'), repo, '', {});
      assert.isTrue(notificationManager.addError.calledWithMatch('Unable to commit', {detail: 'a nice msg', dismissable: true}));
    });
  });

  describe('ADDREMOTE pipeline', function() {
    it('failed-to-add-remote', function() {
      const addRemotePipeline = getPipeline(pipelineManager, 'ADDREMOTE');
      sinon.spy(notificationManager, 'addError');

      addRemotePipeline.run(gitErrorStub('fatal: remote x already exists.'), repo, 'existential-crisis');
      assert.isTrue(notificationManager.addError.calledWithMatch('Cannot create remote', {
        detail: 'The repository already contains a remote named existential-crisis.',
        dismissable: true,
      }));

      addRemotePipeline.run(gitErrorStub('something else'), repo, 'remotename');
      assert.isTrue(notificationManager.addError.calledWithMatch('Cannot create remote', {
        detail: 'something else',
        dismissable: true,
      }));
    });
  });
});
