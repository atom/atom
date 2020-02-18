import fs from 'fs';
import path from 'path';
import React from 'react';
import {mount} from 'enzyme';
import dedent from 'dedent-js';

import GitTabController from '../../lib/controllers/git-tab-controller';
import {gitTabControllerProps} from '../fixtures/props/git-tab-props';
import {cloneRepository, buildRepository, buildRepositoryWithPipeline, initRepository} from '../helpers';
import Repository from '../../lib/models/repository';
import Author from '../../lib/models/author';
import ResolutionProgress from '../../lib/models/conflicts/resolution-progress';
import {GitError} from '../../lib/git-shell-out-strategy';

describe('GitTabController', function() {
  let atomEnvironment, workspace, workspaceElement, commands, notificationManager;
  let resolutionProgress, refreshResolutionProgress;

  beforeEach(function() {
    atomEnvironment = global.buildAtomEnvironment();
    workspace = atomEnvironment.workspace;
    commands = atomEnvironment.commands;
    notificationManager = atomEnvironment.notifications;

    workspaceElement = atomEnvironment.views.getView(workspace);

    resolutionProgress = new ResolutionProgress();
    refreshResolutionProgress = sinon.spy();
  });

  afterEach(function() {
    atomEnvironment.destroy();
  });

  async function buildApp(repository, overrides = {}) {
    const props = await gitTabControllerProps(atomEnvironment, repository, {
      resolutionProgress,
      refreshResolutionProgress,
      ...overrides,
    });
    return <GitTabController {...props} />;
  }

  async function updateWrapper(repository, wrapper, overrides = {}) {
    repository.refresh();
    const props = await gitTabControllerProps(atomEnvironment, repository, {
      resolutionProgress,
      refreshResolutionProgress,
      ...overrides,
    });
    wrapper.setProps(props);
  }

  it('displays a loading message in GitTabView while data is being fetched', async function() {
    const workdirPath = await cloneRepository('three-files');
    fs.writeFileSync(path.join(workdirPath, 'a.txt'), 'a change\n');
    fs.unlinkSync(path.join(workdirPath, 'b.txt'));
    const repository = new Repository(workdirPath);
    assert.isTrue(repository.isLoading());

    const wrapper = mount(await buildApp(repository));

    assert.isTrue(wrapper.find('.github-Git').hasClass('is-loading'));
    assert.lengthOf(wrapper.find('StagingView'), 1);
    assert.lengthOf(wrapper.find('CommitController'), 1);

    await repository.getLoadPromise();
    await updateWrapper(repository, wrapper);

    await assert.async.isFalse(wrapper.update().find('.github-Git').hasClass('is-loading'));
    assert.lengthOf(wrapper.find('StagingView'), 1);
    assert.lengthOf(wrapper.find('CommitController'), 1);
  });

  it('displays an initialization prompt for an absent repository', async function() {
    const repository = Repository.absent();
    const wrapper = mount(await buildApp(repository));

    assert.isTrue(wrapper.find('.is-empty').exists());
    assert.isTrue(wrapper.find('.no-repository').exists());
  });

  it('fetches conflict marker counts for conflicting files', async function() {
    const workdirPath = await cloneRepository('merge-conflict');
    const repository = await buildRepository(workdirPath);
    await assert.isRejected(repository.git.merge('origin/branch'));

    const rp = new ResolutionProgress();
    rp.reportMarkerCount(path.join(workdirPath, 'added-to-both.txt'), 5);

    mount(await buildApp(repository, {resolutionProgress: rp}));

    assert.isTrue(refreshResolutionProgress.calledWith(path.join(workdirPath, 'modified-on-both-ours.txt')));
    assert.isTrue(refreshResolutionProgress.calledWith(path.join(workdirPath, 'modified-on-both-theirs.txt')));
    assert.isFalse(refreshResolutionProgress.calledWith(path.join(workdirPath, 'added-to-both.txt')));
  });

  describe('abortMerge()', function() {
    it('resets merge related state', async function() {
      const workdirPath = await cloneRepository('merge-conflict');
      const repository = await buildRepository(workdirPath);

      await assert.isRejected(repository.git.merge('origin/branch'));

      const confirm = sinon.stub();
      const wrapper = mount(await buildApp(repository, {confirm}));

      await assert.async.isTrue(wrapper.update().find('GitTabView').prop('isMerging'));
      assert.notEqual(wrapper.find('GitTabView').prop('mergeConflicts').length, 0);
      assert.isOk(wrapper.find('GitTabView').prop('mergeMessage'));

      confirm.returns(0);
      await wrapper.instance().abortMerge();
      await updateWrapper(repository, wrapper);

      await assert.async.lengthOf(wrapper.update().find('GitTabView').prop('mergeConflicts'), 0);
      assert.isFalse(wrapper.find('GitTabView').prop('isMerging'));
      assert.isNull(wrapper.find('GitTabView').prop('mergeMessage'));
    });
  });

  describe('prepareToCommit', function() {
    it('shows the git panel and returns false if it was hidden', async function() {
      const workdirPath = await cloneRepository('three-files');
      const repository = await buildRepository(workdirPath);

      const ensureGitTab = () => Promise.resolve(true);
      const wrapper = mount(await buildApp(repository, {ensureGitTab}));

      assert.isFalse(await wrapper.instance().prepareToCommit());
    });

    it('returns true if the git panel was already visible', async function() {
      const workdirPath = await cloneRepository('three-files');
      const repository = await buildRepository(workdirPath);

      const ensureGitTab = () => Promise.resolve(false);
      const wrapper = mount(await buildApp(repository, {ensureGitTab}));

      assert.isTrue(await wrapper.instance().prepareToCommit());
    });
  });

  describe('commit(message)', function() {
    it('shows an error notification when committing throws an error', async function() {
      const workdirPath = await cloneRepository('three-files');
      const repository = await buildRepositoryWithPipeline(workdirPath, {confirm, notificationManager, workspace});
      sinon.stub(repository.git, 'commit').callsFake(async () => {
        await Promise.resolve();
        throw new GitError('message');
      });

      const wrapper = mount(await buildApp(repository));

      notificationManager.clear(); // clear out any notifications
      try {
        await wrapper.instance().commit();
      } catch (e) {
        assert(e, 'is error');
      }
      assert.equal(notificationManager.getNotifications().length, 1);
    });
  });

  describe('when a new author is added', function() {
    it('user store is updated', async function() {
      const workdirPath = await cloneRepository('three-files');
      const repository = await buildRepository(workdirPath);

      const wrapper = mount(await buildApp(repository));
      const coAuthors = [new Author('mona@lisa.com', 'Mona Lisa')];
      const newAuthor = new Author('hubot@github.com', 'Mr. Hubot');

      wrapper.instance().updateSelectedCoAuthors(coAuthors, newAuthor);

      assert.deepEqual(wrapper.state('selectedCoAuthors'), [...coAuthors, newAuthor]);
    });
  });

  it('selects an item by description', async function() {
    const workdirPath = await cloneRepository('three-files');
    const repository = await buildRepository(workdirPath);

    fs.writeFileSync(path.join(workdirPath, 'unstaged-1.txt'), 'This is an unstaged file.');
    fs.writeFileSync(path.join(workdirPath, 'unstaged-2.txt'), 'This is an unstaged file.');
    fs.writeFileSync(path.join(workdirPath, 'unstaged-3.txt'), 'This is an unstaged file.');
    repository.refresh();

    const wrapper = mount(await buildApp(repository));

    await assert.async.lengthOf(wrapper.update().find('GitTabView').prop('unstagedChanges'), 3);

    const controller = wrapper.instance();
    const stagingView = controller.refStagingView.get();

    sinon.spy(stagingView, 'setFocus');

    await controller.quietlySelectItem('unstaged-3.txt', 'unstaged');

    const selections0 = Array.from(stagingView.state.selection.getSelectedItems());
    assert.lengthOf(selections0, 1);
    assert.equal(selections0[0].filePath, 'unstaged-3.txt');

    assert.isFalse(stagingView.setFocus.called);

    await controller.focusAndSelectStagingItem('unstaged-2.txt', 'unstaged');

    const selections1 = Array.from(stagingView.state.selection.getSelectedItems());
    assert.lengthOf(selections1, 1);
    assert.equal(selections1[0].filePath, 'unstaged-2.txt');

    assert.equal(stagingView.setFocus.callCount, 1);
  });

  it('imperatively selects the commit preview button', async function() {
    const repository = await buildRepository(await cloneRepository('three-files'));
    const wrapper = mount(await buildApp(repository));

    const focusMethod = sinon.spy(wrapper.find('GitTabView').instance(), 'focusAndSelectCommitPreviewButton');
    wrapper.instance().focusAndSelectCommitPreviewButton();
    assert.isTrue(focusMethod.called);
  });

  it('imperatively selects the recent commit', async function() {
    const repository = await buildRepository(await cloneRepository('three-files'));
    const wrapper = mount(await buildApp(repository));

    const focusMethod = sinon.spy(wrapper.find('GitTabView').instance(), 'focusAndSelectRecentCommit');
    wrapper.instance().focusAndSelectRecentCommit();
    assert.isTrue(focusMethod.called);
  });

  describe('focus management', function() {
    it('remembers the last focus reported by the view', async function() {
      const repository = await buildRepository(await cloneRepository());
      const wrapper = mount(await buildApp(repository));
      const view = wrapper.instance().refView.get();
      const editorElement = wrapper.find('AtomTextEditor').getDOMNode().querySelector('atom-text-editor');
      const commitElement = wrapper.find('.github-CommitView-commit').getDOMNode();

      wrapper.instance().rememberLastFocus({target: editorElement});

      sinon.spy(view, 'setFocus');
      wrapper.instance().restoreFocus();
      assert.isTrue(view.setFocus.calledWith(GitTabController.focus.EDITOR));

      wrapper.instance().rememberLastFocus({target: commitElement});

      view.setFocus.resetHistory();
      wrapper.instance().restoreFocus();
      assert.isTrue(view.setFocus.calledWith(GitTabController.focus.COMMIT_BUTTON));

      wrapper.instance().rememberLastFocus({target: document.body});

      view.setFocus.resetHistory();
      wrapper.instance().restoreFocus();
      assert.isTrue(view.setFocus.calledWith(GitTabController.focus.STAGING));

      wrapper.instance().refView.setter(null);

      view.setFocus.resetHistory();
      wrapper.instance().restoreFocus();
      assert.isFalse(view.setFocus.called);
    });

    it('detects focus', async function() {
      const repository = await buildRepository(await cloneRepository());
      const wrapper = mount(await buildApp(repository));
      const rootElement = wrapper.instance().refRoot.get();
      sinon.stub(rootElement, 'contains');

      rootElement.contains.returns(true);
      assert.isTrue(wrapper.instance().hasFocus());

      rootElement.contains.returns(false);
      assert.isFalse(wrapper.instance().hasFocus());

      rootElement.contains.returns(true);
      wrapper.instance().refRoot.setter(null);
      assert.isFalse(wrapper.instance().hasFocus());
    });

    it('does nothing on an absent repository', async function() {
      const repository = Repository.absent();

      const wrapper = mount(await buildApp(repository));
      const controller = wrapper.instance();

      assert.isTrue(wrapper.find('.is-empty').exists());
      assert.lengthOf(wrapper.find('.no-repository'), 1);

      controller.rememberLastFocus({target: null});
      assert.strictEqual(controller.lastFocus, GitTabController.focus.STAGING);
    });
  });

  describe('integration tests', function() {
    it('can stage and unstage files and commit', async function() {
      const workdirPath = await cloneRepository('three-files');
      const repository = await buildRepository(workdirPath);
      fs.writeFileSync(path.join(workdirPath, 'a.txt'), 'a change\n');
      fs.unlinkSync(path.join(workdirPath, 'b.txt'));
      const ensureGitTab = () => Promise.resolve(false);

      const wrapper = mount(await buildApp(repository, {ensureGitTab}));

      await assert.async.lengthOf(wrapper.update().find('GitTabView').prop('unstagedChanges'), 2);

      const stagingView = wrapper.instance().refStagingView.get();
      const commitView = wrapper.find('CommitView');

      assert.lengthOf(stagingView.props.unstagedChanges, 2);
      assert.lengthOf(stagingView.props.stagedChanges, 0);

      await stagingView.dblclickOnItem({}, stagingView.props.unstagedChanges[0]).stageOperationPromise;
      await updateWrapper(repository, wrapper, {ensureGitTab});

      assert.lengthOf(stagingView.props.unstagedChanges, 1);
      assert.lengthOf(stagingView.props.stagedChanges, 1);

      await stagingView.dblclickOnItem({}, stagingView.props.unstagedChanges[0]).stageOperationPromise;
      await updateWrapper(repository, wrapper, {ensureGitTab});

      assert.lengthOf(stagingView.props.unstagedChanges, 0);
      assert.lengthOf(stagingView.props.stagedChanges, 2);

      await stagingView.dblclickOnItem({}, stagingView.props.stagedChanges[1]).stageOperationPromise;
      await updateWrapper(repository, wrapper, {ensureGitTab});

      assert.lengthOf(stagingView.props.unstagedChanges, 1);
      assert.lengthOf(stagingView.props.stagedChanges, 1);

      commitView.find('AtomTextEditor').instance().getModel().setText('Make it so');
      commitView.find('.github-CommitView-commit').simulate('click');

      await assert.async.strictEqual((await repository.getLastCommit()).getMessageSubject(), 'Make it so');
    });

    it('can stage merge conflict files', async function() {
      const workdirPath = await cloneRepository('merge-conflict');
      const repository = await buildRepository(workdirPath);

      await assert.isRejected(repository.git.merge('origin/branch'));

      const confirm = sinon.stub();
      const props = {confirm};
      const wrapper = mount(await buildApp(repository, props));

      assert.lengthOf(wrapper.find('GitTabView').prop('mergeConflicts'), 5);
      const stagingView = wrapper.instance().refStagingView.get();

      assert.equal(stagingView.props.mergeConflicts.length, 5);
      assert.equal(stagingView.props.stagedChanges.length, 0);

      const conflict1 = stagingView.props.mergeConflicts.filter(c => c.filePath === 'modified-on-both-ours.txt')[0];
      const contentsWithMarkers = fs.readFileSync(path.join(workdirPath, conflict1.filePath), {encoding: 'utf8'});
      assert.include(contentsWithMarkers, '>>>>>>>');
      assert.include(contentsWithMarkers, '<<<<<<<');

      // click Cancel
      confirm.returns(1);
      await stagingView.dblclickOnItem({}, conflict1).stageOperationPromise;
      await updateWrapper(repository, wrapper, props);

      assert.isTrue(confirm.calledOnce);
      assert.lengthOf(stagingView.props.mergeConflicts, 5);
      assert.lengthOf(stagingView.props.stagedChanges, 0);

      // click Stage
      confirm.reset();
      confirm.returns(0);
      await stagingView.dblclickOnItem({}, conflict1).stageOperationPromise;
      await updateWrapper(repository, wrapper, props);

      assert.isTrue(confirm.calledOnce);
      assert.lengthOf(stagingView.props.mergeConflicts, 4);
      assert.lengthOf(stagingView.props.stagedChanges, 1);

      // clear merge markers
      const conflict2 = stagingView.props.mergeConflicts.filter(c => c.filePath === 'modified-on-both-theirs.txt')[0];
      confirm.reset();
      fs.writeFileSync(path.join(workdirPath, conflict2.filePath), 'text with no merge markers');
      await stagingView.dblclickOnItem({}, conflict2).stageOperationPromise;
      await updateWrapper(repository, wrapper, props);

      assert.lengthOf(stagingView.props.mergeConflicts, 3);
      assert.lengthOf(stagingView.props.stagedChanges, 2);
      assert.isFalse(confirm.called);
    });

    it('avoids conflicts with pending file staging operations', async function() {
      const workdirPath = await cloneRepository('three-files');
      const repository = await buildRepository(workdirPath);
      fs.unlinkSync(path.join(workdirPath, 'a.txt'));
      fs.unlinkSync(path.join(workdirPath, 'b.txt'));

      const wrapper = mount(await buildApp(repository));

      const stagingView = wrapper.instance().refStagingView.get();
      assert.lengthOf(stagingView.props.unstagedChanges, 2);

      // ensure staging the same file twice does not cause issues
      // second stage action is a no-op since the first staging operation is in flight
      const file1StagingPromises = stagingView.confirmSelectedItems();
      stagingView.confirmSelectedItems();

      await file1StagingPromises.stageOperationPromise;
      await updateWrapper(repository, wrapper);

      assert.lengthOf(stagingView.props.unstagedChanges, 1);

      const file2StagingPromises = stagingView.confirmSelectedItems();
      await file2StagingPromises.stageOperationPromise;
      await updateWrapper(repository, wrapper);

      assert.lengthOf(stagingView.props.unstagedChanges, 0);
    });

    it('updates file status and paths when changed', async function() {
      const workdirPath = await cloneRepository('three-files');
      const repository = await buildRepository(workdirPath);
      fs.writeFileSync(path.join(workdirPath, 'new-file.txt'), 'foo\nbar\nbaz\n');

      const wrapper = mount(await buildApp(repository));

      const stagingView = wrapper.instance().refStagingView.get();
      assert.include(stagingView.props.unstagedChanges.map(c => c.filePath), 'new-file.txt');

      const [addedFilePatch] = stagingView.props.unstagedChanges;
      assert.equal(addedFilePatch.filePath, 'new-file.txt');
      assert.equal(addedFilePatch.status, 'added');

      const patchString = dedent`
        --- /dev/null
        +++ b/new-file.txt
        @@ -0,0 +1,1 @@
        +foo

      `;

      // partially stage contents in the newly added file
      await repository.git.applyPatch(patchString, {index: true});
      await updateWrapper(repository, wrapper);

      // since unstaged changes are calculated relative to the index,
      // which now has new-file.txt on it, the working directory version of
      // new-file.txt has a modified status
      const [modifiedFilePatch] = stagingView.props.unstagedChanges;
      assert.strictEqual(modifiedFilePatch.status, 'modified');
      assert.strictEqual(modifiedFilePatch.filePath, 'new-file.txt');
    });

    describe('amend', function() {
      let repository, commitMessage, workdirPath, wrapper;

      function getLastCommit() {
        return wrapper.find('RecentCommitView').at(0).prop('commit');
      }

      beforeEach(async function() {
        workdirPath = await cloneRepository('three-files');
        repository = await buildRepository(workdirPath);

        wrapper = mount(await buildApp(repository));

        commitMessage = 'most recent commit woohoo';
        fs.writeFileSync(path.join(workdirPath, 'foo.txt'), 'oh\nem\ngee\n');
        await repository.stageFiles(['foo.txt']);
        await repository.commit(commitMessage);
        await updateWrapper(repository, wrapper);

        assert.strictEqual(getLastCommit().getMessageSubject(), commitMessage);

        sinon.spy(repository, 'commit');
      });

      describe('when there are staged changes only', function() {
        it('uses the last commit\'s message since there is no new message', async function() {
          // stage some changes
          fs.writeFileSync(path.join(workdirPath, 'new-file.txt'), 'oh\nem\ngee\n');
          await repository.stageFiles(['new-file.txt']);
          await updateWrapper(repository, wrapper);
          assert.lengthOf(wrapper.find('GitTabView').prop('stagedChanges'), 1);

          // ensure that the commit editor is empty
          assert.strictEqual(
            wrapper.find('CommitView').instance().refEditorModel.map(e => e.getText()).getOr(undefined),
            '',
          );

          commands.dispatch(workspaceElement, 'github:amend-last-commit');
          await assert.async.deepEqual(
            repository.commit.args[0][1],
            {amend: true, coAuthors: [], verbatim: true},
          );

          // amending should commit all unstaged changes
          await updateWrapper(repository, wrapper);
          assert.lengthOf(wrapper.find('GitTabView').prop('stagedChanges'), 0);

          // commit message from previous commit should be used
          assert.equal(getLastCommit().getMessageSubject(), commitMessage);
        });
      });

      describe('when there is a new commit message provided (and no staged changes)', function() {
        it('discards the last commit\'s message and uses the new one', async function() {
          // new commit message
          const newMessage = 'such new very message';
          const commitView = wrapper.find('CommitView');
          commitView.instance().refEditorModel.map(e => e.setText(newMessage));

          // no staged changes
          assert.lengthOf(wrapper.find('GitTabView').prop('stagedChanges'), 0);

          commands.dispatch(workspaceElement, 'github:amend-last-commit');
          await assert.async.deepEqual(
            repository.commit.args[0][1],
            {amend: true, coAuthors: [], verbatim: true},
          );
          await updateWrapper(repository, wrapper);

          // new commit message is used
          assert.strictEqual(getLastCommit().getMessageSubject(), newMessage);
        });
      });

      describe('when co-authors are changed', function() {
        it('amends the last commit re-using the commit message and adding the co-author', async function() {
          // verify that last commit has no co-author
          const commitBeforeAmend = getLastCommit();
          assert.deepEqual(commitBeforeAmend.coAuthors, []);

          // add co author
          const author = new Author('foo@bar.com', 'foo bar');
          const commitView = wrapper.find('CommitView').instance();
          commitView.setState({showCoAuthorInput: true});
          commitView.onSelectedCoAuthorsChanged([author]);
          await updateWrapper(repository, wrapper);

          commands.dispatch(workspaceElement, 'github:amend-last-commit');
          // verify that coAuthor was passed
          await assert.async.deepEqual(
            repository.commit.args[0][1],
            {amend: true, coAuthors: [author], verbatim: true},
          );
          await repository.commit.returnValues[0];
          await updateWrapper(repository, wrapper);

          assert.deepEqual(getLastCommit().coAuthors, [author]);
          assert.strictEqual(getLastCommit().getMessageSubject(), commitBeforeAmend.getMessageSubject());
        });

        it('uses a new commit message if provided', async function() {
          // verify that last commit has no co-author
          const commitBeforeAmend = getLastCommit();
          assert.deepEqual(commitBeforeAmend.coAuthors, []);

          // add co author
          const author = new Author('foo@bar.com', 'foo bar');
          const commitView = wrapper.find('CommitView').instance();
          commitView.setState({showCoAuthorInput: true});
          commitView.onSelectedCoAuthorsChanged([author]);
          const newMessage = 'Star Wars: A New Message';
          commitView.refEditorModel.map(e => e.setText(newMessage));
          commands.dispatch(workspaceElement, 'github:amend-last-commit');

          // verify that coAuthor was passed
          await assert.async.deepEqual(
            repository.commit.args[0][1],
            {amend: true, coAuthors: [author], verbatim: true},
          );
          await repository.commit.returnValues[0];
          await updateWrapper(repository, wrapper);

          // verify that commit message has coauthor
          assert.deepEqual(getLastCommit().coAuthors, [author]);
          assert.strictEqual(getLastCommit().getMessageSubject(), newMessage);
        });

        it('successfully removes a co-author', async function() {
          const message = 'We did this together!';
          const author = new Author('mona@lisa.com', 'Mona Lisa');
          const commitMessageWithCoAuthors = dedent`
            ${message}

            Co-authored-by: ${author.getFullName()} <${author.getEmail()}>
          `;

          await repository.git.exec(['commit', '--amend', '-m', commitMessageWithCoAuthors]);
          await updateWrapper(repository, wrapper);

          // verify that commit message has coauthor
          assert.deepEqual(getLastCommit().coAuthors, [author]);
          assert.strictEqual(getLastCommit().getMessageSubject(), message);

          // buh bye co author
          const commitView = wrapper.find('CommitView').instance();
          assert.strictEqual(commitView.refEditorModel.map(e => e.getText()).getOr(''), '');
          commitView.onSelectedCoAuthorsChanged([]);

          // amend again
          commands.dispatch(workspaceElement, 'github:amend-last-commit');
          // verify that NO coAuthor was passed
          await assert.async.deepEqual(
            repository.commit.args[0][1],
            {amend: true, coAuthors: [], verbatim: true},
          );
          await repository.commit.returnValues[0];
          await updateWrapper(repository, wrapper);

          // assert that no co-authors are in last commit
          assert.deepEqual(getLastCommit().coAuthors, []);
          assert.strictEqual(getLastCommit().getMessageSubject(), message);
        });
      });
    });

    describe('undoLastCommit()', function() {
      it('does nothing when there are no commits', async function() {
        const workdirPath = await initRepository();
        const repository = await buildRepository(workdirPath);

        const wrapper = mount(await buildApp(repository));
        await assert.isFulfilled(wrapper.instance().undoLastCommit());
      });

      it('restores to the state prior to committing', async function() {
        const workdirPath = await cloneRepository('three-files');
        const repository = await buildRepository(workdirPath);
        sinon.spy(repository, 'undoLastCommit');
        fs.writeFileSync(path.join(workdirPath, 'new-file.txt'), 'foo\nbar\nbaz\n');
        const coAuthorName = 'Janelle Monae';
        const coAuthorEmail = 'janellemonae@github.com';

        await repository.stageFiles(['new-file.txt']);
        const commitSubject = 'Commit some stuff';
        const commitMessage = dedent`
          ${commitSubject}

          Co-authored-by: ${coAuthorName} <${coAuthorEmail}>
        `;
        await repository.commit(commitMessage);

        const wrapper = mount(await buildApp(repository));

        assert.deepEqual(wrapper.find('CommitView').prop('selectedCoAuthors'), []);
        // ensure that the co author trailer is stripped from commit message
        let commitMessages = wrapper.find('.github-RecentCommit-message').map(node => node.text());
        assert.deepEqual(commitMessages, [commitSubject, 'Initial commit']);

        assert.lengthOf(wrapper.find('.github-RecentCommit-undoButton'), 1);
        wrapper.find('.github-RecentCommit-undoButton').simulate('click');
        await assert.async.isTrue(repository.undoLastCommit.called);
        await repository.undoLastCommit.returnValues[0];
        await updateWrapper(repository, wrapper);

        assert.lengthOf(wrapper.find('GitTabView').prop('stagedChanges'), 1);
        assert.deepEqual(wrapper.find('GitTabView').prop('stagedChanges'), [{
          filePath: 'new-file.txt',
          status: 'added',
        }]);

        commitMessages = wrapper.find('.github-RecentCommit-message').map(node => node.text());
        assert.deepEqual(commitMessages, ['Initial commit']);

        const expectedCoAuthor = new Author(coAuthorEmail, coAuthorName);
        assert.strictEqual(wrapper.find('CommitView').prop('messageBuffer').getText(), commitSubject);
        assert.deepEqual(wrapper.find('CommitView').prop('selectedCoAuthors'), [expectedCoAuthor]);
      });
    });
  });
});
