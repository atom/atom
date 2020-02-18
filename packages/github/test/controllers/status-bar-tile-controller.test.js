import fs from 'fs';
import path from 'path';

import React from 'react';
import until from 'test-until';
import {mount} from 'enzyme';

import {cloneRepository, buildRepository, buildRepositoryWithPipeline, setUpLocalAndRemoteRepositories} from '../helpers';
import {getTempDir} from '../../lib/helpers';
import Repository from '../../lib/models/repository';
import StatusBarTileController from '../../lib/controllers/status-bar-tile-controller';
import BranchView from '../../lib/views/branch-view';
import ChangedFilesCountView from '../../lib/views/changed-files-count-view';
import GithubTileView from '../../lib/views/github-tile-view';

describe('StatusBarTileController', function() {
  let atomEnvironment;
  let workspace, workspaceElement, commands, notificationManager, tooltips, confirm;

  beforeEach(function() {
    atomEnvironment = global.buildAtomEnvironment();
    workspace = atomEnvironment.workspace;
    commands = atomEnvironment.commands;
    notificationManager = atomEnvironment.notifications;
    tooltips = atomEnvironment.tooltips;
    confirm = sinon.stub(atomEnvironment, 'confirm');

    workspaceElement = atomEnvironment.views.getView(workspace);
  });

  afterEach(function() {
    atomEnvironment.destroy();
  });

  function buildApp(props) {
    return (
      <StatusBarTileController
        workspace={workspace}
        commands={commands}
        notificationManager={notificationManager}
        tooltips={tooltips}
        confirm={confirm}
        toggleGitTab={() => {}}
        toggleGithubTab={() => {}}
        {...props}
      />
    );
  }

  function getTooltipNode(wrapper, selector) {
    const ts = tooltips.findTooltips(wrapper.find(selector).getDOMNode());
    assert.lengthOf(ts, 1);
    ts[0].show();
    return ts[0].getTooltipElement();
  }

  async function mountAndLoad(app) {
    const wrapper = mount(app);
    await assert.async.isTrue(wrapper.update().find('.github-ChangedFilesCount').exists());
    return wrapper;
  }

  describe('branches', function() {
    it('indicates the current branch', async function() {
      const workdirPath = await cloneRepository('three-files');
      const repository = await buildRepository(workdirPath);

      const wrapper = await mountAndLoad(buildApp({repository}));

      assert.equal(wrapper.find(BranchView).prop('currentBranch').name, 'master');
      assert.lengthOf(wrapper.find(BranchView).find('.github-branch-detached'), 0);
    });

    it('styles a detached HEAD differently', async function() {
      const workdirPath = await cloneRepository('multiple-commits');
      const repository = await buildRepository(workdirPath);
      await repository.checkout('HEAD~2');

      const wrapper = await mountAndLoad(buildApp({repository}));

      assert.equal(wrapper.find(BranchView).prop('currentBranch').name, 'master~2');
      assert.lengthOf(wrapper.find(BranchView).find('.github-branch-detached'), 1);
    });

    describe('the branch menu', function() {
      function selectOption(tip, value) {
        const selects = Array.from(tip.getElementsByTagName('select'));
        assert.lengthOf(selects, 1);
        const select = selects[0];
        select.value = value;

        const event = new Event('change', {bubbles: true, cancelable: true});
        select.dispatchEvent(event);
      }

      describe('checking out an existing branch', function() {
        it('can check out existing branches with no conflicts', async function() {
          const workdirPath = await cloneRepository('three-files');
          const repository = await buildRepository(workdirPath);

          // create branch called 'branch'
          await repository.git.exec(['branch', 'branch']);

          const wrapper = await mountAndLoad(buildApp({repository}));

          const tip = getTooltipNode(wrapper, '.github-branch');
          const selectList = tip.querySelector('select');

          const branches = Array.from(tip.getElementsByTagName('option'), e => e.innerHTML);
          assert.deepEqual(branches, ['branch', 'master']);

          const branch0 = await repository.getCurrentBranch();
          assert.equal(branch0.getName(), 'master');
          assert.isFalse(branch0.isDetached());
          assert.equal(selectList.value, 'master');

          selectOption(tip, 'branch');
          assert.isTrue(selectList.hasAttribute('disabled'));

          await until(async () => {
            const branch1 = await repository.getCurrentBranch();
            return branch1.getName() === 'branch' && !branch1.isDetached();
          });

          await assert.async.equal(selectList.value, 'branch');
          await assert.async.isFalse(selectList.hasAttribute('disabled'));

          selectOption(tip, 'master');
          assert.isTrue(selectList.hasAttribute('disabled'));

          await until(async () => {
            const branch2 = await repository.getCurrentBranch();
            return branch2.getName() === 'master' && !branch2.isDetached();
          });
          await assert.async.equal(selectList.value, 'master');
          await assert.async.isFalse(selectList.hasAttribute('disabled'));
        });

        it('displays an error message if checkout fails', async function() {
          const {localRepoPath} = await setUpLocalAndRemoteRepositories('three-files');
          const repository = await buildRepositoryWithPipeline(localRepoPath, {confirm, notificationManager, workspace});
          await repository.git.exec(['branch', 'branch']);

          // create a conflict
          fs.writeFileSync(path.join(localRepoPath, 'a.txt'), 'a change');

          await repository.git.exec(['commit', '-a', '-m', 'change on master']);
          await repository.checkout('branch');
          fs.writeFileSync(path.join(localRepoPath, 'a.txt'), 'a change that conflicts');

          const wrapper = await mountAndLoad(buildApp({repository}));

          const tip = getTooltipNode(wrapper, BranchView);
          const selectList = tip.querySelector('select');

          const branch0 = await repository.getCurrentBranch();
          assert.equal(branch0.getName(), 'branch');
          assert.isFalse(branch0.isDetached());
          assert.equal(selectList.value, 'branch');

          sinon.stub(notificationManager, 'addError');

          selectOption(tip, 'master');
          assert.isTrue(selectList.hasAttribute('disabled'));
          await assert.async.equal(selectList.value, 'master');
          await until(() => {
            repository.refresh();
            return selectList.value === 'branch';
          });

          assert.isTrue(notificationManager.addError.called);
          assert.isFalse(selectList.hasAttribute('disabled'));
          const notificationArgs = notificationManager.addError.args[0];
          assert.equal(notificationArgs[0], 'Checkout aborted');
          assert.match(notificationArgs[1].description, /Local changes to the following would be overwritten/);
        });
      });

      describe('checking out newly created branches', function() {
        it('can check out newly created branches', async function() {
          const workdirPath = await cloneRepository('three-files');
          const repository = await buildRepositoryWithPipeline(workdirPath, {confirm, notificationManager, workspace});

          const wrapper = await mountAndLoad(buildApp({repository}));

          const tip = getTooltipNode(wrapper, BranchView);
          const selectList = tip.querySelector('select');
          const editor = tip.querySelector('atom-text-editor');

          const branches = Array.from(tip.querySelectorAll('option'), option => option.value);
          assert.deepEqual(branches, ['master']);
          const branch0 = await repository.getCurrentBranch();
          assert.equal(branch0.getName(), 'master');
          assert.isFalse(branch0.isDetached());
          assert.equal(selectList.value, 'master');

          tip.querySelector('button').click();

          assert.isTrue(selectList.className.includes('hidden'));
          assert.isFalse(tip.querySelector('.github-BranchMenuView-editor').className.includes('hidden'));

          tip.querySelector('atom-text-editor').getModel().setText('new-branch');
          tip.querySelector('button').click();
          assert.isTrue(editor.hasAttribute('readonly'));

          await until(async () => {
            const branch1 = await repository.getCurrentBranch();
            return branch1.getName() === 'new-branch' && !branch1.isDetached();
          });
          repository.refresh(); // clear cache manually, since we're not listening for file system events here
          await assert.async.equal(selectList.value, 'new-branch');

          await assert.async.isTrue(tip.querySelector('.github-BranchMenuView-editor').className.includes('hidden'));
          assert.isFalse(selectList.className.includes('hidden'));
        });

        it('displays an error message if branch already exists', async function() {
          const workdirPath = await cloneRepository('three-files');
          const repository = await buildRepositoryWithPipeline(workdirPath, {confirm, notificationManager, workspace});
          await repository.git.exec(['checkout', '-b', 'branch']);

          const wrapper = await mountAndLoad(buildApp({repository}));

          const tip = getTooltipNode(wrapper, BranchView);
          const createNewButton = tip.querySelector('button');
          sinon.stub(notificationManager, 'addError');

          const branches = Array.from(tip.getElementsByTagName('option'), option => option.value);
          assert.deepEqual(branches, ['branch', 'master']);
          const branch0 = await repository.getCurrentBranch();
          assert.equal(branch0.getName(), 'branch');
          assert.isFalse(branch0.isDetached());
          assert.equal(tip.querySelector('select').value, 'branch');

          createNewButton.click();
          tip.querySelector('atom-text-editor').getModel().setText('master');
          createNewButton.click();
          assert.isTrue(createNewButton.hasAttribute('disabled'));

          await assert.async.isTrue(notificationManager.addError.called);
          const notificationArgs = notificationManager.addError.args[0];
          assert.equal(notificationArgs[0], 'Cannot create branch');
          assert.match(notificationArgs[1].description, /already exists/);

          const branch1 = await repository.getCurrentBranch();
          assert.equal(branch1.getName(), 'branch');
          assert.isFalse(branch1.isDetached());

          assert.lengthOf(tip.querySelectorAll('.github-BranchMenuView-editor'), 1);
          assert.equal(tip.querySelector('atom-text-editor').getModel().getText(), 'master');
          assert.isFalse(createNewButton.hasAttribute('disabled'));
        });

        it('clears the new branch name after successful creation', async function() {
          const workdirPath = await cloneRepository('three-files');
          const repository = await buildRepositoryWithPipeline(workdirPath, {confirm, notificationManager, workspace});

          const wrapper = await mountAndLoad(buildApp({repository}));

          // Open the branch creator, type a branch name, and confirm branch creation.
          await wrapper.find('.github-BranchMenuView-button').simulate('click');
          wrapper.find('.github-BranchMenuView-editor atom-text-editor').getDOMNode().getModel()
            .setText('new-branch-name');
          await wrapper.find('.github-BranchMenuView-button').simulate('click');

          await until('branch creation completes', async () => {
            const b = await repository.getCurrentBranch();
            return b.getName() === 'new-branch-name' && !b.isDetached();
          });
          repository.refresh();
          await assert.async.isUndefined(
            wrapper.update().find('.github-BranchMenuView-editor atom-text-editor').prop('readonly'),
          );

          await wrapper.find('.github-BranchMenuView-button').simulate('click');
          assert.strictEqual(
            wrapper.find('.github-BranchMenuView-editor atom-text-editor').getDOMNode().getModel().getText(),
            '',
          );
        });
      });

      describe('with a detached HEAD', function() {
        it('includes the current describe output as a disabled option', async function() {
          const workdirPath = await cloneRepository('multiple-commits');
          const repository = await buildRepository(workdirPath);
          await repository.checkout('HEAD~2');

          const wrapper = await mountAndLoad(buildApp({repository}));

          const tip = getTooltipNode(wrapper, BranchView);
          assert.equal(tip.querySelector('select').value, 'detached');
          const option = tip.querySelector('option[value="detached"]');
          assert.equal(option.textContent, 'master~2');
          assert.isTrue(option.disabled);
        });
      });
    });
  });

  describe('pushing and pulling', function() {

    describe('status bar tile state', function() {

      describe('when there is no remote tracking branch', function() {
        let repository;
        let statusBarTile;

        beforeEach(async function() {
          const {localRepoPath} = await setUpLocalAndRemoteRepositories();
          repository = await buildRepository(localRepoPath);
          await repository.git.exec(['checkout', '-b', 'new-branch']);

          statusBarTile = await mountAndLoad(buildApp({repository}));

          sinon.spy(repository, 'fetch');
          sinon.spy(repository, 'push');
          sinon.spy(repository, 'pull');
        });

        it('gives the option to publish the current branch', function() {
          assert.equal(statusBarTile.find('.github-PushPull').text().trim(), 'Publish');
        });

        it('pushes the current branch when clicked', function() {
          statusBarTile.find('.github-PushPull').simulate('click');
          assert.isTrue(repository.push.called);
        });

        it('does nothing when clicked and currently pushing', async function() {
          repository.getOperationStates().setPushInProgress(true);
          await assert.async.strictEqual(statusBarTile.update().find('.github-PushPull').text().trim(), 'Pushing');

          statusBarTile.find('.github-PushPull').simulate('click');
          assert.isFalse(repository.fetch.called);
          assert.isFalse(repository.push.called);
          assert.isFalse(repository.pull.called);
        });
      });

      describe('when there is a remote with nothing to pull or push', function() {
        let repository;
        let statusBarTile;

        beforeEach(async function() {
          const {localRepoPath} = await setUpLocalAndRemoteRepositories();
          repository = await buildRepository(localRepoPath);

          statusBarTile = await mountAndLoad(buildApp({repository}));

          sinon.spy(repository, 'fetch');
          sinon.spy(repository, 'push');
          sinon.spy(repository, 'pull');
        });

        it('gives the option to fetch from remote', function() {
          assert.equal(statusBarTile.find('.github-PushPull').text().trim(), 'Fetch');
        });

        it('fetches from remote when clicked', function() {
          statusBarTile.find('.github-PushPull').simulate('click');
          assert.isTrue(repository.fetch.called);
        });

        it('does nothing when clicked and currently fetching', async function() {
          repository.getOperationStates().setFetchInProgress(true);
          await assert.async.strictEqual(statusBarTile.update().find('.github-PushPull').text().trim(), 'Fetching');

          statusBarTile.find('.github-PushPull').simulate('click');
          assert.isFalse(repository.fetch.called);
          assert.isFalse(repository.push.called);
          assert.isFalse(repository.pull.called);
        });
      });

      describe('when there is a remote and we are ahead', function() {
        let repository;
        let statusBarTile;

        beforeEach(async function() {
          const {localRepoPath} = await setUpLocalAndRemoteRepositories();
          repository = await buildRepository(localRepoPath);
          await repository.git.commit('new local commit', {allowEmpty: true});

          statusBarTile = await mountAndLoad(buildApp({repository}));

          sinon.spy(repository, 'fetch');
          sinon.spy(repository, 'push');
          sinon.spy(repository, 'pull');
        });

        it('gives the option to push with ahead count', function() {
          assert.equal(statusBarTile.find('.github-PushPull').text().trim(), 'Push 1');
        });

        it('pushes when clicked', function() {
          statusBarTile.find('.github-PushPull').simulate('click');
          assert.isTrue(repository.push.called);
        });

        it('does nothing when clicked and is currently pushing', async function() {
          repository.getOperationStates().setPushInProgress(true);
          await assert.async.strictEqual(statusBarTile.find('.github-PushPull').text().trim(), 'Pushing');

          statusBarTile.find('.github-PushPull').simulate('click');
          assert.isFalse(repository.fetch.called);
          assert.isFalse(repository.push.called);
          assert.isFalse(repository.pull.called);
        });
      });

      describe('when there is a remote and we are behind', function() {
        let repository;
        let statusBarTile;

        beforeEach(async function() {
          const {localRepoPath} = await setUpLocalAndRemoteRepositories();
          repository = await buildRepository(localRepoPath);
          await repository.git.exec(['reset', '--hard', 'HEAD~2']);

          statusBarTile = await mountAndLoad(buildApp({repository}));

          sinon.spy(repository, 'fetch');
          sinon.spy(repository, 'push');
          sinon.spy(repository, 'pull');
        });

        it('gives the option to pull with behind count', function() {
          assert.equal(statusBarTile.find('.github-PushPull').text().trim(), 'Pull 2');
        });

        it('pulls when clicked', function() {
          statusBarTile.find('.github-PushPull').simulate('click');
          assert.isTrue(repository.pull.called);
        });

        it('does nothing when clicked and is currently pulling', async function() {
          repository.getOperationStates().setPullInProgress(true);
          await assert.async.strictEqual(statusBarTile.update().find('.github-PushPull').text().trim(), 'Pulling');

          statusBarTile.find('.github-PushPull').simulate('click');
          assert.isFalse(repository.fetch.called);
          assert.isFalse(repository.push.called);
          assert.isFalse(repository.pull.called);
        });
      });

      describe('when there is a remote and we are ahead and behind', function() {
        let repository;
        let statusBarTile;

        beforeEach(async function() {
          const {localRepoPath} = await setUpLocalAndRemoteRepositories();
          repository = await buildRepository(localRepoPath);
          await repository.git.exec(['reset', '--hard', 'HEAD~2']);
          await repository.git.commit('new local commit', {allowEmpty: true});

          statusBarTile = await mountAndLoad(buildApp({repository}));

          sinon.spy(repository, 'fetch');
          sinon.spy(repository, 'push');
          sinon.spy(repository, 'pull');
        });

        it('gives the option to pull with ahead and behind count', function() {
          assert.equal(statusBarTile.find('.github-PushPull').text().trim(), '1 Pull 2');
        });

        it('pulls when clicked', function() {
          statusBarTile.find('.github-PushPull').simulate('click');
          assert.isTrue(repository.pull.called);
          assert.isFalse(repository.fetch.called);
          assert.isFalse(repository.push.called);
        });

        it('does nothing when clicked and is currently pulling', async function() {
          repository.getOperationStates().setPullInProgress(true);
          await assert.async.strictEqual(statusBarTile.update().find('.github-PushPull').text().trim(), 'Pulling');

          statusBarTile.find('.github-PushPull').simulate('click');
          assert.isFalse(repository.fetch.called);
          assert.isFalse(repository.push.called);
          assert.isFalse(repository.pull.called);
        });
      });

      describe('when there is a remote and we are detached HEAD', function() {
        let repository;
        let statusBarTile;

        beforeEach(async function() {
          const {localRepoPath} = await setUpLocalAndRemoteRepositories();
          repository = await buildRepository(localRepoPath);
          await repository.checkout('HEAD~2');

          statusBarTile = await mountAndLoad(buildApp({repository}));

          sinon.spy(repository, 'fetch');
          sinon.spy(repository, 'push');
          sinon.spy(repository, 'pull');
        });

        it('gives a hint that we are not on a branch', function() {
          assert.equal(statusBarTile.find('.github-PushPull').text().trim(), 'Not on branch');
        });

        it('does nothing when clicked', function() {
          statusBarTile.find('.github-PushPull').simulate('click');
          assert.equal(statusBarTile.find('.github-PushPull').text().trim(), 'Not on branch');
          assert.isFalse(repository.fetch.called);
          assert.isFalse(repository.push.called);
          assert.isFalse(repository.pull.called);
        });
      });

      describe('when there is no remote named "origin"', function() {
        let repository;
        let statusBarTile;

        beforeEach(async function() {
          const {localRepoPath} = await setUpLocalAndRemoteRepositories();
          repository = await buildRepository(localRepoPath);
          await repository.git.exec(['remote', 'remove', 'origin']);

          statusBarTile = await mountAndLoad(buildApp({repository}));

          sinon.spy(repository, 'fetch');
          sinon.spy(repository, 'push');
          sinon.spy(repository, 'pull');
        });

        it('gives that there is no remote', function() {
          assert.equal(statusBarTile.find('.github-PushPull').text().trim(), 'No remote');
        });

        it('does nothing when clicked', function() {
          statusBarTile.find('.github-PushPull').simulate('click');
          assert.equal(statusBarTile.find('.github-PushPull').text().trim(), 'No remote');
          assert.isFalse(repository.fetch.called);
          assert.isFalse(repository.push.called);
          assert.isFalse(repository.pull.called);
        });
      });

    });

    it('displays an error message if push fails', async function() {
      const {localRepoPath} = await setUpLocalAndRemoteRepositories();
      const repository = await buildRepositoryWithPipeline(localRepoPath, {confirm, notificationManager, workspace});
      await repository.git.exec(['reset', '--hard', 'HEAD~2']);
      await repository.git.commit('another commit', {allowEmpty: true});

      const wrapper = await mountAndLoad(buildApp({repository}));

      sinon.stub(notificationManager, 'addError');

      try {
        await wrapper.instance().push(await wrapper.instance().fetchData(repository))();
      } catch (e) {
        assert(e, 'is error');
      }

      await assert.async.isTrue(notificationManager.addError.called);
      const notificationArgs = notificationManager.addError.args[0];
      assert.equal(notificationArgs[0], 'Push rejected');
      assert.match(notificationArgs[1].description, /Try pulling before pushing/);
    });

    describe('fetch and pull commands', function() {
      it('fetches when github:fetch is triggered', async function() {
        const {localRepoPath} = await setUpLocalAndRemoteRepositories('multiple-commits', {remoteAhead: true});
        const repository = await buildRepository(localRepoPath);

        await mountAndLoad(buildApp({repository}));

        sinon.spy(repository, 'fetch');

        commands.dispatch(workspaceElement, 'github:fetch');

        assert.isTrue(repository.fetch.called);
      });

      it('pulls when github:pull is triggered', async function() {
        const {localRepoPath} = await setUpLocalAndRemoteRepositories('multiple-commits', {remoteAhead: true});
        const repository = await buildRepository(localRepoPath);

        await mountAndLoad(buildApp({repository}));

        sinon.spy(repository, 'pull');

        commands.dispatch(workspaceElement, 'github:pull');

        assert.isTrue(repository.pull.called);
      });

      it('pushes when github:push is triggered', async function() {
        const {localRepoPath} = await setUpLocalAndRemoteRepositories();
        const repository = await buildRepository(localRepoPath);
        await mountAndLoad(buildApp({repository}));

        sinon.spy(repository, 'push');

        commands.dispatch(workspaceElement, 'github:push');

        assert.isTrue(repository.push.calledWith('master', sinon.match({force: false, setUpstream: false})));
      });

      it('force pushes when github:force-push is triggered', async function() {
        const {localRepoPath} = await setUpLocalAndRemoteRepositories();
        const repository = await buildRepositoryWithPipeline(localRepoPath, {confirm, notificationManager, workspace});

        confirm.returns(0);
        await mountAndLoad(buildApp({repository}));

        sinon.spy(repository.git, 'push');

        commands.dispatch(workspaceElement, 'github:force-push');

        assert.equal(confirm.callCount, 1);
        await assert.async.isTrue(repository.git.push.calledWith('origin', 'master', sinon.match({force: true, setUpstream: false})));
        await assert.async.isFalse(repository.getOperationStates().isPushInProgress());
      });

      it('displays a warning notification when pull results in merge conflicts', async function() {
        const {localRepoPath} = await setUpLocalAndRemoteRepositories('multiple-commits', {remoteAhead: true});
        fs.writeFileSync(path.join(localRepoPath, 'file.txt'), 'apple');
        const repository = await buildRepositoryWithPipeline(localRepoPath, {confirm, notificationManager, workspace});
        await repository.git.exec(['commit', '-am', 'Add conflicting change']);

        const wrapper = await mountAndLoad(buildApp({repository}));

        sinon.stub(notificationManager, 'addWarning');

        try {
          await wrapper.instance().pull(await wrapper.instance().fetchData(repository))();
        } catch (e) {
          assert(e, 'is error');
        }
        repository.refresh();

        await assert.async.isTrue(notificationManager.addWarning.called);
        const notificationArgs = notificationManager.addWarning.args[0];
        assert.equal(notificationArgs[0], 'Merge conflicts');
        assert.match(notificationArgs[1].description, /Your local changes conflicted with changes made on the remote branch./);

        assert.isTrue(await repository.isMerging());
      });
    });
  });

  describe('when the local branch is named differently from the remote branch it\'s tracking', function() {
    let repository, wrapper;

    beforeEach(async function() {
      const {localRepoPath} = await setUpLocalAndRemoteRepositories();
      repository = await buildRepository(localRepoPath);
      wrapper = await mountAndLoad(buildApp({repository}));
      await repository.git.exec(['checkout', '-b', 'another-name', '--track', 'origin/master']);
      repository.refresh();
    });

    it('fetches with no git error', async function() {
      sinon.spy(repository, 'fetch');
      await wrapper
        .instance()
        .fetch(await wrapper.instance().fetchData(repository))();
      assert.isTrue(repository.fetch.calledWith('refs/heads/master', {
        remoteName: 'origin',
      }));
    });

    it('pulls from the correct branch', async function() {
      const prePullSHA = await repository.git.exec(['rev-parse', 'HEAD']);
      await repository.git.exec(['reset', '--hard', 'HEAD~2']);
      sinon.spy(repository, 'pull');
      await wrapper
        .instance()
        .pull(await wrapper.instance().fetchData(repository))();
      const postPullSHA = await repository.git.exec(['rev-parse', 'HEAD']);
      assert.isTrue(repository.pull.calledWith('another-name', {
        refSpec: 'master:another-name',
      }));
      assert.equal(prePullSHA, postPullSHA);
    });

    it('pushes to the correct branch', async function() {
      await repository.git.commit('new local commit', {allowEmpty: true});
      const localSHA = await repository.git.exec(['rev-parse', 'another-name']);
      sinon.spy(repository, 'push');
      await wrapper
        .instance()
        .push(await wrapper.instance().fetchData(repository))();
      const remoteSHA = await repository.git.exec(['rev-parse', 'origin/master']);
      assert.isTrue(repository.push.calledWith('another-name',
        sinon.match({refSpec: 'another-name:master'}),
      ));
      assert.equal(localSHA, remoteSHA);
    });
  });

  describe('github tile', function() {
    it('toggles the github panel when clicked', async function() {
      const workdirPath = await cloneRepository('three-files');
      const repository = await buildRepository(workdirPath);

      const toggleGithubTab = sinon.spy();

      const wrapper = await mountAndLoad(buildApp({repository, toggleGithubTab}));

      wrapper.find(GithubTileView).simulate('click');
      assert(toggleGithubTab.calledOnce);
    });
  });

  describe('changed files', function() {

    it('toggles the git panel when clicked', async function() {
      const workdirPath = await cloneRepository('three-files');
      const repository = await buildRepository(workdirPath);

      const toggleGitTab = sinon.spy();

      const wrapper = await mountAndLoad(buildApp({repository, toggleGitTab}));

      wrapper.find(ChangedFilesCountView).simulate('click');
      assert(toggleGitTab.calledOnce);
    });
  });

  describe('while the repository is not present', function() {
    it('does not display the branch or push-pull tiles', async function() {
      const workdirPath = await getTempDir();
      const repository = new Repository(workdirPath);
      assert.isFalse(repository.isPresent());

      const wrapper = await mountAndLoad(buildApp({repository}));

      assert.isFalse(wrapper.find('BranchView').exists());
      assert.isFalse(wrapper.find('BranchMenuView').exists());
      assert.isFalse(wrapper.find('PushPullView').exists());
      assert.isTrue(wrapper.find('ChangedFilesCountView').exists());
    });
  });
});
