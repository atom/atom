import {TextBuffer} from 'atom';
import React from 'react';
import {shallow, mount} from 'enzyme';

import Author from '../../lib/models/author';
import CoAuthorForm from '../../lib/views/co-author-form';
import {cloneRepository, buildRepository} from '../helpers';
import Commit, {nullCommit} from '../../lib/models/commit';
import Branch, {nullBranch} from '../../lib/models/branch';
import ObserveModel from '../../lib/views/observe-model';
import UserStore from '../../lib/models/user-store';
import CommitView from '../../lib/views/commit-view';
import RecentCommitsView from '../../lib/views/recent-commits-view';
import StagingView from '../../lib/views/staging-view';
import * as reporterProxy from '../../lib/reporter-proxy';

describe('CommitView', function() {
  let atomEnv, commands, tooltips, config, lastCommit;
  let messageBuffer;
  let app;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    commands = atomEnv.commands;
    tooltips = atomEnv.tooltips;
    config = atomEnv.config;

    lastCommit = new Commit({sha: '1234abcd', message: 'commit message'});
    const noop = () => {};
    const returnTruthyPromise = () => Promise.resolve(true);
    const store = new UserStore({config});

    messageBuffer = new TextBuffer();

    app = (
      <CommitView
        workspace={atomEnv.workspace}
        commands={commands}
        tooltips={tooltips}
        config={config}
        lastCommit={lastCommit}
        userStore={store}
        currentBranch={nullBranch}
        isMerging={false}
        stagedChangesExist={false}
        mergeConflictsExist={false}
        isCommitting={false}
        commitPreviewActive={false}
        deactivateCommitBox={false}
        maximumCharacterLimit={72}
        messageBuffer={messageBuffer}
        prepareToCommit={returnTruthyPromise}
        commit={noop}
        abortMerge={noop}
        toggleExpandedCommitMessageEditor={noop}
        updateSelectedCoAuthors={noop}
        toggleCommitPreview={noop}
        activateCommitPreview={noop}
      />
    );
  });

  afterEach(function() {
    atomEnv.destroy();
  });
  describe('amend', function() {
    it('increments a counter when amend is called', function() {
      messageBuffer.setText('yo dawg I heard you like amending');
      const wrapper = shallow(app);
      sinon.stub(reporterProxy, 'incrementCounter');
      wrapper.instance().amendLastCommit();

      assert.equal(reporterProxy.incrementCounter.callCount, 1);
    });
  });

  describe('coauthor stuff', function() {
    let wrapper, incrementCounterStub;
    beforeEach(function() {
      wrapper = shallow(app);
      incrementCounterStub = sinon.stub(reporterProxy, 'incrementCounter');
    });
    it('on initial load, renders co-author toggle but not input or form', function() {
      const coAuthorButton = wrapper.find('.github-CommitView-coAuthorToggle');
      assert.deepEqual(coAuthorButton.length, 1);
      assert.isFalse(coAuthorButton.hasClass('focused'));

      const coAuthorInput = wrapper.find('github-CommitView-coAuthorEditor');
      assert.deepEqual(coAuthorInput.length, 0);

      const coAuthorForm = wrapper.find(CoAuthorForm);
      assert.deepEqual(coAuthorForm.length, 0);

      assert.isFalse(incrementCounterStub.called);
    });
    it('renders co-author input when toggle is clicked', function() {
      const coAuthorButton = wrapper.find('.github-CommitView-coAuthorToggle');
      coAuthorButton.simulate('click');

      const coAuthorInput = wrapper.find(ObserveModel);
      assert.deepEqual(coAuthorInput.length, 1);
      assert.isTrue(incrementCounterStub.calledOnce);
      assert.deepEqual(incrementCounterStub.lastCall.args, ['show-co-author-input']);
    });
    it('hides co-author input when toggle is clicked twice', function() {
      const coAuthorButton = wrapper.find('.github-CommitView-coAuthorToggle');
      coAuthorButton.simulate('click');
      coAuthorButton.simulate('click');

      const coAuthorInput = wrapper.find(ObserveModel);
      assert.deepEqual(coAuthorInput.length, 0);
      assert.isTrue(incrementCounterStub.calledTwice);
      assert.deepEqual(incrementCounterStub.lastCall.args, ['hide-co-author-input']);
    });
    it('renders co-author form when a new co-author is added', function() {
      const coAuthorButton = wrapper.find('.github-CommitView-coAuthorToggle');
      coAuthorButton.simulate('click');

      const newAuthor = Author.createNew('pizza@unicorn.party', 'Pizza Unicorn');
      wrapper.instance().onSelectedCoAuthorsChanged([newAuthor]);
      wrapper.update();

      const coAuthorForm = wrapper.find(CoAuthorForm);
      assert.deepEqual(coAuthorForm.length, 1);

      assert.isTrue(incrementCounterStub.calledTwice);
      assert.deepEqual(incrementCounterStub.lastCall.args, ['selected-co-authors-changed']);
    });

  });

  describe('when the repo is loading', function() {
    beforeEach(function() {
      app = React.cloneElement(app, {lastCommit: nullCommit});
    });

    it('disables the commit button', function() {
      messageBuffer.setText('even with text');
      const wrapper = shallow(app);

      assert.isTrue(wrapper.find('.github-CommitView-commit').prop('disabled'));
    });
  });

  it('displays the remaining characters limit based on which line is being edited', function() {
    const wrapper = mount(app);
    assert.strictEqual(wrapper.find('.github-CommitView-remaining-characters').text(), '72');

    messageBuffer.setText('abcde fghij');
    assert.strictEqual(wrapper.find('.github-CommitView-remaining-characters').text(), '61');
    assert.isFalse(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-error'));
    assert.isFalse(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-warning'));

    messageBuffer.setText('\nklmno');
    assert.strictEqual(wrapper.find('.github-CommitView-remaining-characters').text(), '∞');
    assert.isFalse(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-error'));
    assert.isFalse(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-warning'));

    messageBuffer.setText('abcde\npqrst');
    assert.strictEqual(wrapper.find('.github-CommitView-remaining-characters').text(), '∞');
    assert.isFalse(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-error'));
    assert.isFalse(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-warning'));

    wrapper.find('AtomTextEditor').instance().getModel().setCursorBufferPosition([0, 3]);
    assert.strictEqual(wrapper.find('.github-CommitView-remaining-characters').text(), '67');
    assert.isFalse(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-error'));
    assert.isFalse(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-warning'));

    wrapper.setProps({stagedChangesExist: true, maximumCharacterLimit: 50});
    assert.strictEqual(wrapper.find('.github-CommitView-remaining-characters').text(), '45');
    assert.isFalse(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-error'));
    assert.isFalse(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-warning'));

    messageBuffer.setText('a'.repeat(41));
    wrapper.update();
    assert.strictEqual(wrapper.find('.github-CommitView-remaining-characters').text(), '9');
    assert.isFalse(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-error'));
    assert.isTrue(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-warning'));

    messageBuffer.setText('a'.repeat(58));
    wrapper.update();
    assert.strictEqual(wrapper.find('.github-CommitView-remaining-characters').text(), '-8');
    assert.isTrue(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-error'));
    assert.isFalse(wrapper.find('.github-CommitView-remaining-characters').hasClass('is-warning'));
  });

  describe('the commit button', function() {
    let wrapper;

    beforeEach(async function() {
      const workdirPath = await cloneRepository('three-files');
      const repository = await buildRepository(workdirPath);

      messageBuffer.setText('something');
      app = React.cloneElement(app, {
        repository,
        stagedChangesExist: true,
        mergeConflictsExist: false,
      });
      wrapper = mount(app);
    });

    it('is disabled when no changes are staged', function() {
      wrapper.setProps({stagedChangesExist: false});
      assert.isTrue(wrapper.find('.github-CommitView-commit').prop('disabled'));

      wrapper.setProps({stagedChangesExist: true});
      assert.isFalse(wrapper.find('.github-CommitView-commit').prop('disabled'));
    });

    it('is disabled when there are merge conflicts', function() {
      wrapper.setProps({mergeConflictsExist: true});
      assert.isTrue(wrapper.find('.github-CommitView-commit').prop('disabled'));

      wrapper.setProps({mergeConflictsExist: false});
      assert.isFalse(wrapper.find('.github-CommitView-commit').prop('disabled'));
    });

    it('is disabled when the commit message is empty', function() {
      messageBuffer.setText('');
      wrapper.update();
      assert.isTrue(wrapper.find('.github-CommitView-commit').prop('disabled'));

      messageBuffer.setText('Not empty');
      wrapper.update();
      assert.isFalse(wrapper.find('.github-CommitView-commit').prop('disabled'));
    });

    it('displays the current branch name', function() {
      const currentBranch = new Branch('aw-do-the-stuff');
      wrapper.setProps({currentBranch});
      assert.strictEqual(wrapper.find('.github-CommitView-commit').text(), 'Commit to aw-do-the-stuff');
    });

    it('indicates when a commit will be detached', function() {
      const currentBranch = Branch.createDetached('master~3');
      wrapper.setProps({currentBranch});
      assert.strictEqual(wrapper.find('.github-CommitView-commit').text(), 'Create detached commit');
    });

    it('displays a progress message while committing', function() {
      wrapper.setState({showWorking: true});
      assert.strictEqual(wrapper.find('.github-CommitView-commit').text(), 'Working...');
    });

    it('falls back to "commit" with no current branch', function() {
      assert.strictEqual(wrapper.find('.github-CommitView-commit').text(), 'Commit');
    });
  });

  describe('committing', function() {
    let commit, prepareToCommitResolution;
    let wrapper, editorElement, editor, commitButton, workspaceElement;

    beforeEach(function() {
      const prepareToCommit = () => Promise.resolve(prepareToCommitResolution);

      commit = sinon.spy();
      messageBuffer.setText('Something');
      app = React.cloneElement(app, {stagedChangesExist: true, prepareToCommit, commit});
      wrapper = mount(app);

      editorElement = wrapper.find('AtomTextEditor').getDOMNode().querySelector('atom-text-editor');
      sinon.spy(editorElement, 'focus');
      editor = editorElement.getModel();

      // Perform an extra render to ensure the editor text is reflected in the commit button enablement.
      // The controller accomplishes this by re-rendering on Repository update.
      wrapper.setProps({});

      commitButton = wrapper.find('.github-CommitView-commit');
      workspaceElement = atomEnv.views.getView(atomEnv.workspace);
    });

    describe('when props.prepareToCommit() resolves true', function() {
      beforeEach(function() {
        prepareToCommitResolution = true;
      });

      it('calls props.commit(message) when the commit button is clicked', async function() {
        wrapper.update();
        commitButton.simulate('click');

        await assert.async.isTrue(commit.calledWith('Something'));

        // undo history is cleared
        commands.dispatch(editorElement, 'core:undo');
        assert.equal(editor.getText(), '');
      });

      it('calls props.commit(message) when github:commit is dispatched', async function() {
        commands.dispatch(workspaceElement, 'github:commit');

        await assert.async.isTrue(commit.calledWith('Something'));
      });
    });

    describe('when props.prepareToCommit() resolves false', function() {
      beforeEach(function() {
        prepareToCommitResolution = false;
      });

      it('takes no further action when the commit button is clicked', async function() {
        commitButton.simulate('click');

        await assert.async.isTrue(editorElement.focus.called);
        assert.isFalse(commit.called);
      });

      it('takes no further action when github:commit is dispatched', async function() {
        commands.dispatch(workspaceElement, 'github:commit');

        await assert.async.isTrue(editorElement.focus.called);
        assert.isFalse(commit.called);
      });
    });
  });

  it('shows the "Abort Merge" button when props.isMerging is true', function() {
    app = React.cloneElement(app, {isMerging: true});
    const wrapper = shallow(app);
    assert.isTrue(wrapper.find('.github-CommitView-abortMerge').exists());

    wrapper.setProps({isMerging: false});
    assert.isFalse(wrapper.find('.github-CommitView-abortMerge').exists());
  });

  it('calls props.abortMerge() when the "Abort Merge" button is clicked', function() {
    const abortMerge = sinon.stub().resolves();
    app = React.cloneElement(app, {abortMerge, stagedChangesExist: true, isMerging: true});
    const wrapper = shallow(app);

    wrapper.find('.github-CommitView-abortMerge').simulate('click');
    assert.isTrue(abortMerge.calledOnce);
  });

  it('detects when the component has focus', function() {
    const wrapper = mount(app);
    const rootElement = wrapper.find('.github-CommitView').getDOMNode();

    sinon.stub(rootElement, 'contains').returns(true);
    assert.isTrue(wrapper.instance().hasFocus());

    rootElement.contains.returns(false);
    assert.isFalse(wrapper.instance().hasFocus());

    rootElement.contains.returns(true);
    wrapper.instance().refRoot.setter(null);
    assert.isFalse(wrapper.instance().hasFocus());
  });

  describe('advancing focus', function() {
    let wrapper, instance;

    beforeEach(function() {
      wrapper = mount(app);
      instance = wrapper.instance();
    });

    it('returns null if the focus is not in the commit view', async function() {
      assert.isNull(await instance.advanceFocusFrom(StagingView.focus.STAGING));
    });

    it('moves focus to the commit editor if the commit preview button is focused', async function() {
      assert.strictEqual(
        await instance.advanceFocusFrom(CommitView.focus.COMMIT_PREVIEW_BUTTON),
        CommitView.focus.EDITOR,
      );
    });

    it('moves focus to the RecentCommitsView if the commit editor is focused', async function() {
      wrapper.setProps({isCommitting: true});
      assert.strictEqual(
        await instance.advanceFocusFrom(CommitView.focus.EDITOR),
        RecentCommitsView.firstFocus,
      );
    });

    it('moves focus to the commit button if the commit editor is focused and the button is enabled', async function() {
      sinon.stub(instance, 'commitIsEnabled').returns(true);
      assert.strictEqual(
        await instance.advanceFocusFrom(CommitView.focus.EDITOR),
        CommitView.focus.COMMIT_BUTTON,
      );
    });

    it('moves focus to the coauthor input if the commit editor is focused and the coauthor input is open', async function() {
      wrapper.setState({showCoAuthorInput: true});
      assert.strictEqual(
        await instance.advanceFocusFrom(CommitView.focus.EDITOR),
        CommitView.focus.COAUTHOR_INPUT,
      );
    });

    it('moves focus to the abort merge button if the commit editor is focused and a merge is in progress', async function() {
      wrapper.setProps({isMerging: true});
      assert.strictEqual(
        await instance.advanceFocusFrom(CommitView.focus.EDITOR),
        CommitView.focus.ABORT_MERGE_BUTTON,
      );
    });

    it('moves focus to the RecentCommitsView if the coauthor input is focused and no merge is in progress', async function() {
      assert.strictEqual(
        await instance.advanceFocusFrom(CommitView.focus.COAUTHOR_INPUT),
        RecentCommitsView.firstFocus,
      );
    });

    it('moves focus to the commit button if the coauthor input is focused, no merge is in progress, and the button is enabled', async function() {
      sinon.stub(instance, 'commitIsEnabled').returns(true);
      assert.strictEqual(
        await instance.advanceFocusFrom(CommitView.focus.COAUTHOR_INPUT),
        CommitView.focus.COMMIT_BUTTON,
      );
    });

    it('moves focus to the abort merge button if the coauthor form is focused and a merge is in progress', async function() {
      wrapper.setProps({isMerging: true});
      assert.strictEqual(
        await instance.advanceFocusFrom(CommitView.focus.COAUTHOR_INPUT),
        CommitView.focus.ABORT_MERGE_BUTTON,
      );
    });

    it('moves focus to the RecentCommitsView if the abort merge button is focused', async function() {
      assert.strictEqual(
        await instance.advanceFocusFrom(CommitView.focus.ABORT_MERGE_BUTTON),
        RecentCommitsView.firstFocus,
      );
    });

    it('moves focus to the commit button if the abort merge button is focused and the commit button is enabled', async function() {
      sinon.stub(instance, 'commitIsEnabled').returns(true);
      assert.strictEqual(
        await instance.advanceFocusFrom(CommitView.focus.ABORT_MERGE_BUTTON),
        CommitView.focus.COMMIT_BUTTON,
      );
    });

    it('moves focus to the RecentCommitsView if the commit button is focused', async function() {
      assert.strictEqual(
        await instance.advanceFocusFrom(CommitView.focus.COMMIT_BUTTON),
        RecentCommitsView.firstFocus,
      );
    });
  });

  describe('retreating focus', function() {
    let wrapper, instance;

    beforeEach(function() {
      wrapper = mount(app);
      instance = wrapper.instance();
    });

    it('returns null if the focus is not in the commit view', async function() {
      assert.isNull(await instance.retreatFocusFrom(RecentCommitsView.RECENT_COMMIT));
    });

    it('moves focus to the abort merge button if the commit button is focused and a merge is in progress', async function() {
      wrapper.setProps({isMerging: true});
      assert.strictEqual(
        await instance.retreatFocusFrom(CommitView.focus.COMMIT_BUTTON),
        CommitView.focus.ABORT_MERGE_BUTTON,
      );
    });

    it('moves focus to the editor if the commit button is focused and no merge is underway', async function() {
      assert.strictEqual(
        await instance.retreatFocusFrom(CommitView.focus.COMMIT_BUTTON),
        CommitView.focus.EDITOR,
      );
    });

    it('moves focus to the co-author input if it is visible, the commit button is focused, and no merge', async function() {
      wrapper.setState({showCoAuthorInput: true});
      assert.strictEqual(
        await instance.retreatFocusFrom(CommitView.focus.COMMIT_BUTTON),
        CommitView.focus.COAUTHOR_INPUT,
      );
    });

    it('moves focus to the co-author input if it is visible and the abort merge button is in focus', async function() {
      wrapper.setState({showCoAuthorInput: true});
      assert.strictEqual(
        await instance.retreatFocusFrom(CommitView.focus.ABORT_MERGE_BUTTON),
        CommitView.focus.COAUTHOR_INPUT,
      );
    });

    it('moves focus to the commit editor if the abort merge button is in focus', async function() {
      assert.strictEqual(
        await instance.retreatFocusFrom(CommitView.focus.ABORT_MERGE_BUTTON),
        CommitView.focus.EDITOR,
      );
    });

    it('moves focus to the commit editor if the co-author form is focused', async function() {
      assert.strictEqual(
        await instance.retreatFocusFrom(CommitView.focus.COAUTHOR_INPUT),
        CommitView.focus.EDITOR,
      );
    });

    it('moves focus to the commit preview button if the commit editor is focused', async function() {
      assert.strictEqual(
        await instance.retreatFocusFrom(CommitView.focus.EDITOR),
        CommitView.focus.COMMIT_PREVIEW_BUTTON,
      );
    });

    it('moves focus to the StagingView if the commit preview button is focused', async function() {
      assert.strictEqual(
        await instance.retreatFocusFrom(CommitView.focus.COMMIT_PREVIEW_BUTTON),
        StagingView.lastFocus,
      );
    });
  });

  it('gets the current focus', function() {
    const wrapper = mount(React.cloneElement(app, {isMerging: true}));
    wrapper.instance().toggleCoAuthorInput();
    wrapper.update();

    const foci = [
      ['AtomTextEditor', CommitView.focus.EDITOR, 'atom-text-editor'],
      ['.github-CommitView-abortMerge', CommitView.focus.ABORT_MERGE_BUTTON],
      ['.github-CommitView-commit', CommitView.focus.COMMIT_BUTTON],
      ['.github-CommitView-coAuthorEditor input', CommitView.focus.COAUTHOR_INPUT],
      ['.github-CommitView-commitPreview', CommitView.focus.COMMIT_PREVIEW_BUTTON],
    ];
    for (const [selector, focus, subselector] of foci) {
      let target = wrapper.find(selector).getDOMNode();
      if (subselector) {
        target = target.querySelector(subselector);
      }
      assert.strictEqual(wrapper.instance().getFocus(target), focus);
    }

    assert.isNull(wrapper.instance().getFocus(document.body));

    const holders = [
      'refEditorComponent', 'refEditorModel', 'refAbortMergeButton', 'refCommitButton', 'refCoAuthorSelect',
      'refCommitPreviewButton',
    ].map(ivar => wrapper.instance()[ivar]);
    for (const holder of holders) {
      holder.setter(null);
    }
    assert.isNull(wrapper.instance().getFocus({target: document.body}));
  });

  describe('restoring focus', function() {
    it('to the commit preview button', function() {
      const wrapper = mount(app);
      const element = wrapper.find('.github-CommitView-commitPreview').getDOMNode();
      sinon.spy(element, 'focus');

      assert.isTrue(wrapper.instance().setFocus(CommitView.focus.COMMIT_PREVIEW_BUTTON));
      assert.isTrue(element.focus.called);
    });

    it('to the editor', function() {
      const wrapper = mount(app);
      const element = wrapper.find('AtomTextEditor').getDOMNode().querySelector('atom-text-editor');
      sinon.spy(element, 'focus');

      assert.isTrue(wrapper.instance().setFocus(CommitView.focus.EDITOR));
      assert.isTrue(element.focus.called);
    });

    it('to the editor when a template is present', function() {
      messageBuffer.setText('# Template text here');

      const wrapper = mount(app);
      const element = wrapper.find('AtomTextEditor').getDOMNode().querySelector('atom-text-editor');
      sinon.spy(element, 'focus');

      assert.isTrue(wrapper.instance().setFocus(CommitView.focus.EDITOR));
      assert.isTrue(element.focus.called);
      assert.deepEqual(
        element.getModel().getCursorBufferPositions().map(p => p.serialize()),
        [[0, 0]],
      );
    });

    it('to the abort merge button', function() {
      const wrapper = mount(React.cloneElement(app, {isMerging: true}));
      sinon.spy(wrapper.find('.github-CommitView-abortMerge').getDOMNode(), 'focus');

      assert.isTrue(wrapper.instance().setFocus(CommitView.focus.ABORT_MERGE_BUTTON));
      assert.isTrue(wrapper.find('.github-CommitView-abortMerge').getDOMNode().focus.called);
    });

    it('to the commit button', function() {
      const wrapper = mount(app);
      sinon.spy(wrapper.find('.github-CommitView-commit').getDOMNode(), 'focus');

      assert.isTrue(wrapper.instance().setFocus(CommitView.focus.COMMIT_BUTTON));
      assert.isTrue(wrapper.find('.github-CommitView-commit').getDOMNode().focus.called);
    });

    it('to the co-author input', function() {
      const wrapper = mount(app);
      wrapper.instance().toggleCoAuthorInput();

      sinon.spy(wrapper.update().find('.github-CommitView-coAuthorEditor input').getDOMNode(), 'focus');

      assert.isTrue(wrapper.instance().setFocus(CommitView.focus.COAUTHOR_INPUT));
      assert.isTrue(wrapper.find('.github-CommitView-coAuthorEditor input').getDOMNode().focus.called);
    });

    it("to the last element when it's the commit button", function() {
      messageBuffer.setText('non-empty');
      const wrapper = mount(React.cloneElement(app, {stagedChangesExist: true}));
      sinon.spy(wrapper.find('.github-CommitView-commit').getDOMNode(), 'focus');

      assert.isTrue(wrapper.instance().setFocus(CommitView.lastFocus));
      assert.isTrue(wrapper.find('.github-CommitView-commit').getDOMNode().focus.called);
    });

    it("to the last element when it's the abort merge button", function() {
      const wrapper = mount(React.cloneElement(app, {isMerging: true}));
      sinon.spy(wrapper.find('.github-CommitView-abortMerge').getDOMNode(), 'focus');

      assert.isTrue(wrapper.instance().setFocus(CommitView.lastFocus));
      assert.isTrue(wrapper.find('.github-CommitView-abortMerge').getDOMNode().focus.called);
    });

    it("to the last element when it's the coauthor input", function() {
      const wrapper = mount(app);
      wrapper.instance().toggleCoAuthorInput();

      sinon.spy(wrapper.update().find('.github-CommitView-coAuthorEditor input').getDOMNode(), 'focus');

      assert.isTrue(wrapper.instance().setFocus(CommitView.lastFocus));
      assert.isTrue(wrapper.find('.github-CommitView-coAuthorEditor input').getDOMNode().focus.called);
    });

    it("to the last element when it's the editor", function() {
      const wrapper = mount(app);
      const element = wrapper.find('AtomTextEditor').getDOMNode().querySelector('atom-text-editor');
      sinon.spy(element, 'focus');

      assert.isTrue(wrapper.instance().setFocus(CommitView.lastFocus));
      assert.isTrue(element.focus.called);
    });

    it('with an unrecognized symbol', function() {
      const wrapper = mount(app);
      assert.isFalse(wrapper.instance().setFocus(Symbol('lolno')));
    });

    it('when the named element is no longer rendered', function() {
      const wrapper = mount(app);
      const element = wrapper.find('AtomTextEditor').getDOMNode().querySelector('atom-text-editor');
      sinon.spy(element, 'focus');

      assert.isTrue(wrapper.instance().setFocus(CommitView.focus.ABORT_MERGE_BUTTON));
      assert.strictEqual(element.focus.callCount, 1);

      assert.isTrue(wrapper.instance().setFocus(CommitView.focus.COAUTHOR_INPUT));
      assert.strictEqual(element.focus.callCount, 2);
    });

    it('when refs have not been assigned yet', function() {
      const wrapper = mount(app);

      // Simulate an unmounted component by clearing out RefHolders manually.
      const holders = [
        'refEditorComponent', 'refEditorModel', 'refAbortMergeButton', 'refCommitButton', 'refCoAuthorSelect',
        'refCommitPreviewButton',
      ].map(ivar => wrapper.instance()[ivar]);
      for (const holder of holders) {
        holder.setter(null);
      }

      for (const focusKey of Object.keys(CommitView.focus)) {
        assert.isFalse(wrapper.instance().setFocus(CommitView.focus[focusKey]));
      }
    });
  });

  describe('commit preview button', function() {
    it('is enabled when there is staged changes', function() {
      const wrapper = shallow(React.cloneElement(app, {
        stagedChangesExist: true,
      }));
      assert.isFalse(wrapper.find('.github-CommitView-commitPreview').prop('disabled'));
    });

    it('is disabled when there\'s no staged changes', function() {
      const wrapper = shallow(React.cloneElement(app, {
        stagedChangesExist: false,
      }));
      assert.isTrue(wrapper.find('.github-CommitView-commitPreview').prop('disabled'));
    });

    it('calls a callback when the button is clicked', function() {
      const toggleCommitPreview = sinon.spy();

      const wrapper = shallow(React.cloneElement(app, {
        toggleCommitPreview,
        stagedChangesExist: true,
      }));

      wrapper.find('.github-CommitView-commitPreview').simulate('click');
      assert.isTrue(toggleCommitPreview.called);
    });

    it('displays correct button text depending on prop value', function() {
      const wrapper = shallow(app);

      assert.strictEqual(wrapper.find('.github-CommitView-commitPreview').text(), 'See All Staged Changes');

      wrapper.setProps({commitPreviewActive: true});
      assert.strictEqual(wrapper.find('.github-CommitView-commitPreview').text(), 'Hide All Staged Changes');

      wrapper.setProps({commitPreviewActive: false});
      assert.strictEqual(wrapper.find('.github-CommitView-commitPreview').text(), 'See All Staged Changes');
    });
  });
});
