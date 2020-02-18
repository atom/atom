import React from 'react';
import {mount} from 'enzyme';
import dedent from 'dedent-js';

import PatchPreviewView from '../../lib/views/patch-preview-view';
import {multiFilePatchBuilder} from '../builder/patch';
import {assertMarkerRanges} from '../helpers';

describe('PatchPreviewView', function() {
  let atomEnv, multiFilePatch;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    multiFilePatch = multiFilePatchBuilder()
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('file.txt'));
        fp.addHunk(h => h.unchanged('000').added('001', '002').deleted('003', '004'));
        fp.addHunk(h => h.unchanged('005').deleted('006').added('007').unchanged('008'));
      })
      .build()
      .multiFilePatch;
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    const props = {
      multiFilePatch,
      fileName: 'file.txt',
      diffRow: 3,
      maxRowCount: 4,
      config: atomEnv.config,
      ...override,
    };

    return <PatchPreviewView {...props} />;
  }

  function getEditor(wrapper) {
    return wrapper.find('AtomTextEditor').instance().getRefModel().getOr(null);
  }

  it('builds and renders sub-PatchBuffer content within a TextEditor', function() {
    const wrapper = mount(buildApp({fileName: 'file.txt', diffRow: 5, maxRowCount: 4}));
    const editor = getEditor(wrapper);

    assert.strictEqual(editor.getText(), dedent`
      001
      002
      003
      004
    `);
  });

  it('retains sub-PatchBuffers, adopting new content if the MultiFilePatch changes', function() {
    const wrapper = mount(buildApp({fileName: 'file.txt', diffRow: 4, maxRowCount: 4}));
    const previewPatchBuffer = wrapper.state('previewPatchBuffer');
    assert.strictEqual(previewPatchBuffer.getBuffer().getText(), dedent`
      000
      001
      002
      003
    `);

    wrapper.setProps({});
    assert.strictEqual(wrapper.state('previewPatchBuffer'), previewPatchBuffer);
    assert.strictEqual(previewPatchBuffer.getBuffer().getText(), dedent`
      000
      001
      002
      003
    `);

    const {multiFilePatch: newPatch} = multiFilePatchBuilder()
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('file.txt'));
        fp.addHunk(h => h.unchanged('000').added('001').unchanged('changed').deleted('003', '004'));
        fp.addHunk(h => h.unchanged('005').deleted('006').added('007').unchanged('008'));
      })
      .build();
    wrapper.setProps({multiFilePatch: newPatch});

    assert.strictEqual(wrapper.state('previewPatchBuffer'), previewPatchBuffer);
    assert.strictEqual(previewPatchBuffer.getBuffer().getText(), dedent`
      000
      001
      changed
      003
    `);
  });

  it('decorates the addition and deletion marker layers', function() {
    const wrapper = mount(buildApp({fileName: 'file.txt', diffRow: 5, maxRowCount: 4}));

    const additionDecoration = wrapper.find(
      'BareDecoration[className="github-FilePatchView-line--added"][type="line"]',
    );
    const additionLayer = additionDecoration.prop('decorableHolder').get();
    assertMarkerRanges(additionLayer, [[0, 0], [1, 3]]);

    const deletionDecoration = wrapper.find(
      'BareDecoration[className="github-FilePatchView-line--deleted"][type="line"]',
    );
    const deletionLayer = deletionDecoration.prop('decorableHolder').get();
    assertMarkerRanges(deletionLayer, [[2, 0], [3, 3]]);
  });

  it('includes a diff icon gutter when enabled', function() {
    atomEnv.config.set('github.showDiffIconGutter', true);

    const wrapper = mount(buildApp());

    const gutter = wrapper.find('BareGutter');
    assert.strictEqual(gutter.prop('name'), 'diff-icons');
    assert.strictEqual(gutter.prop('type'), 'line-number');
    assert.strictEqual(gutter.prop('className'), 'icons');
    assert.strictEqual(gutter.prop('labelFn')(), '\u00a0');
  });

  it('omits the diff icon gutter when disabled', function() {
    atomEnv.config.set('github.showDiffIconGutter', false);

    const wrapper = mount(buildApp());
    assert.isFalse(wrapper.exists('BareGutter'));
  });
});
