import fs from 'fs-extra';
import temp from 'temp';
import path from 'path';
import React from 'react';
import {mount} from 'enzyme';

import ResolutionProgress from '../../lib/models/conflicts/resolution-progress';
import {OURS, BASE, THEIRS} from '../../lib/models/conflicts/source';
import EditorConflictController from '../../lib/controllers/editor-conflict-controller';
import ConflictController from '../../lib/controllers/conflict-controller';

const onlyTwoMarkers = `This is some text before the marking.

More text.

<<<<<<< HEAD
My changes
Multi-line even
=======
Your changes
>>>>>>> other-branch

In between.

<<<<<<< HEAD
More of my changes
=======
More of your changes
>>>>>>> other-branch

Stuff at the very end.`;

describe('EditorConflictController', function() {
  let atomEnv, workspace, commands, app, wrapper, editor, editorView;
  let resolutionProgress, refreshResolutionProgress;
  let fixtureFile;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    workspace = atomEnv.workspace;
    commands = atomEnv.commands;

    refreshResolutionProgress = sinon.spy();
    resolutionProgress = new ResolutionProgress();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  const useFixture = async function(fixtureName, {isRebase} = {isRebase: false}) {
    const fixturePath = path.join(
      path.dirname(__filename), '..', 'fixtures', 'conflict-marker-examples', fixtureName);
    const tempDir = temp.mkdirSync('conflict-fixture-');
    fixtureFile = path.join(tempDir, fixtureName);
    fs.copySync(fixturePath, fixtureFile);

    editor = await workspace.open(fixtureFile);
    editorView = atomEnv.views.getView(editor);

    app = (
      <EditorConflictController
        workspace={workspace}
        commands={commands}
        editor={editor}
        resolutionProgress={resolutionProgress}
        refreshResolutionProgress={refreshResolutionProgress}
        isRebase={isRebase}
      />
    );
    wrapper = mount(app);
  };

  const textFromSide = function(side) {
    return editor.getTextInBufferRange(side.marker.getBufferRange());
  };

  describe('on a file with 2-way diff markers', function() {
    let conflicts;

    beforeEach(async function() {
      await useFixture('triple-2way-diff.txt');

      conflicts = Array.from(wrapper.state('conflicts'));
    });

    it('creates a Conflict from each conflict marker', function() {
      assert.lengthOf(conflicts, 3);

      assert.equal(textFromSide(conflicts[0].getSide(OURS)), 'My changes\nMulti-line even\n');
      assert.equal(textFromSide(conflicts[0].separator), '=======\n');
      assert.equal(textFromSide(conflicts[0].getSide(THEIRS)), 'Your changes\n');

      assert.equal(textFromSide(conflicts[1].getSide(OURS)), 'My middle changes\n');
      assert.equal(textFromSide(conflicts[1].separator), '=======\n');
      assert.equal(textFromSide(conflicts[1].getSide(THEIRS)), 'Your middle changes\n');

      assert.equal(textFromSide(conflicts[2].getSide(OURS)), 'More of my changes\n');
      assert.equal(textFromSide(conflicts[2].separator), '=======\n');
      assert.equal(textFromSide(conflicts[2].getSide(THEIRS)), '');
    });

    it('renders a ConflictController for each Conflict', function() {
      const conflictControllers = wrapper.find(ConflictController);
      assert.lengthOf(conflictControllers, conflicts.length);

      conflicts.forEach(conflict => {
        assert.isTrue(conflictControllers.someWhere(cc => cc.prop('conflict') === conflict));
      });
    });

    it('reports the unresolved conflict count on render', function() {
      assert.equal(resolutionProgress.getRemaining(editor.getPath()), 3);
    });

    it('resolves a conflict as "ours"', function() {
      const conflict = conflicts[1];
      assert.isFalse(conflict.isResolved());

      editor.setCursorBufferPosition([16, 6]); // On "Your middle changes"
      commands.dispatch(editorView, 'github:resolve-as-ours');

      assert.isTrue(conflict.isResolved());
      assert.strictEqual(conflict.getChosenSide(), conflict.getSide(OURS));
      assert.deepEqual(conflict.getUnchosenSides(), [conflict.getSide(THEIRS)]);

      assert.include(editor.getText(), 'Text in between 0 and 1.\n\nMy middle changes\n\nText in between 1 and 2.');
    });

    it('resolves a conflict as "theirs"', function() {
      const conflict = conflicts[1];

      editor.setCursorBufferPosition([14, 1]); // On "My middle changes"
      commands.dispatch(editorView, 'github:resolve-as-theirs');

      assert.isTrue(conflict.isResolved());
      assert.strictEqual(conflict.getChosenSide(), conflict.getSide(THEIRS));
      assert.deepEqual(conflict.getUnchosenSides(), [conflict.getSide(OURS)]);

      assert.include(editor.getText(), 'Text in between 0 and 1.\n\nYour middle changes\n\nText in between 1 and 2.');
    });

    it('resolves a conflict as current', function() {
      const conflict = conflicts[1];

      editor.setCursorBufferPosition([14, 1]); // On "My middle changes"
      commands.dispatch(editorView, 'github:resolve-as-current');

      assert.isTrue(conflict.isResolved());
      assert.strictEqual(conflict.getChosenSide(), conflict.getSide(OURS));
      assert.deepEqual(conflict.getUnchosenSides(), [conflict.getSide(THEIRS)]);

      assert.include(editor.getText(), 'Text in between 0 and 1.\n\nMy middle changes\n\nText in between 1 and 2.');
    });

    it('resolves multiple conflicts as current', function() {
      editor.setCursorBufferPosition([14, 1]); // On "My middle changes"
      editor.addCursorAtBufferPosition([24, 3]); // On "More of your changes"

      commands.dispatch(editorView, 'github:resolve-as-current');

      assert.isFalse(conflicts[0].isResolved());
      assert.isTrue(conflicts[1].isResolved());
      assert.strictEqual(conflicts[1].getChosenSide(), conflicts[1].getSide(OURS));
      assert.isTrue(conflicts[2].isResolved());
      assert.strictEqual(conflicts[2].getChosenSide(), conflicts[2].getSide(THEIRS));
    });

    it('resolves multiple conflicts as "ours"', function() {
      assert.isFalse(conflicts[0].isResolved());
      assert.isFalse(conflicts[1].isResolved());
      assert.isFalse(conflicts[2].isResolved());

      editor.setCursorBufferPosition([8, 3]); // On "Your changes"
      editor.addCursorAtBufferPosition([11, 2]); // On "Text in between 0 and 1."
      editor.addCursorAtBufferPosition([14, 5]); // On "My middle changes"
      editor.addCursorAtBufferPosition([15, 0]); // On "======="
      commands.dispatch(editorView, 'github:resolve-as-ours');

      assert.isTrue(conflicts[0].isResolved());
      assert.strictEqual(conflicts[0].getChosenSide(), conflicts[0].getSide(OURS));
      assert.deepEqual(conflicts[0].getUnchosenSides(), [conflicts[0].getSide(THEIRS)]);

      assert.isTrue(conflicts[1].isResolved());
      assert.strictEqual(conflicts[1].getChosenSide(), conflicts[1].getSide(OURS));
      assert.deepEqual(conflicts[1].getUnchosenSides(), [conflicts[1].getSide(THEIRS)]);

      assert.isFalse(conflicts[2].isResolved());
    });

    it('resolves multiple conflicts as "theirs"', function() {
      assert.isFalse(conflicts[0].isResolved());
      assert.isFalse(conflicts[1].isResolved());
      assert.isFalse(conflicts[2].isResolved());

      editor.setCursorBufferPosition([8, 3]); // On "Your changes"
      editor.addCursorAtBufferPosition([11, 2]); // On "Text in between 0 and 1."
      editor.addCursorAtBufferPosition([22, 5]); // On "More of my changes"
      commands.dispatch(editorView, 'github:resolve-as-theirs');

      assert.isTrue(conflicts[0].isResolved());
      assert.strictEqual(conflicts[0].getChosenSide(), conflicts[0].getSide(THEIRS));
      assert.deepEqual(conflicts[0].getUnchosenSides(), [conflicts[0].getSide(OURS)]);

      assert.isFalse(conflicts[1].isResolved());

      assert.isTrue(conflicts[2].isResolved());
      assert.strictEqual(conflicts[2].getChosenSide(), conflicts[2].getSide(THEIRS));
      assert.deepEqual(conflicts[2].getUnchosenSides(), [conflicts[2].getSide(OURS)]);
    });

    it('disregards conflicts with cursors on both sides', function() {
      editor.setCursorBufferPosition([6, 3]); // On "Multi-line even"
      editor.addCursorAtBufferPosition([14, 1]); // On "My middle changes"
      editor.addCursorAtBufferPosition([16, 0]); // On "Your middle changes"

      commands.dispatch(editorView, 'github:resolve-as-current');

      assert.isTrue(conflicts[0].isResolved());
      assert.strictEqual(conflicts[0].getChosenSide(), conflicts[0].getSide(OURS));
      assert.isFalse(conflicts[1].isResolved());
      assert.isFalse(conflicts[2].isResolved());
    });

    it('resolves a conflict as "ours then theirs"', function() {
      const conflict = conflicts[1];

      editor.setCursorBufferPosition([14, 1]); // On "My middle changes"
      commands.dispatch(editorView, 'github:resolve-as-ours-then-theirs');

      assert.isTrue(conflict.isResolved());
      assert.include(editor.getText(), 'Text in between 0 and 1.' +
        '\n\nMy middle changes\nYour middle changes\n\nText in between 1 and 2.');
    });

    it('resolves a conflict as "theirs then ours"', function() {
      const conflict = conflicts[1];

      editor.setCursorBufferPosition([14, 1]); // On "My middle changes"
      commands.dispatch(editorView, 'github:resolve-as-theirs-then-ours');

      assert.isTrue(conflict.isResolved());
      assert.include(editor.getText(), 'Text in between 0 and 1.' +
        '\n\nYour middle changes\nMy middle changes\n\nText in between 1 and 2.');
    });

    it('resolves a conflict as custom text', function() {
      const conflict = conflicts[1];
      const range = conflict.getSide(OURS).getMarker().getBufferRange();
      editor.setTextInBufferRange(range, 'Actually it should be this\n');

      editor.setCursorBufferPosition([16, 6]); // On "Your middle changes"
      commands.dispatch(editorView, 'github:resolve-as-ours');

      assert.isTrue(conflict.isResolved());
      assert.strictEqual(conflict.getChosenSide(), conflict.getSide(OURS));

      assert.include(editor.getText(), 'Text in between 0 and 1.\n\n' +
        'Actually it should be this\n\nText in between 1 and 2.');
    });

    it('reverts modified text within a conflict', function() {
      const conflict = conflicts[1];
      const range = conflict.getSide(OURS).getMarker().getBufferRange();
      editor.setTextInBufferRange(range, 'Actually it should be this\n');

      editor.setCursorBufferPosition([14, 3]); // On "Actually it should be this"
      commands.dispatch(editorView, 'github:revert-conflict-modifications');

      assert.isFalse(conflict.getSide(OURS).isModified());
      assert.include(editor.getText(), 'Text in between 0 and 1.\n\n' +
        '<<<<<<< HEAD\n' +
        'My middle changes\n' +
        '=======\n' +
        'Your middle changes\n' +
        '>>>>>>> other-branch\n' +
        '\nText in between 1 and 2.');
    });

    it('preserves a modified side banner', function() {
      const conflict = conflicts[1];
      const range = conflict.getSide(OURS).getBannerMarker().getBufferRange();
      editor.setTextInBufferRange(range, '>>>>>>> Changed this myself\n');

      assert.isTrue(conflict.getSide(OURS).isBannerModified());

      editor.setCursorBufferPosition([16, 6]); // On "Your middle changes"
      commands.dispatch(editorView, 'github:resolve-as-ours');

      assert.isTrue(conflict.isResolved());
      assert.strictEqual(conflict.getChosenSide(), conflict.getSide(OURS));

      assert.include(editor.getText(), 'Text in between 0 and 1.\n\n' +
        '>>>>>>> Changed this myself\n' +
        'My middle changes\n\n' +
        'Text in between 1 and 2.');
    });

    it('preserves a modified separator', function() {
      const conflict = conflicts[1];
      const range = conflict.getSeparator().getMarker().getBufferRange();
      editor.setTextInBufferRange(range, '==== hooray ====\n');

      assert.isTrue(conflict.getSeparator().isModified());

      editor.setCursorBufferPosition([16, 6]); // On "Your middle changes"
      commands.dispatch(editorView, 'github:resolve-as-ours');

      assert.include(editor.getText(), 'Text in between 0 and 1.\n\n' +
        'My middle changes\n' +
        '==== hooray ====\n\n' +
        'Text in between 1 and 2.');
    });

    it('reports resolution progress', function() {
      assert.equal(resolutionProgress.getRemaining(editor.getPath()), 3);

      editor.setCursorBufferPosition([16, 6]); // On "Your middle changes"
      commands.dispatch(editorView, 'github:resolve-as-ours');

      assert.equal(resolutionProgress.getRemaining(editor.getPath()), 2);
    });

    it('dismisses a conflict for manual resolution', function() {
      const dismissedConflict = conflicts[1];
      assert.equal(resolutionProgress.getRemaining(editor.getPath()), 3);

      editor.setCursorBufferPosition([16, 6]); // On "Your middle changes"
      commands.dispatch(editorView, 'github:dismiss-conflict');
      wrapper.update();

      assert.equal(resolutionProgress.getRemaining(editor.getPath()), 2);
      assert.include(editor.getText(), 'Text in between 0 and 1.\n\n' +
        '<<<<<<< HEAD\n' +
        'My middle changes\n' +
        '=======\n' +
        'Your middle changes\n' +
        '>>>>>>> other-branch\n' +
        '\nText in between 1 and 2.');
      assert.lengthOf(wrapper.find(ConflictController), 2);
      assert.isFalse(wrapper.find(ConflictController).someWhere(cc => cc.prop('conflict') === dismissedConflict));
    });

    it('refreshes conflict markers on buffer reload', async function() {
      fs.writeFileSync(fixtureFile, onlyTwoMarkers);

      await assert.async.equal(wrapper.state('conflicts').size, 2);
      wrapper.update();

      assert.lengthOf(wrapper.find(ConflictController), 2);
      assert.equal(resolutionProgress.getRemaining(fixtureFile), 2);
    });

    it('triggers an offline resolution progress refresh when the editor is closed', async function() {
      editor.setCursorBufferPosition([16, 6]); // On "Your middle changes"
      commands.dispatch(editorView, 'github:resolve-as-ours');

      editor.destroy();

      await assert.async.isTrue(refreshResolutionProgress.calledWith(fixtureFile));
    });

    it('performs a resolution from the context menu', function() {
      const conflict = conflicts[1];
      assert.isFalse(conflict.isResolved());

      wrapper.find('ConflictController').at(1).prop('resolveAsSequence')([OURS]);

      assert.isTrue(conflict.isResolved());
      assert.strictEqual(conflict.getChosenSide(), conflict.getSide(OURS));
    });

    it('dismisses a conflict from the context menu', function() {
      const conflict = conflicts[2];

      wrapper.find('ConflictController').at(2).prop('dismiss')();
      wrapper.update();

      assert.lengthOf(wrapper.find(ConflictController), 2);
      assert.isFalse(wrapper.find(ConflictController).someWhere(cc => cc.prop('conflict') === conflict));
    });
  });

  describe('on a file with 3-way diff markers', function() {
    let conflicts, conflict;

    beforeEach(async function() {
      await useFixture('single-3way-diff.txt');
      conflicts = Array.from(wrapper.state('conflicts'));
      conflict = conflicts[0];
    });

    it('creates a conflict controller for each conflict', function() {
      assert.lengthOf(conflicts, 1);

      assert.equal(textFromSide(conflicts[0].getSide(BASE)), 'These are original texts\n');
    });

    it('resolves a conflict as "ours"', function() {
      assert.isFalse(conflict.isResolved());

      editor.setCursorBufferPosition([3, 4]); // On "These are original texts"
      commands.dispatch(editorView, 'github:resolve-as-ours');

      assert.isTrue(conflict.isResolved());
      assert.strictEqual(conflict.getChosenSide(), conflict.getSide(OURS));
      assert.deepEqual(conflict.getUnchosenSides(), [conflict.getSide(BASE), conflict.getSide(THEIRS)]);

      assert.include(editor.getText(), 'These are my changes\n\nPast the end\n');
    });

    it('resolves a conflict as "theirs"', function() {
      editor.setCursorBufferPosition([3, 4]); // On "These are original texts"
      commands.dispatch(editorView, 'github:resolve-as-theirs');

      assert.isTrue(conflict.isResolved());
      assert.strictEqual(conflict.getChosenSide(), conflict.getSide(THEIRS));
      assert.deepEqual(conflict.getUnchosenSides(), [conflict.getSide(OURS), conflict.getSide(BASE)]);

      assert.include(editor.getText(), 'These are your changes\n\nPast the end\n');
    });

    it('resolves a conflict as "base"', function() {
      editor.setCursorBufferPosition([1, 0]); // On "These are my changes"
      commands.dispatch(editorView, 'github:resolve-as-base');

      assert.isTrue(conflict.isResolved());
      assert.strictEqual(conflict.getChosenSide(), conflict.getSide(BASE));
      assert.deepEqual(conflict.getUnchosenSides(), [conflict.getSide(OURS), conflict.getSide(THEIRS)]);

      assert.include(editor.getText(), 'These are original texts\n\nPast the end\n');
    });

    it('resolves a conflict as "ours then theirs"', function() {
      editor.setCursorBufferPosition([3, 4]); // On "These are original texts"
      commands.dispatch(editorView, 'github:resolve-as-ours-then-theirs');

      assert.isTrue(conflict.isResolved());
      assert.include(editor.getText(), 'These are my changes\nThese are your changes\n\nPast the end\n');
    });

    it('resolves a conflict as "theirs then ours"', function() {
      editor.setCursorBufferPosition([3, 4]); // On "These are original texts"
      commands.dispatch(editorView, 'github:resolve-as-theirs-then-ours');

      assert.isTrue(conflict.isResolved());
      assert.include(editor.getText(), 'These are your changes\nThese are my changes\n\nPast the end\n');
    });
  });

  describe('while rebasing', function() {
    let conflict;

    beforeEach(async function() {
      await useFixture('single-3way-diff.txt', {isRebase: true});
      [conflict] = Array.from(wrapper.state('conflicts'));
    });

    it('resolves a conflict as "ours"', function() {
      editor.setCursorBufferPosition([3, 3]); // On "these are original texts"
      commands.dispatch(editorView, 'github:resolve-as-ours');

      assert.isTrue(conflict.isResolved());
      assert.strictEqual(conflict.getChosenSide(), conflict.getSide(OURS));
      assert.deepEqual(conflict.getUnchosenSides(), [conflict.getSide(BASE), conflict.getSide(THEIRS)]);

      assert.equal(editor.getText(), 'These are your changes\n\nPast the end\n');
    });

    it('resolves a conflict as "theirs"', function() {
      editor.setCursorBufferPosition([3, 3]); // On "these are original texts"
      commands.dispatch(editorView, 'github:resolve-as-theirs');

      assert.isTrue(conflict.isResolved());
      assert.strictEqual(conflict.getChosenSide(), conflict.getSide(THEIRS));
      assert.deepEqual(conflict.getUnchosenSides(), [conflict.getSide(OURS), conflict.getSide(BASE)]);

      assert.equal(editor.getText(), 'These are my changes\n\nPast the end\n');
    });

    it('resolves a conflict as "base"', function() {
      editor.setCursorBufferPosition([3, 3]); // On "these are original texts"
      commands.dispatch(editorView, 'github:resolve-as-base');

      assert.isTrue(conflict.isResolved());
      assert.strictEqual(conflict.getChosenSide(), conflict.getSide(BASE));
      assert.deepEqual(conflict.getUnchosenSides(), [conflict.getSide(OURS), conflict.getSide(THEIRS)]);

      assert.equal(editor.getText(), 'These are original texts\n\nPast the end\n');
    });

    it('resolves a conflict as "ours then theirs"', function() {
      editor.setCursorBufferPosition([3, 3]); // On "these are original texts"
      commands.dispatch(editorView, 'github:resolve-as-ours-then-theirs');

      assert.isTrue(conflict.isResolved());
      assert.equal(editor.getText(), 'These are your changes\nThese are my changes\n\nPast the end\n');
    });

    it('resolves a conflict as "theirs then ours"', function() {
      editor.setCursorBufferPosition([3, 3]); // On "these are original texts"
      commands.dispatch(editorView, 'github:resolve-as-theirs-then-ours');

      assert.isTrue(conflict.isResolved());
      assert.equal(editor.getText(), 'These are my changes\nThese are your changes\n\nPast the end\n');
    });
  });

  it('cleans up its subscriptions when unmounting', async function() {
    await useFixture('triple-2way-diff.txt');
    wrapper.unmount();

    editor.destroy();
    assert.isFalse(refreshResolutionProgress.called);
  });
});
