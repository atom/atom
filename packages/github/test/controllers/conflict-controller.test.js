import path from 'path';
import React from 'react';
import {shallow} from 'enzyme';

import Conflict from '../../lib/models/conflicts/conflict';
import {OURS, THEIRS} from '../../lib/models/conflicts/source';
import ConflictController from '../../lib/controllers/conflict-controller';
import Decoration from '../../lib/atom/decoration';

describe('ConflictController', function() {
  let atomEnv, workspace, app, editor, conflict, decorations;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    workspace = atomEnv.workspace;
  });

  afterEach(async function() {
    await atomEnv.destroy();
  });

  const useFixture = async function(fixtureName, conflictIndex, {resolution} = {}) {
    editor = await workspace.open(path.join(
      path.dirname(__filename), '..', 'fixtures', 'conflict-marker-examples', fixtureName));

    const conflicts = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false);
    conflict = conflicts[conflictIndex];

    if (resolution) {
      conflict.resolveAs(resolution);
    }

    app = <ConflictController workspace={workspace} editor={editor} conflict={conflict} />;
    const wrapper = shallow(app);
    decorations = wrapper.find(Decoration);
  };

  const decorationsMatching = query => decorations.filterWhere(d => {
    const queryKeys = Object.keys(query);
    const props = d.props();
    for (let i = 0; i < queryKeys.length; i++) {
      const key = queryKeys[i];

      if (props[key] !== query[key]) {
        return false;
      }
    }
    return true;
  });

  const textFromDecoration = function(d) {
    return editor.getTextInBufferRange(d.prop('decorable').getBufferRange());
  };

  const pointFromDecoration = function(d) {
    const range = d.prop('decorable').getBufferRange();
    assert.isTrue(range.isEmpty());
    return range.start.toArray();
  };

  it('creates a line Decoration for each side and banner of the conflict', async function() {
    await useFixture('triple-2way-diff.txt', 1);

    const ourBlockDecorations = decorationsMatching({type: 'block', position: 'before'});
    assert.deepEqual(ourBlockDecorations.map(pointFromDecoration), [[13, 0]]);

    const ourBannerDecorations = decorationsMatching({type: 'line', className: 'github-ConflictOursBanner'});
    assert.deepEqual(ourBannerDecorations.map(textFromDecoration), ['<<<<<<< HEAD\n']);

    const ourSideDecorations = decorationsMatching({type: 'line', className: 'github-ConflictOurs'});
    assert.deepEqual(ourSideDecorations.map(textFromDecoration), ['My middle changes\n']);

    const separatorDecorations = decorationsMatching({type: 'line', className: 'github-ConflictSeparator'});
    assert.deepEqual(separatorDecorations.map(textFromDecoration), ['=======\n']);

    const theirSideDecorations = decorationsMatching({type: 'line', className: 'github-ConflictTheirs'});
    assert.deepEqual(theirSideDecorations.map(textFromDecoration), ['Your middle changes\n']);

    const theirBannerDecorations = decorationsMatching({type: 'line', className: 'github-ConflictTheirsBanner'});
    assert.deepEqual(theirBannerDecorations.map(textFromDecoration), ['>>>>>>> other-branch\n']);

    const theirBlockDecorations = decorationsMatching({type: 'block', position: 'after'});
    assert.deepEqual(theirBlockDecorations.map(pointFromDecoration), [[17, 20]]);
  });

  it('creates a line Decoration for resolved conflicts', async function() {
    await useFixture('triple-2way-diff.txt', 1, {resolution: OURS});

    const resolvedSideDecorations = decorationsMatching({type: 'line', className: 'github-ResolvedLines'});
    assert.deepEqual(resolvedSideDecorations.map(textFromDecoration), ['My middle changes\n']);

    [
      {type: 'block', position: 'before'},
      {type: 'line', className: 'github-ConflictOursBanner'},
      {type: 'line', className: 'github-ConflictOurs'},
      {type: 'line', className: 'github-ConflictSeparator'},
      {type: 'line', className: 'github-ConflictTheirs'},
      {type: 'line', className: 'github-ConflictTheirsBanner'},
      {type: 'block', position: 'after'},
    ].forEach(query => {
      assert.lengthOf(decorationsMatching(query), 0);
    });
  });

  it('creates no decorations for conflicts resolved as empty', async function() {
    await useFixture('triple-2way-diff.txt', 2, {resolution: THEIRS});

    [
      {type: 'block', position: 'before'},
      {type: 'line', className: 'github-ConflictOursBanner'},
      {type: 'line', className: 'github-ConflictOurs'},
      {type: 'line', className: 'github-ConflictSeparator'},
      {type: 'line', className: 'github-ConflictTheirs'},
      {type: 'line', className: 'github-ConflictTheirsBanner'},
      {type: 'block', position: 'after'},
      {type: 'line', className: 'github-ResolvedLines'},
    ].forEach(query => {
      assert.lengthOf(decorationsMatching(query), 0);
    });
  });
});
