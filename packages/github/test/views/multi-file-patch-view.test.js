import React from 'react';
import {shallow, mount} from 'enzyme';

import * as reporterProxy from '../../lib/reporter-proxy';

import {cloneRepository, buildRepository} from '../helpers';
import {EXPANDED, COLLAPSED, DEFERRED, REMOVED} from '../../lib/models/patch/patch';
import MultiFilePatchView from '../../lib/views/multi-file-patch-view';
import {multiFilePatchBuilder} from '../builder/patch';
import {aggregatedReviewsBuilder} from '../builder/graphql/aggregated-reviews-builder';
import {nullFile} from '../../lib/models/patch/file';
import FilePatch from '../../lib/models/patch/file-patch';
import RefHolder from '../../lib/models/ref-holder';
import CommentGutterDecorationController from '../../lib/controllers/comment-gutter-decoration-controller';
import CommitPreviewItem from '../../lib/items/commit-preview-item';
import ChangedFileItem from '../../lib/items/changed-file-item';
import IssueishDetailItem from '../../lib/items/issueish-detail-item';

describe('MultiFilePatchView', function() {
  let atomEnv, workspace, repository, filePatches;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    workspace = atomEnv.workspace;

    const workdirPath = await cloneRepository();
    repository = await buildRepository(workdirPath);

    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('path.txt'));
        fp.addHunk(h => {
          h.oldRow(4);
          h.unchanged('0000').added('0001', '0002').deleted('0003').unchanged('0004');
        });
        fp.addHunk(h => {
          h.oldRow(8);
          h.unchanged('0005').added('0006').deleted('0007').unchanged('0008');
        });
      }).build();

    filePatches = multiFilePatch;
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrideProps = {}) {
    const props = {
      relPath: 'path.txt',
      stagingStatus: 'unstaged',
      isPartiallyStaged: false,
      multiFilePatch: filePatches,
      hasUndoHistory: false,
      selectionMode: 'line',
      selectedRows: new Set(),
      hasMultipleFileSelections: false,
      repository,
      isActive: true,

      workspace,
      config: atomEnv.config,
      commands: atomEnv.commands,
      keymaps: atomEnv.keymaps,
      tooltips: atomEnv.tooltips,

      selectedRowsChanged: () => {},
      switchToIssueish: () => {},

      diveIntoMirrorPatch: () => {},
      surface: () => {},
      openFile: () => {},
      toggleFile: () => {},
      toggleRows: () => {},
      toggleModeChange: () => {},
      toggleSymlinkChange: () => {},
      undoLastDiscard: () => {},
      discardRows: () => {},

      itemType: CommitPreviewItem,

      ...overrideProps,
    };

    return <MultiFilePatchView {...props} />;
  }

  it('renders the file header', function() {
    const wrapper = shallow(buildApp());
    assert.isTrue(wrapper.find('FilePatchHeaderView').exists());
  });

  it('passes the new path of renamed files', function() {
    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(fp => {
        fp.status('renamed');
        fp.setOldFile(f => f.path('old.txt'));
        fp.setNewFile(f => f.path('new.txt'));
      })
      .build();

    const wrapper = shallow(buildApp({multiFilePatch}));
    assert.strictEqual(wrapper.find('FilePatchHeaderView').prop('newPath'), 'new.txt');
  });

  it('populates an externally provided refEditor', async function() {
    const refEditor = new RefHolder();
    mount(buildApp({refEditor}));
    assert.isDefined(await refEditor.getPromise());
  });

  describe('file header decoration positioning', function() {
    let wrapper;

    function decorationForFileHeader(fileName) {
      return wrapper.find('Decoration').filterWhere(dw => dw.exists(`FilePatchHeaderView[relPath="${fileName}"]`));
    }

    it('renders visible file headers with position: before', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('0.txt'));
          fp.addHunk(h => h.unchanged('a-0').deleted('a-1').unchanged('a-2'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('1.txt'));
          fp.addHunk(h => h.unchanged('b-0').added('b-1').unchanged('b-2'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('2.txt'));
          fp.addHunk(h => h.unchanged('c-0').deleted('c-1').unchanged('c-2'));
        })
        .build();

      wrapper = shallow(buildApp({multiFilePatch}));

      assert.strictEqual(decorationForFileHeader('0.txt').prop('position'), 'before');
      assert.strictEqual(decorationForFileHeader('1.txt').prop('position'), 'before');
      assert.strictEqual(decorationForFileHeader('2.txt').prop('position'), 'before');
    });

    it('renders a final collapsed file header with position: after', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.renderStatus(COLLAPSED);
          fp.setOldFile(f => f.path('0.txt'));
          fp.addHunk(h => h.unchanged('a-0').added('a-1').unchanged('a-2'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('1.txt'));
          fp.addHunk(h => h.unchanged('b-0').added('b-1').unchanged('b-2'));
        })
        .addFilePatch(fp => {
          fp.renderStatus(COLLAPSED);
          fp.setOldFile(f => f.path('2.txt'));
          fp.addHunk(h => h.unchanged('c-0').added('c-1').unchanged('c-2'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('3.txt'));
          fp.addHunk(h => h.unchanged('d-0').added('d-1').unchanged('d-2'));
        })
        .addFilePatch(fp => {
          fp.renderStatus(COLLAPSED);
          fp.setOldFile(f => f.path('4.txt'));
          fp.addHunk(h => h.unchanged('e-0').added('e-1').unchanged('e-2'));
        })
        .build();

      wrapper = shallow(buildApp({multiFilePatch}));

      assert.strictEqual(decorationForFileHeader('0.txt').prop('position'), 'before');
      assert.strictEqual(decorationForFileHeader('1.txt').prop('position'), 'before');
      assert.strictEqual(decorationForFileHeader('2.txt').prop('position'), 'before');
      assert.strictEqual(decorationForFileHeader('3.txt').prop('position'), 'before');
      assert.strictEqual(decorationForFileHeader('4.txt').prop('position'), 'after');
    });

    it('renders a final mode change-only file header with position: after', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('0.txt'));
          fp.setNewFile(f => f.path('0.txt').executable());
          fp.empty();
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('1.txt'));
          fp.addHunk(h => h.unchanged('b-0').added('b-1').unchanged('b-2'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('2.txt').executable());
          fp.setNewFile(f => f.path('2.txt'));
          fp.empty();
        })
        .build();

      wrapper = shallow(buildApp({multiFilePatch}));

      assert.strictEqual(decorationForFileHeader('0.txt').prop('position'), 'before');
      assert.strictEqual(decorationForFileHeader('1.txt').prop('position'), 'before');
      assert.strictEqual(decorationForFileHeader('2.txt').prop('position'), 'after');
    });
  });

  it('undoes the last discard from the file header button', function() {
    const undoLastDiscard = sinon.spy();
    const wrapper = shallow(buildApp({undoLastDiscard}));

    wrapper.find('FilePatchHeaderView').first().prop('undoLastDiscard')();

    assert.lengthOf(filePatches.getFilePatches(), 1);
    const [filePatch] = filePatches.getFilePatches();
    assert.isTrue(undoLastDiscard.calledWith(filePatch, {eventSource: 'button'}));
  });

  it('dives into the mirror patch from the file header button', function() {
    const diveIntoMirrorPatch = sinon.spy();
    const wrapper = shallow(buildApp({diveIntoMirrorPatch}));

    wrapper.find('FilePatchHeaderView').prop('diveIntoMirrorPatch')();

    assert.lengthOf(filePatches.getFilePatches(), 1);
    const [filePatch] = filePatches.getFilePatches();
    assert.isTrue(diveIntoMirrorPatch.calledWith(filePatch));
  });

  it('toggles a file from staged to unstaged from the file header button', function() {
    const toggleFile = sinon.spy();
    const wrapper = shallow(buildApp({toggleFile}));

    wrapper.find('FilePatchHeaderView').prop('toggleFile')();

    assert.lengthOf(filePatches.getFilePatches(), 1);
    const [filePatch] = filePatches.getFilePatches();
    assert.isTrue(toggleFile.calledWith(filePatch));
  });

  it('passes hasMultipleFileSelections to all file headers', function() {
    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(fp => fp.setOldFile(f => f.path('0')))
      .addFilePatch(fp => fp.setOldFile(f => f.path('1')))
      .build();

    const wrapper = shallow(buildApp({multiFilePatch, hasMultipleFileSelections: true}));

    assert.isTrue(wrapper.find('FilePatchHeaderView[relPath="0"]').prop('hasMultipleFileSelections'));
    assert.isTrue(wrapper.find('FilePatchHeaderView[relPath="1"]').prop('hasMultipleFileSelections'));

    wrapper.setProps({hasMultipleFileSelections: false});

    assert.isFalse(wrapper.find('FilePatchHeaderView[relPath="0"]').prop('hasMultipleFileSelections'));
    assert.isFalse(wrapper.find('FilePatchHeaderView[relPath="1"]').prop('hasMultipleFileSelections'));
  });

  it('triggers a FilePatch collapse from file headers', function() {
    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(fp => fp.setOldFile(f => f.path('0')))
      .addFilePatch(fp => fp.setOldFile(f => f.path('1')))
      .build();
    const fp1 = multiFilePatch.getFilePatches()[1];

    const wrapper = shallow(buildApp({multiFilePatch}));

    sinon.stub(multiFilePatch, 'collapseFilePatch');

    wrapper.find('FilePatchHeaderView[relPath="1"]').prop('triggerCollapse')();
    assert.isTrue(multiFilePatch.collapseFilePatch.calledWith(fp1));
  });

  it('triggers a FilePatch expansion from file headers', function() {
    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(fp => fp.setOldFile(f => f.path('0')))
      .addFilePatch(fp => fp.setOldFile(f => f.path('1')))
      .build();
    const fp0 = multiFilePatch.getFilePatches()[0];

    const wrapper = shallow(buildApp({multiFilePatch}));

    sinon.stub(multiFilePatch, 'expandFilePatch');

    wrapper.find('FilePatchHeaderView[relPath="0"]').prop('triggerExpand')();
    assert.isTrue(multiFilePatch.expandFilePatch.calledWith(fp0));
  });

  describe('review comments', function() {
    it('renders a gutter decoration for each review thread if itemType is IssueishDetailItem', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file0.txt'));
          fp.addHunk(h => h.unchanged('0', '1', '2').added('3').unchanged('4', '5'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file1.txt'));
          fp.addHunk(h => h.unchanged('6').deleted('7', '8').unchanged('9'));
        })
        .build();

      const payload = aggregatedReviewsBuilder()
        .addReviewThread(b => {
          b.thread(t => t.id('thread0').isResolved(true));
          b.addComment(c => c.path('file0.txt').position(1));
        })
        .addReviewThread(b => {
          b.thread(t => t.id('thread1').isResolved(false));
          b.addComment(c => c.path('file1.txt').position(2));
          b.addComment(c => c.path('ignored').position(999));
          b.addComment(c => c.path('file1.txt').position(0));
        })
        .addReviewThread(b => {
          b.thread(t => t.id('thread2').isResolved(false));
          b.addComment(c => c.path('file0.txt').position(4));
          b.addComment(c => c.path('file0.txt').position(4));
        })
        .build();

      const wrapper = shallow(buildApp({
        multiFilePatch,
        reviewCommentsLoading: false,
        reviewCommentsTotalCount: 3,
        reviewCommentsResolvedCount: 1,
        reviewCommentThreads: payload.commentThreads,
        selectedRows: new Set([7]),
        itemType: IssueishDetailItem,
      }));

      const controllers = wrapper.find(CommentGutterDecorationController);
      assert.lengthOf(controllers, 3);

      const controller0 = controllers.at(0);
      assert.strictEqual(controller0.prop('commentRow'), 0);
      assert.strictEqual(controller0.prop('threadId'), 'thread0');
      assert.lengthOf(controller0.prop('extraClasses'), 0);

      const controller1 = controllers.at(1);
      assert.strictEqual(controller1.prop('commentRow'), 7);
      assert.strictEqual(controller1.prop('threadId'), 'thread1');
      assert.deepEqual(controller1.prop('extraClasses'), ['github-FilePatchView-line--selected']);

      const controller2 = controllers.at(2);
      assert.strictEqual(controller2.prop('commentRow'), 3);
      assert.strictEqual(controller2.prop('threadId'), 'thread2');
      assert.lengthOf(controller2.prop('extraClasses'), 0);
    });

    it('does not render threads until they finish loading', function() {
      const payload = aggregatedReviewsBuilder()
        .addReviewThread(b => {
          b.thread(t => t.isResolved(true));
          b.addComment();
        })
        .addReviewThread(b => {
          b.thread(t => t.isResolved(false));
          b.addComment();
          b.addComment();
          b.addComment();
        })
        .build();

      const wrapper = shallow(buildApp({
        reviewCommentsLoading: true,
        reviewCommentsTotalCount: 3,
        reviewCommentsResolvedCount: 1,
        reviewCommentThreads: payload.commentThreads,
        itemType: IssueishDetailItem,
      }));

      assert.isFalse(wrapper.find(CommentGutterDecorationController).exists());
    });

    it('omit threads that have an invalid path or position', function() {
      sinon.stub(console, 'error');

      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file.txt'));
          fp.addHunk(h => h.unchanged('0').added('1').unchanged('2'));
        })
        .build();

      const payload = aggregatedReviewsBuilder()
        .addReviewThread(b => {
          b.addComment(c => c.path('bad-path.txt').position(1));
        })
        .addReviewThread(b => {
          b.addComment(c => c.path('file.txt').position(100));
        })
        .build();

      const wrapper = shallow(buildApp({
        multiFilePatch,
        reviewCommentsLoading: false,
        reviewCommentsTotalCount: 2,
        reviewCommentsResolvedCount: 0,
        reviewCommentThreads: payload.commentThreads,
        itemType: IssueishDetailItem,
      }));

      assert.isFalse(wrapper.find(CommentGutterDecorationController).exists());

      // eslint-disable-next-line no-console
      assert.strictEqual(console.error.callCount, 1);
    });
  });

  it('renders the file patch within an editor', function() {
    const wrapper = mount(buildApp());

    const editor = wrapper.find('AtomTextEditor');
    assert.strictEqual(editor.instance().getModel().getText(), filePatches.getBuffer().getText());
  });

  it('sets the root class when in hunk selection mode', function() {
    const wrapper = shallow(buildApp({selectionMode: 'line'}));
    assert.isFalse(wrapper.find('.github-FilePatchView--hunkMode').exists());
    wrapper.setProps({selectionMode: 'hunk'});
    assert.isTrue(wrapper.find('.github-FilePatchView--hunkMode').exists());
  });

  describe('initial selection', function() {
    it('selects the origin with an empty FilePatch', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => fp.empty())
        .build();
      const wrapper = mount(buildApp({multiFilePatch}));
      const editor = wrapper.find('AtomTextEditor').instance().getModel();

      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [[[0, 0], [0, 0]]]);
    });

    it('selects the first hunk with a populated file patch', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file-0'));
          fp.addHunk(h => h.unchanged('0').added('1', '2').deleted('3').unchanged('4'));
          fp.addHunk(h => h.added('5', '6'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file-1'));
          fp.addHunk(h => h.deleted('7', '8', '9'));
        })
        .build();
      const wrapper = mount(buildApp({multiFilePatch}));
      const editor = wrapper.find('AtomTextEditor').instance().getModel();

      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [[[0, 0], [4, 1]]]);
    });
  });

  it('preserves the selection index when a new file patch arrives in line selection mode', function() {
    const selectedRowsChanged = sinon.spy();

    let willUpdate, didUpdate;
    const onWillUpdatePatch = cb => {
      willUpdate = cb;
      return {dispose: () => {}};
    };
    const onDidUpdatePatch = cb => {
      didUpdate = cb;
      return {dispose: () => {}};
    };

    const wrapper = mount(buildApp({
      selectedRows: new Set([2]),
      selectionMode: 'line',
      selectedRowsChanged,
      onWillUpdatePatch,
      onDidUpdatePatch,
    }));

    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('path.txt'));
        fp.addHunk(h => {
          h.oldRow(5);
          h.unchanged('0000').added('0001').unchanged('0002').deleted('0003').unchanged('0004');
        });
      }).build();

    willUpdate();
    wrapper.setProps({multiFilePatch});
    didUpdate(multiFilePatch);
    assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [3]);
    assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'line');

    const editor = wrapper.find('AtomTextEditor').instance().getModel();
    assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
      [[3, 0], [3, 4]],
    ]);

    selectedRowsChanged.resetHistory();
    wrapper.setProps({isPartiallyStaged: true});
    assert.isFalse(selectedRowsChanged.called);
  });

  it('selects the next full hunk when a new file patch arrives in hunk selection mode', function() {
    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('path.txt'));
        fp.addHunk(h => {
          h.oldRow(10);
          h.unchanged('0000').added('0001').unchanged('0002').deleted('0003').unchanged('0004');
        });
        fp.addHunk(h => {
          h.oldRow(20);
          h.unchanged('0005').added('0006').added('0007').deleted('0008').unchanged('0009');
        });
        fp.addHunk(h => {
          h.oldRow(30);
          h.unchanged('0010').added('0011').deleted('0012').unchanged('0013');
        });
        fp.addHunk(h => {
          h.oldRow(40);
          h.unchanged('0014').deleted('0015').unchanged('0016').added('0017').unchanged('0018');
        });
      }).build();

    let willUpdate, didUpdate;
    const onWillUpdatePatch = cb => {
      willUpdate = cb;
      return {dispose: () => {}};
    };
    const onDidUpdatePatch = cb => {
      didUpdate = cb;
      return {dispose: () => {}};
    };

    const selectedRowsChanged = sinon.spy();
    const wrapper = mount(buildApp({
      multiFilePatch,
      selectedRows: new Set([6, 7, 8]),
      selectionMode: 'hunk',
      selectedRowsChanged,
      onWillUpdatePatch,
      onDidUpdatePatch,
    }));

    const {multiFilePatch: nextMfp} = multiFilePatchBuilder()
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('path.txt'));
        fp.addHunk(h => {
          h.oldRow(10);
          h.unchanged('0000').added('0001').unchanged('0002').deleted('0003').unchanged('0004');
        });
        fp.addHunk(h => {
          h.oldRow(30);
          h.unchanged('0010').added('0011').deleted('0012').unchanged('0013');
        });
        fp.addHunk(h => {
          h.oldRow(40);
          h.unchanged('0014').deleted('0015').unchanged('0016').added('0017').unchanged('0018');
        });
      }).build();

    willUpdate();
    wrapper.setProps({multiFilePatch: nextMfp});
    didUpdate(nextMfp);

    assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [6, 7]);
    assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'hunk');
    const editor = wrapper.find('AtomTextEditor').instance().getModel();
    assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
      [[5, 0], [8, 4]],
    ]);
  });

  describe('when the last line in a non-last file patch is staged', function() {
    it('updates the selected row to be the first changed line in the next file patch', function() {
      const selectedRowsChanged = sinon.spy();

      let willUpdate, didUpdate;
      const onWillUpdatePatch = cb => {
        willUpdate = cb;
        return {dispose: () => {}};
      };
      const onDidUpdatePatch = cb => {
        didUpdate = cb;
        return {dispose: () => {}};
      };

      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('path.txt'));
          fp.addHunk(h => {
            h.oldRow(5);
            h.unchanged('0000').added('0001').unchanged('0002').deleted('0003').unchanged('0004');
          });
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('another-path.txt'));
          fp.addHunk(h => {
            h.oldRow(5);
            h.unchanged('0000').added('0001').unchanged('0002').deleted('0003').unchanged('0004');
          });
        }).build();

      const wrapper = mount(buildApp({
        selectedRows: new Set([3]),
        selectionMode: 'line',
        selectedRowsChanged,
        onWillUpdatePatch,
        onDidUpdatePatch,
        multiFilePatch,
      }));

      assert.deepEqual([...wrapper.prop('selectedRows')], [3]);

      const {multiFilePatch: multiFilePatch2} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('path.txt'));
          fp.addHunk(h => {
            h.oldRow(5);
            h.unchanged('0000').added('0001').unchanged('0002').unchanged('0003').unchanged('0004');
          });
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('another-path.txt'));
          fp.addHunk(h => {
            h.oldRow(5);
            h.unchanged('0000').added('0001').unchanged('0002').deleted('0003').unchanged('0004');
          });
        }).build();

      selectedRowsChanged.resetHistory();
      willUpdate();
      wrapper.setProps({multiFilePatch: multiFilePatch2});
      didUpdate(multiFilePatch2);

      assert.strictEqual(selectedRowsChanged.callCount, 1);
      assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [6]);
      assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'line');

      const editor = wrapper.find('AtomTextEditor').instance().getModel();
      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
        [[6, 0], [6, 4]],
      ]);
    });
  });

  it('unregisters the mouseup handler on unmount', function() {
    sinon.spy(window, 'addEventListener');
    sinon.spy(window, 'removeEventListener');

    const wrapper = shallow(buildApp());
    assert.strictEqual(window.addEventListener.callCount, 1);
    const addCall = window.addEventListener.getCall(0);
    assert.strictEqual(addCall.args[0], 'mouseup');
    const handler = window.addEventListener.getCall(0).args[1];

    wrapper.unmount();

    assert.isTrue(window.removeEventListener.calledWith('mouseup', handler));
  });

  describe('refInitialFocus', function() {
    it('is set to its editor', function() {
      const refInitialFocus = new RefHolder();
      const wrapper = mount(buildApp({refInitialFocus}));

      assert.isFalse(refInitialFocus.isEmpty());
      assert.strictEqual(
        refInitialFocus.get(),
        wrapper.find('AtomTextEditor').getDOMNode().querySelector('atom-text-editor'),
      );
    });

    it('may be swapped out for a new RefHolder', function() {
      const refInitialFocus0 = new RefHolder();
      const wrapper = mount(buildApp({refInitialFocus: refInitialFocus0}));
      const editorElement = wrapper.find('AtomTextEditor').getDOMNode().querySelector('atom-text-editor');

      assert.strictEqual(refInitialFocus0.getOr(null), editorElement);

      const refInitialFocus1 = new RefHolder();
      wrapper.setProps({refInitialFocus: refInitialFocus1});

      assert.isTrue(refInitialFocus0.isEmpty());
      assert.strictEqual(refInitialFocus1.getOr(null), editorElement);

      wrapper.setProps({refInitialFocus: null});

      assert.isTrue(refInitialFocus0.isEmpty());
      assert.isTrue(refInitialFocus1.isEmpty());

      wrapper.setProps({refInitialFocus: refInitialFocus0});

      assert.strictEqual(refInitialFocus0.getOr(null), editorElement);
      assert.isTrue(refInitialFocus1.isEmpty());
    });
  });

  describe('executable mode changes', function() {
    it('does not render if the mode has not changed', function() {
      const [fp] = filePatches.getFilePatches();
      const mfp = filePatches.clone({
        filePatches: [fp.clone({
          oldFile: fp.getOldFile().clone({mode: '100644'}),
          newFile: fp.getNewFile().clone({mode: '100644'}),
        })],
      });

      const wrapper = shallow(buildApp({multiFilePatch: mfp}));
      assert.isFalse(wrapper.find('FilePatchMetaView[title="Mode change"]').exists());
    });

    it('renders change details within a meta container', function() {
      const [fp] = filePatches.getFilePatches();
      const mfp = filePatches.clone({
        filePatches: [fp.clone({
          oldFile: fp.getOldFile().clone({mode: '100644'}),
          newFile: fp.getNewFile().clone({mode: '100755'}),
        })],
      });

      const wrapper = mount(buildApp({multiFilePatch: mfp, stagingStatus: 'unstaged'}));

      const meta = wrapper.find('FilePatchMetaView[title="Mode change"]');
      assert.strictEqual(meta.prop('actionIcon'), 'icon-move-down');
      assert.strictEqual(meta.prop('actionText'), 'Stage Mode Change');

      const details = meta.find('.github-FilePatchView-metaDetails');
      assert.strictEqual(details.text(), 'File changed modefrom non executable 100644to executable 100755');
    });

    it("stages or unstages the mode change when the meta container's action is triggered", function() {
      const [fp] = filePatches.getFilePatches();

      const mfp = filePatches.clone({
        filePatches: [fp.clone({
          oldFile: fp.getOldFile().clone({mode: '100644'}),
          newFile: fp.getNewFile().clone({mode: '100755'}),
        })],
      });

      const toggleModeChange = sinon.stub();
      const wrapper = mount(buildApp({multiFilePatch: mfp, stagingStatus: 'staged', toggleModeChange}));

      const meta = wrapper.find('FilePatchMetaView[title="Mode change"]');
      assert.isTrue(meta.exists());
      assert.strictEqual(meta.prop('actionIcon'), 'icon-move-up');
      assert.strictEqual(meta.prop('actionText'), 'Unstage Mode Change');

      meta.prop('action')();
      assert.isTrue(toggleModeChange.called);
    });
  });

  describe('symlink changes', function() {
    it('does not render if the symlink status is unchanged', function() {
      const [fp] = filePatches.getFilePatches();
      const mfp = filePatches.clone({
        filePatches: [fp.clone({
          oldFile: fp.getOldFile().clone({mode: '100644'}),
          newFile: fp.getNewFile().clone({mode: '100755'}),
        })],
      });

      const wrapper = mount(buildApp({multiFilePatch: mfp}));
      assert.lengthOf(wrapper.find('FilePatchMetaView').filterWhere(v => v.prop('title').startsWith('Symlink')), 0);
    });

    it('renders symlink change information within a meta container', function() {
      const [fp] = filePatches.getFilePatches();
      const mfp = filePatches.clone({
        filePatches: [fp.clone({
          oldFile: fp.getOldFile().clone({mode: '120000', symlink: '/old.txt'}),
          newFile: fp.getNewFile().clone({mode: '120000', symlink: '/new.txt'}),
        })],
      });

      const wrapper = mount(buildApp({multiFilePatch: mfp, stagingStatus: 'unstaged'}));
      const meta = wrapper.find('FilePatchMetaView[title="Symlink changed"]');
      assert.isTrue(meta.exists());
      assert.strictEqual(meta.prop('actionIcon'), 'icon-move-down');
      assert.strictEqual(meta.prop('actionText'), 'Stage Symlink Change');
      assert.strictEqual(
        meta.find('.github-FilePatchView-metaDetails').text(),
        'Symlink changedfrom /old.txtto /new.txt.',
      );
    });

    it('stages or unstages the symlink change', function() {
      const toggleSymlinkChange = sinon.stub();
      const [fp] = filePatches.getFilePatches();
      const mfp = filePatches.clone({
        filePatches: [fp.clone({
          oldFile: fp.getOldFile().clone({mode: '120000', symlink: '/old.txt'}),
          newFile: fp.getNewFile().clone({mode: '120000', symlink: '/new.txt'}),
        })],
      });

      const wrapper = mount(buildApp({multiFilePatch: mfp, stagingStatus: 'staged', toggleSymlinkChange}));
      const meta = wrapper.find('FilePatchMetaView[title="Symlink changed"]');
      assert.isTrue(meta.exists());
      assert.strictEqual(meta.prop('actionIcon'), 'icon-move-up');
      assert.strictEqual(meta.prop('actionText'), 'Unstage Symlink Change');

      meta.find('button.icon-move-up').simulate('click');
      assert.isTrue(toggleSymlinkChange.called);
    });

    it('renders details for a symlink deletion', function() {
      const [fp] = filePatches.getFilePatches();
      const mfp = filePatches.clone({
        filePatches: [fp.clone({
          oldFile: fp.getOldFile().clone({mode: '120000', symlink: '/old.txt'}),
          newFile: nullFile,
        })],
      });

      const wrapper = mount(buildApp({multiFilePatch: mfp}));
      const meta = wrapper.find('FilePatchMetaView[title="Symlink deleted"]');
      assert.isTrue(meta.exists());
      assert.strictEqual(
        meta.find('.github-FilePatchView-metaDetails').text(),
        'Symlinkto /old.txtdeleted.',
      );
    });

    it('renders details for a symlink creation', function() {
      const [fp] = filePatches.getFilePatches();
      const mfp = filePatches.clone({
        filePatches: [fp.clone({
          oldFile: nullFile,
          newFile: fp.getOldFile().clone({mode: '120000', symlink: '/new.txt'}),
        })],
      });

      const wrapper = mount(buildApp({multiFilePatch: mfp}));
      const meta = wrapper.find('FilePatchMetaView[title="Symlink created"]');
      assert.isTrue(meta.exists());
      assert.strictEqual(
        meta.find('.github-FilePatchView-metaDetails').text(),
        'Symlinkto /new.txtcreated.',
      );
    });
  });

  describe('hunk headers', function() {
    it('renders one for each hunk', function() {
      const {multiFilePatch: mfp} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('path.txt'));
          fp.addHunk(h => {
            h.oldRow(1);
            h.unchanged('0000').added('0001').unchanged('0002');
          });
          fp.addHunk(h => {
            h.oldRow(10);
            h.unchanged('0003').deleted('0004').unchanged('0005');
          });
        }).build();

      const hunks = mfp.getFilePatches()[0].getHunks();
      const wrapper = mount(buildApp({multiFilePatch: mfp}));

      assert.isTrue(wrapper.find('HunkHeaderView').someWhere(h => h.prop('hunk') === hunks[0]));
      assert.isTrue(wrapper.find('HunkHeaderView').someWhere(h => h.prop('hunk') === hunks[1]));
    });

    it('pluralizes the toggle and discard button labels', function() {
      const wrapper = shallow(buildApp({selectedRows: new Set([2]), selectionMode: 'line'}));
      assert.strictEqual(wrapper.find('HunkHeaderView').at(0).prop('toggleSelectionLabel'), 'Stage Selected Line');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(0).prop('discardSelectionLabel'), 'Discard Selected Line');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(1).prop('toggleSelectionLabel'), 'Stage Hunk');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(1).prop('discardSelectionLabel'), 'Discard Hunk');

      wrapper.setProps({selectedRows: new Set([1, 2, 3]), selectionMode: 'line'});
      assert.strictEqual(wrapper.find('HunkHeaderView').at(0).prop('toggleSelectionLabel'), 'Stage Selected Lines');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(0).prop('discardSelectionLabel'), 'Discard Selected Lines');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(1).prop('toggleSelectionLabel'), 'Stage Hunk');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(1).prop('discardSelectionLabel'), 'Discard Hunk');

      wrapper.setProps({selectedRows: new Set([1, 2, 3]), selectionMode: 'hunk'});
      assert.strictEqual(wrapper.find('HunkHeaderView').at(0).prop('toggleSelectionLabel'), 'Stage Hunk');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(0).prop('discardSelectionLabel'), 'Discard Hunk');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(1).prop('toggleSelectionLabel'), 'Stage Hunk');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(1).prop('discardSelectionLabel'), 'Discard Hunk');

      wrapper.setProps({selectedRows: new Set([1, 2, 3, 6, 7]), selectionMode: 'hunk'});
      assert.strictEqual(wrapper.find('HunkHeaderView').at(0).prop('toggleSelectionLabel'), 'Stage Hunks');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(0).prop('discardSelectionLabel'), 'Discard Hunks');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(1).prop('toggleSelectionLabel'), 'Stage Hunks');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(1).prop('discardSelectionLabel'), 'Discard Hunks');
    });

    it('uses the appropriate staging action verb in hunk header button labels', function() {
      const wrapper = shallow(buildApp({
        selectedRows: new Set([2]),
        stagingStatus: 'unstaged',
        selectionMode: 'line',
      }));
      assert.strictEqual(wrapper.find('HunkHeaderView').at(0).prop('toggleSelectionLabel'), 'Stage Selected Line');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(1).prop('toggleSelectionLabel'), 'Stage Hunk');

      wrapper.setProps({stagingStatus: 'staged'});
      assert.strictEqual(wrapper.find('HunkHeaderView').at(0).prop('toggleSelectionLabel'), 'Unstage Selected Line');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(1).prop('toggleSelectionLabel'), 'Unstage Hunk');
    });

    it('uses the appropriate staging action noun in hunk header button labels', function() {
      const wrapper = shallow(buildApp({
        selectedRows: new Set([1, 2, 3]),
        stagingStatus: 'unstaged',
        selectionMode: 'line',
      }));

      assert.strictEqual(wrapper.find('HunkHeaderView').at(0).prop('toggleSelectionLabel'), 'Stage Selected Lines');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(1).prop('toggleSelectionLabel'), 'Stage Hunk');

      wrapper.setProps({selectionMode: 'hunk'});

      assert.strictEqual(wrapper.find('HunkHeaderView').at(0).prop('toggleSelectionLabel'), 'Stage Hunk');
      assert.strictEqual(wrapper.find('HunkHeaderView').at(1).prop('toggleSelectionLabel'), 'Stage Hunk');
    });

    it('handles mousedown as a selection event', function() {
      const {multiFilePatch: mfp} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('path.txt'));
          fp.addHunk(h => {
            h.oldRow(1);
            h.unchanged('0000').added('0001').unchanged('0002');
          });
          fp.addHunk(h => {
            h.oldRow(10);
            h.unchanged('0003').deleted('0004').unchanged('0005');
          });
        }).build();

      const selectedRowsChanged = sinon.spy();
      const wrapper = mount(buildApp({multiFilePatch: mfp, selectedRowsChanged, selectionMode: 'line'}));

      wrapper.find('HunkHeaderView').at(1).prop('mouseDown')({button: 0}, mfp.getFilePatches()[0].getHunks()[1]);

      assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [4]);
      assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'hunk');
    });

    it('handles a toggle click on a hunk containing a selection', function() {
      const toggleRows = sinon.spy();
      const wrapper = mount(buildApp({selectedRows: new Set([2]), toggleRows, selectionMode: 'line'}));

      wrapper.find('HunkHeaderView').at(0).prop('toggleSelection')();
      assert.sameMembers(Array.from(toggleRows.lastCall.args[0]), [2]);
      assert.strictEqual(toggleRows.lastCall.args[1], 'line');
    });

    it('handles a toggle click on a hunk not containing a selection', function() {
      const toggleRows = sinon.spy();
      const wrapper = mount(buildApp({selectedRows: new Set([2]), toggleRows, selectionMode: 'line'}));

      wrapper.find('HunkHeaderView').at(1).prop('toggleSelection')();
      assert.sameMembers(Array.from(toggleRows.lastCall.args[0]), [6, 7]);
      assert.strictEqual(toggleRows.lastCall.args[1], 'hunk');
    });

    it('handles a discard click on a hunk containing a selection', function() {
      const discardRows = sinon.spy();
      const wrapper = mount(buildApp({selectedRows: new Set([2]), discardRows, selectionMode: 'line'}));

      wrapper.find('HunkHeaderView').at(0).prop('discardSelection')();
      assert.sameMembers(Array.from(discardRows.lastCall.args[0]), [2]);
      assert.strictEqual(discardRows.lastCall.args[1], 'line');
    });

    it('handles a discard click on a hunk not containing a selection', function() {
      const discardRows = sinon.spy();
      const wrapper = mount(buildApp({selectedRows: new Set([2]), discardRows, selectionMode: 'line'}));

      wrapper.find('HunkHeaderView').at(1).prop('discardSelection')();
      assert.sameMembers(Array.from(discardRows.lastCall.args[0]), [6, 7]);
      assert.strictEqual(discardRows.lastCall.args[1], 'hunk');
    });
  });

  describe('custom gutters', function() {
    let wrapper, instance, editor;

    beforeEach(function() {
      wrapper = mount(buildApp());
      instance = wrapper.instance();
      editor = wrapper.find('AtomTextEditor').instance().getModel();
    });

    it('computes the old line number for a buffer row', function() {
      assert.strictEqual(instance.oldLineNumberLabel({bufferRow: 5, softWrapped: false}), '\u00a08');
      assert.strictEqual(instance.oldLineNumberLabel({bufferRow: 6, softWrapped: false}), '\u00a0\u00a0');
      assert.strictEqual(instance.oldLineNumberLabel({bufferRow: 6, softWrapped: true}), '\u00a0\u00a0');
      assert.strictEqual(instance.oldLineNumberLabel({bufferRow: 7, softWrapped: false}), '\u00a09');
      assert.strictEqual(instance.oldLineNumberLabel({bufferRow: 8, softWrapped: false}), '10');
      assert.strictEqual(instance.oldLineNumberLabel({bufferRow: 8, softWrapped: true}), '\u00a0•');

      assert.strictEqual(instance.oldLineNumberLabel({bufferRow: 999, softWrapped: false}), '\u00a0\u00a0');
    });

    it('computes the new line number for a buffer row', function() {
      assert.strictEqual(instance.newLineNumberLabel({bufferRow: 5, softWrapped: false}), '\u00a09');
      assert.strictEqual(instance.newLineNumberLabel({bufferRow: 6, softWrapped: false}), '10');
      assert.strictEqual(instance.newLineNumberLabel({bufferRow: 6, softWrapped: true}), '\u00a0•');
      assert.strictEqual(instance.newLineNumberLabel({bufferRow: 7, softWrapped: false}), '\u00a0\u00a0');
      assert.strictEqual(instance.newLineNumberLabel({bufferRow: 7, softWrapped: true}), '\u00a0\u00a0');
      assert.strictEqual(instance.newLineNumberLabel({bufferRow: 8, softWrapped: false}), '11');

      assert.strictEqual(instance.newLineNumberLabel({bufferRow: 999, softWrapped: false}), '\u00a0\u00a0');
    });

    it('renders diff region scope characters when the config option is enabled', function() {
      atomEnv.config.set('github.showDiffIconGutter', true);

      wrapper.update();
      const gutter = wrapper.find('Gutter[name="diff-icons"]');
      assert.isTrue(gutter.exists());

      const assertLayerDecorated = layer => {
        const layerWrapper = wrapper.find('MarkerLayer').filterWhere(each => each.prop('external') === layer);
        const decorations = layerWrapper.find('Decoration[type="line-number"][gutterName="diff-icons"]');
        assert.isTrue(decorations.exists());
      };

      assertLayerDecorated(filePatches.getAdditionLayer());
      assertLayerDecorated(filePatches.getDeletionLayer());

      atomEnv.config.set('github.showDiffIconGutter', false);
      wrapper.update();
      assert.isFalse(wrapper.find('Gutter[name="diff-icons"]').exists());
    });

    it('selects a single line on click', function() {
      instance.didMouseDownOnLineNumber({bufferRow: 2, domEvent: {button: 0}});
      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
        [[2, 0], [2, 4]],
      ]);
    });

    it('changes to line selection mode on click', function() {
      const selectedRowsChanged = sinon.spy();
      wrapper.setProps({selectedRowsChanged, selectionMode: 'hunk'});

      instance.didMouseDownOnLineNumber({bufferRow: 2, domEvent: {button: 0}});
      assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [2]);
      assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'line');
    });

    it('ignores right clicks', function() {
      instance.didMouseDownOnLineNumber({bufferRow: 2, domEvent: {button: 1}});
      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
        [[0, 0], [4, 4]],
      ]);
    });

    if (process.platform !== 'win32') {
      it('ignores ctrl-clicks on non-Windows platforms', function() {
        instance.didMouseDownOnLineNumber({bufferRow: 2, domEvent: {button: 0, ctrlKey: true}});
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[0, 0], [4, 4]],
        ]);
      });
    }

    it('selects a range of lines on click and drag', function() {
      instance.didMouseDownOnLineNumber({bufferRow: 2, domEvent: {button: 0}});
      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
        [[2, 0], [2, 4]],
      ]);

      instance.didMouseMoveOnLineNumber({bufferRow: 2, domEvent: {button: 0}});
      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
        [[2, 0], [2, 4]],
      ]);

      instance.didMouseMoveOnLineNumber({bufferRow: 3, domEvent: {button: 0}});
      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
        [[2, 0], [3, 4]],
      ]);

      instance.didMouseMoveOnLineNumber({bufferRow: 3, domEvent: {button: 0}});
      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
        [[2, 0], [3, 4]],
      ]);

      instance.didMouseMoveOnLineNumber({bufferRow: 4, domEvent: {button: 0}});
      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
        [[2, 0], [4, 4]],
      ]);

      instance.didMouseUp();
      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
        [[2, 0], [4, 4]],
      ]);

      instance.didMouseMoveOnLineNumber({bufferRow: 5, domEvent: {button: 0}});
      // Unchanged after mouse up
      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
        [[2, 0], [4, 4]],
      ]);
    });

    describe('shift-click', function() {
      it('selects a range of lines', function() {
        instance.didMouseDownOnLineNumber({bufferRow: 2, domEvent: {button: 0}});
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[2, 0], [2, 4]],
        ]);
        instance.didMouseUp();

        instance.didMouseDownOnLineNumber({bufferRow: 4, domEvent: {shiftKey: true, button: 0}});
        instance.didMouseUp();
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[2, 0], [4, 4]],
        ]);
      });

      it("extends to the range's beginning when the selection is reversed", function() {
        editor.setSelectedBufferRange([[4, 4], [2, 0]], {reversed: true});

        instance.didMouseDownOnLineNumber({bufferRow: 6, domEvent: {shiftKey: true, button: 0}});
        assert.isFalse(editor.getLastSelection().isReversed());
        assert.deepEqual(editor.getLastSelection().getBufferRange().serialize(), [[2, 0], [6, 4]]);
      });

      it('reverses the selection if the extension line is before the existing selection', function() {
        editor.setSelectedBufferRange([[3, 0], [4, 4]]);

        instance.didMouseDownOnLineNumber({bufferRow: 1, domEvent: {shiftKey: true, button: 0}});
        assert.isTrue(editor.getLastSelection().isReversed());
        assert.deepEqual(editor.getLastSelection().getBufferRange().serialize(), [[1, 0], [4, 4]]);
      });
    });

    describe('ctrl- or meta-click', function() {
      beforeEach(function() {
        // Select an initial row range.
        instance.didMouseDownOnLineNumber({bufferRow: 2, domEvent: {button: 0}});
        instance.didMouseDownOnLineNumber({bufferRow: 5, domEvent: {shiftKey: true, button: 0}});
        instance.didMouseUp();
        // [[2, 0], [5, 4]]
      });

      it('deselects a line at the beginning of an existing selection', function() {
        instance.didMouseDownOnLineNumber({bufferRow: 2, domEvent: {metaKey: true, button: 0}});
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[3, 0], [5, 4]],
        ]);
      });

      it('deselects a line within an existing selection', function() {
        instance.didMouseDownOnLineNumber({bufferRow: 3, domEvent: {metaKey: true, button: 0}});
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[2, 0], [2, 4]],
          [[4, 0], [5, 4]],
        ]);
      });

      it('deselects a line at the end of an existing selection', function() {
        instance.didMouseDownOnLineNumber({bufferRow: 5, domEvent: {metaKey: true, button: 0}});
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[2, 0], [4, 4]],
        ]);
      });

      it('selects a line outside of an existing selection', function() {
        instance.didMouseDownOnLineNumber({bufferRow: 8, domEvent: {metaKey: true, button: 0}});
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[2, 0], [5, 4]],
          [[8, 0], [8, 4]],
        ]);
      });

      it('deselects the only line within an existing selection', function() {
        instance.didMouseDownOnLineNumber({bufferRow: 7, domEvent: {metaKey: true, button: 0}});
        instance.didMouseUp();
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[2, 0], [5, 4]],
          [[7, 0], [7, 4]],
        ]);

        instance.didMouseDownOnLineNumber({bufferRow: 7, domEvent: {metaKey: true, button: 0}});
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[2, 0], [5, 4]],
        ]);
      });

      it('cannot deselect the only selection', function() {
        instance.didMouseDownOnLineNumber({bufferRow: 7, domEvent: {button: 0}});
        instance.didMouseUp();
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[7, 0], [7, 4]],
        ]);

        instance.didMouseDownOnLineNumber({bufferRow: 7, domEvent: {metaKey: true, button: 0}});
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[7, 0], [7, 4]],
        ]);
      });

      it('bonus points: understands ranges that do not cleanly align with editor rows', function() {
        instance.handleSelectionEvent({metaKey: true, button: 0}, [[3, 1], [5, 2]]);
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[2, 0], [3, 1]],
          [[5, 2], [5, 4]],
        ]);
      });
    });

    it('does nothing on a click without a buffer row', function() {
      instance.didMouseDownOnLineNumber({bufferRow: NaN, domEvent: {button: 0}});
      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
        [[0, 0], [4, 4]],
      ]);

      instance.didMouseDownOnLineNumber({bufferRow: undefined, domEvent: {button: 0}});
      assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
        [[0, 0], [4, 4]],
      ]);
    });
  });

  describe('hunk lines', function() {
    let linesPatch;

    beforeEach(function() {

      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('path.txt'));
          fp.addHunk(h => {
            h.oldRow(1);
            h.unchanged('0000').added('0001', '0002').deleted('0003').added('0004').added('0005').unchanged('0006');
          });
          fp.addHunk(h => {
            h.oldRow(10);
            h.unchanged('0007').deleted('0008', '0009', '0010').unchanged('0011').added('0012', '0013', '0014').deleted('0015').unchanged('0016').noNewline();
          });
        }).build();
      linesPatch = multiFilePatch;
    });

    it('decorates added lines', function() {
      const wrapper = mount(buildApp({multiFilePatch: linesPatch}));

      const decorationSelector = 'Decoration[type="line"][className="github-FilePatchView-line--added"]';
      const decoration = wrapper.find(decorationSelector);
      assert.isTrue(decoration.exists());

      const layer = wrapper.find('MarkerLayer').filterWhere(each => each.find(decorationSelector).exists());
      assert.strictEqual(layer.prop('external'), linesPatch.getAdditionLayer());
    });

    it('decorates deleted lines', function() {
      const wrapper = mount(buildApp({multiFilePatch: linesPatch}));

      const decorationSelector = 'Decoration[type="line"][className="github-FilePatchView-line--deleted"]';
      const decoration = wrapper.find(decorationSelector);
      assert.isTrue(decoration.exists());

      const layer = wrapper.find('MarkerLayer').filterWhere(each => each.find(decorationSelector).exists());
      assert.strictEqual(layer.prop('external'), linesPatch.getDeletionLayer());
    });

    it('decorates the nonewline line', function() {
      const wrapper = mount(buildApp({multiFilePatch: linesPatch}));

      const decorationSelector = 'Decoration[type="line"][className="github-FilePatchView-line--nonewline"]';
      const decoration = wrapper.find(decorationSelector);
      assert.isTrue(decoration.exists());

      const layer = wrapper.find('MarkerLayer').filterWhere(each => each.find(decorationSelector).exists());
      assert.strictEqual(layer.prop('external'), linesPatch.getNoNewlineLayer());
    });
  });

  describe('editor selection change notification', function() {
    let multiFilePatch;

    beforeEach(function() {
      multiFilePatch = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('0'));
          fp.addHunk(h => h.oldRow(1).unchanged('0').added('1', '2').deleted('3').unchanged('4'));
          fp.addHunk(h => h.oldRow(10).unchanged('5').added('6', '7').deleted('8').unchanged('9'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('1'));
          fp.addHunk(h => h.oldRow(1).unchanged('10').added('11', '12').deleted('13').unchanged('14'));
          fp.addHunk(h => h.oldRow(10).unchanged('15').added('16', '17').deleted('18').unchanged('19'));
        })
        .build()
        .multiFilePatch;
    });

    it('notifies a callback when the selected rows change', function() {
      const selectedRowsChanged = sinon.spy();
      const wrapper = mount(buildApp({multiFilePatch, selectedRowsChanged}));
      const editor = wrapper.find('AtomTextEditor').instance().getModel();

      selectedRowsChanged.resetHistory();

      editor.setSelectedBufferRange([[5, 1], [6, 2]]);

      assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [6]);
      assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'hunk');
      assert.isFalse(selectedRowsChanged.lastCall.args[2]);

      selectedRowsChanged.resetHistory();

      // Same rows
      editor.setSelectedBufferRange([[5, 0], [6, 3]]);
      assert.isFalse(selectedRowsChanged.called);

      // Start row is different
      editor.setSelectedBufferRange([[4, 0], [6, 3]]);

      assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [6]);
      assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'hunk');
      assert.isFalse(selectedRowsChanged.lastCall.args[2]);

      selectedRowsChanged.resetHistory();

      // End row is different
      editor.setSelectedBufferRange([[4, 0], [7, 3]]);

      assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [6, 7]);
      assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'hunk');
      assert.isFalse(selectedRowsChanged.lastCall.args[2]);
    });

    it('notifies a callback when cursors span multiple files', function() {
      const selectedRowsChanged = sinon.spy();
      const wrapper = mount(buildApp({multiFilePatch, selectedRowsChanged}));
      const editor = wrapper.find('AtomTextEditor').instance().getModel();

      selectedRowsChanged.resetHistory();
      editor.setSelectedBufferRanges([
        [[5, 0], [5, 0]],
        [[16, 0], [16, 0]],
      ]);

      assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [16]);
      assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'hunk');
      assert.isTrue(selectedRowsChanged.lastCall.args[2]);
    });
  });

  describe('when viewing an empty patch', function() {
    it('renders an empty patch message', function() {
      const {multiFilePatch: emptyMfp} = multiFilePatchBuilder().build();
      const wrapper = shallow(buildApp({multiFilePatch: emptyMfp}));
      assert.isTrue(wrapper.find('.github-FilePatchView').hasClass('github-FilePatchView--blank'));
      assert.isTrue(wrapper.find('.github-FilePatchView-message').exists());
    });

    it('shows navigation controls', function() {
      const wrapper = shallow(buildApp({filePatch: FilePatch.createNull()}));
      assert.isTrue(wrapper.find('FilePatchHeaderView').exists());
    });
  });

  describe('registers Atom commands', function() {
    it('toggles all mode changes', function() {
      function tenLineHunk(builder) {
        builder.addHunk(h => {
          for (let i = 0; i < 10; i++) {
            h.added('xxxxx');
          }
        });
      }

      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('f0'));
          tenLineHunk(fp);
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('f1'));
          fp.setNewFile(f => f.path('f1').executable());
          tenLineHunk(fp);
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('f2'));
          tenLineHunk(fp);
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('f3').executable());
          fp.setNewFile(f => f.path('f3'));
          tenLineHunk(fp);
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('f4').executable());
          tenLineHunk(fp);
        })
        .build();
      const toggleModeChange = sinon.spy();
      const wrapper = mount(buildApp({toggleModeChange, multiFilePatch}));

      const editor = wrapper.find('AtomTextEditor').instance().getModel();
      editor.setSelectedBufferRanges([
        [[5, 0], [5, 2]],
        [[37, 0], [42, 0]],
      ]);

      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:stage-file-mode-change');

      const [fp0, fp1, fp2, fp3, fp4] = multiFilePatch.getFilePatches();

      assert.isFalse(toggleModeChange.calledWith(fp0));
      assert.isFalse(toggleModeChange.calledWith(fp1));
      assert.isFalse(toggleModeChange.calledWith(fp2));
      assert.isTrue(toggleModeChange.calledWith(fp3));
      assert.isFalse(toggleModeChange.calledWith(fp4));
    });

    it('toggles all symlink changes', function() {
      function tenLineHunk(builder) {
        builder.addHunk(h => {
          for (let i = 0; i < 10; i++) {
            h.added('zzzzz');
          }
        });
      }

      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.status('deleted');
          fp.setOldFile(f => f.path('f0').symlinkTo('elsewhere'));
          fp.nullNewFile();
        })
        .addFilePatch(fp => {
          fp.status('added');
          fp.nullOldFile();
          fp.setNewFile(f => f.path('f0'));
          tenLineHunk(fp);
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('f1'));
          tenLineHunk(fp);
        })
        .addFilePatch(fp => {
          fp.status('deleted');
          fp.setOldFile(f => f.path('f2').symlinkTo('somewhere'));
          fp.nullNewFile();
        })
        .addFilePatch(fp => {
          fp.status('added');
          fp.nullOldFile();
          fp.setNewFile(f => f.path('f2'));
          tenLineHunk(fp);
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('f3'));
          tenLineHunk(fp);
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('f4').executable());
          tenLineHunk(fp);
        })
        .build();

      const toggleSymlinkChange = sinon.spy();
      const wrapper = mount(buildApp({toggleSymlinkChange, multiFilePatch}));

      const editor = wrapper.find('AtomTextEditor').instance().getModel();
      editor.setSelectedBufferRanges([
        [[0, 0], [2, 2]],
        [[5, 1], [6, 2]],
        [[37, 0], [37, 0]],
      ]);

      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:stage-symlink-change');

      const [fp0, fp1, fp2, fp3, fp4] = multiFilePatch.getFilePatches();

      assert.isTrue(toggleSymlinkChange.calledWith(fp0));
      assert.isFalse(toggleSymlinkChange.calledWith(fp1));
      assert.isFalse(toggleSymlinkChange.calledWith(fp2));
      assert.isFalse(toggleSymlinkChange.calledWith(fp3));
      assert.isFalse(toggleSymlinkChange.calledWith(fp4));
    });

    it('registers file mode and symlink commands depending on the staging status', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.status('deleted');
          fp.setOldFile(f => f.path('f0').symlinkTo('elsewhere'));
          fp.nullNewFile();
        })
        .addFilePatch(fp => {
          fp.status('added');
          fp.nullOldFile();
          fp.setNewFile(f => f.path('f0'));
          fp.addHunk(h => h.added('0'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('f1'));
          fp.setNewFile(f => f.path('f1').executable());
          fp.addHunk(h => h.added('0'));
        })
        .build();

      const wrapper = shallow(buildApp({multiFilePatch, stagingStatus: 'unstaged'}));

      assert.isTrue(wrapper.exists('Command[command="github:stage-file-mode-change"]'));
      assert.isTrue(wrapper.exists('Command[command="github:stage-symlink-change"]'));
      assert.isFalse(wrapper.exists('Command[command="github:unstage-file-mode-change"]'));
      assert.isFalse(wrapper.exists('Command[command="github:unstage-symlink-change"]'));

      wrapper.setProps({stagingStatus: 'staged'});

      assert.isFalse(wrapper.exists('Command[command="github:stage-file-mode-change"]'));
      assert.isFalse(wrapper.exists('Command[command="github:stage-symlink-change"]'));
      assert.isTrue(wrapper.exists('Command[command="github:unstage-file-mode-change"]'));
      assert.isTrue(wrapper.exists('Command[command="github:unstage-symlink-change"]'));
    });

    it('toggles the current selection', function() {
      const toggleRows = sinon.spy();
      const wrapper = mount(buildApp({toggleRows}));

      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'core:confirm');

      assert.isTrue(toggleRows.called);
    });

    it('undoes the last discard', function() {
      const undoLastDiscard = sinon.spy();
      const wrapper = mount(buildApp({undoLastDiscard, hasUndoHistory: true, itemType: ChangedFileItem}));

      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'core:undo');

      const [filePatch] = filePatches.getFilePatches();
      assert.isTrue(undoLastDiscard.calledWith(filePatch, {eventSource: {command: 'core:undo'}}));
    });

    it('does nothing when there is no last discard to undo', function() {
      const undoLastDiscard = sinon.spy();
      const wrapper = mount(buildApp({undoLastDiscard, hasUndoHistory: false}));

      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'core:undo');

      assert.isFalse(undoLastDiscard.called);
    });

    it('discards selected rows', function() {
      const discardRows = sinon.spy();
      const wrapper = mount(buildApp({discardRows, selectedRows: new Set([1, 2]), selectionMode: 'line'}));

      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:discard-selected-lines');

      assert.isTrue(discardRows.called);
      assert.sameMembers(Array.from(discardRows.lastCall.args[0]), [1, 2]);
      assert.strictEqual(discardRows.lastCall.args[1], 'line');
      assert.deepEqual(discardRows.lastCall.args[2], {eventSource: {command: 'github:discard-selected-lines'}});
    });

    it('toggles the patch selection mode from line to hunk', function() {
      const selectedRowsChanged = sinon.spy();
      const selectedRows = new Set([2]);
      const wrapper = mount(buildApp({selectedRowsChanged, selectedRows, selectionMode: 'line'}));
      const editor = wrapper.find('AtomTextEditor').instance().getModel();
      editor.setSelectedBufferRanges([[[2, 0], [2, 0]]]);

      selectedRowsChanged.resetHistory();
      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:toggle-patch-selection-mode');

      assert.isTrue(selectedRowsChanged.called);
      assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [1, 2, 3]);
      assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'hunk');
    });

    it('toggles from line to hunk when no change rows are selected', function() {
      const selectedRowsChanged = sinon.spy();
      const selectedRows = new Set([]);
      const wrapper = mount(buildApp({selectedRowsChanged, selectedRows, selectionMode: 'line'}));
      const editor = wrapper.find('AtomTextEditor').instance().getModel();
      editor.setSelectedBufferRanges([[[5, 0], [5, 2]]]);

      selectedRowsChanged.resetHistory();
      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:toggle-patch-selection-mode');

      assert.isTrue(selectedRowsChanged.called);
      assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [6, 7]);
      assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'hunk');
    });

    it('toggles the patch selection mode from hunk to line', function() {
      const selectedRowsChanged = sinon.spy();
      const selectedRows = new Set([6, 7]);
      const wrapper = mount(buildApp({selectedRowsChanged, selectedRows, selectionMode: 'hunk'}));
      const editor = wrapper.find('AtomTextEditor').instance().getModel();
      editor.setSelectedBufferRanges([[[5, 0], [8, 4]]]);

      selectedRowsChanged.resetHistory();

      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:toggle-patch-selection-mode');

      assert.isTrue(selectedRowsChanged.called);
      assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [6]);
      assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'line');
    });

    it('surfaces focus to the git tab', function() {
      const surface = sinon.spy();
      const wrapper = mount(buildApp({surface}));

      atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:surface');
      assert.isTrue(surface.called);
    });

    describe('hunk mode navigation', function() {
      let mfp;

      beforeEach(function() {
        const {multiFilePatch} = multiFilePatchBuilder().addFilePatch(fp => {
          fp.setOldFile(f => f.path('path.txt'));
          fp.addHunk(h => {
            h.oldRow(4);
            h.unchanged('0000').added('0001').unchanged('0002');
          });
          fp.addHunk(h => {
            h.oldRow(10);
            h.unchanged('0003').deleted('0004').unchanged('0005');
          });
          fp.addHunk(h => {
            h.oldRow(20);
            h.unchanged('0006').added('0007').unchanged('0008');
          });
          fp.addHunk(h => {
            h.oldRow(30);
            h.unchanged('0009').added('0010').unchanged('0011');
          });
          fp.addHunk(h => {
            h.oldRow(40);
            h.unchanged('0012').deleted('0013', '0014').unchanged('0015');
          });
        }).build();
        mfp = multiFilePatch;
      });

      it('advances the selection to the next hunks', function() {
        const selectedRowsChanged = sinon.spy();
        const selectedRows = new Set([1, 7, 10]);
        const wrapper = mount(buildApp({multiFilePatch: mfp, selectedRowsChanged, selectedRows, selectionMode: 'hunk'}));
        const editor = wrapper.find('AtomTextEditor').instance().getModel();
        editor.setSelectedBufferRanges([
          [[0, 0], [2, 4]], // hunk 0
          [[6, 0], [8, 4]], // hunk 2
          [[9, 0], [11, 0]], // hunk 3
        ]);

        selectedRowsChanged.resetHistory();
        atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:select-next-hunk');

        assert.isTrue(selectedRowsChanged.called);
        assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [4, 10, 13, 14]);
        assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'hunk');
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[3, 0], [5, 4]], // hunk 1
          [[9, 0], [11, 4]], // hunk 3
          [[12, 0], [15, 4]], // hunk 4
        ]);
      });

      it('does not advance a selected hunk at the end of the patch', function() {
        const selectedRowsChanged = sinon.spy();
        const selectedRows = new Set([4, 13, 14]);
        const wrapper = mount(buildApp({multiFilePatch: mfp, selectedRowsChanged, selectedRows, selectionMode: 'hunk'}));
        const editor = wrapper.find('AtomTextEditor').instance().getModel();
        editor.setSelectedBufferRanges([
          [[3, 0], [5, 4]], // hunk 1
          [[12, 0], [15, 4]], // hunk 4
        ]);

        selectedRowsChanged.resetHistory();
        atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:select-next-hunk');

        assert.isTrue(selectedRowsChanged.called);
        assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [7, 13, 14]);
        assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'hunk');
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[6, 0], [8, 4]], // hunk 2
          [[12, 0], [15, 4]], // hunk 4
        ]);
      });

      it('retreats the selection to the previous hunks', function() {
        const selectedRowsChanged = sinon.spy();
        const selectedRows = new Set([4, 10, 13, 14]);
        const wrapper = mount(buildApp({multiFilePatch: mfp, selectedRowsChanged, selectedRows, selectionMode: 'hunk'}));
        const editor = wrapper.find('AtomTextEditor').instance().getModel();
        editor.setSelectedBufferRanges([
          [[3, 0], [5, 4]], // hunk 1
          [[9, 0], [11, 4]], // hunk 3
          [[12, 0], [15, 4]], // hunk 4
        ]);

        selectedRowsChanged.resetHistory();
        atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:select-previous-hunk');

        assert.isTrue(selectedRowsChanged.called);
        assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [1, 7, 10]);
        assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'hunk');
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[0, 0], [2, 4]], // hunk 0
          [[6, 0], [8, 4]], // hunk 2
          [[9, 0], [11, 4]], // hunk 3
        ]);
      });

      it('does not retreat a selected hunk at the beginning of the patch', function() {
        const selectedRowsChanged = sinon.spy();
        const selectedRows = new Set([4, 10, 13, 14]);
        const wrapper = mount(buildApp({multiFilePatch: mfp, selectedRowsChanged, selectedRows, selectionMode: 'hunk'}));
        const editor = wrapper.find('AtomTextEditor').instance().getModel();
        editor.setSelectedBufferRanges([
          [[0, 0], [2, 4]], // hunk 0
          [[12, 0], [15, 4]], // hunk 4
        ]);

        selectedRowsChanged.resetHistory();
        atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:select-previous-hunk');

        assert.isTrue(selectedRowsChanged.called);
        assert.sameMembers(Array.from(selectedRowsChanged.lastCall.args[0]), [1, 10]);
        assert.strictEqual(selectedRowsChanged.lastCall.args[1], 'hunk');
        assert.deepEqual(editor.getSelectedBufferRanges().map(r => r.serialize()), [
          [[0, 0], [2, 4]], // hunk 0
          [[9, 0], [11, 4]], // hunk 3
        ]);
      });
    });

    describe('jump to file', function() {
      let mfp, fp;

      beforeEach(function() {
        const {multiFilePatch} = multiFilePatchBuilder()
          .addFilePatch(filePatch => {
            filePatch.setOldFile(f => f.path('path.txt'));
            filePatch.addHunk(h => {
              h.oldRow(2);
              h.unchanged('0000').added('0001').unchanged('0002');
            });
            filePatch.addHunk(h => {
              h.oldRow(10);
              h.unchanged('0003').added('0004', '0005').deleted('0006').unchanged('0007').added('0008').deleted('0009').unchanged('0010');
            });
          })
          .addFilePatch(filePatch => {
            filePatch.setOldFile(f => f.path('other.txt'));
            filePatch.addHunk(h => {
              h.oldRow(10);
              h.unchanged('0011').added('0012').unchanged('0013');
            });
          })
          .build();

        mfp = multiFilePatch;
        fp = mfp.getFilePatches()[0];
      });

      it('opens the file at the current unchanged row', function() {
        const openFile = sinon.spy();
        const wrapper = mount(buildApp({multiFilePatch: mfp, openFile}));

        const editor = wrapper.find('AtomTextEditor').instance().getModel();
        editor.setCursorBufferPosition([7, 2]);

        atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:jump-to-file');
        assert.isTrue(openFile.calledWith(fp, [[13, 2]], true));
      });

      it('opens the file at a current added row', function() {
        const openFile = sinon.spy();
        const wrapper = mount(buildApp({multiFilePatch: mfp, openFile}));

        const editor = wrapper.find('AtomTextEditor').instance().getModel();
        editor.setCursorBufferPosition([8, 3]);

        atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:jump-to-file');

        assert.isTrue(openFile.calledWith(fp, [[14, 3]], true));
      });

      it('opens the file at the beginning of the previous added or unchanged row', function() {
        const openFile = sinon.spy();
        const wrapper = mount(buildApp({multiFilePatch: mfp, openFile}));

        const editor = wrapper.find('AtomTextEditor').instance().getModel();
        editor.setCursorBufferPosition([9, 2]);

        atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:jump-to-file');

        assert.isTrue(openFile.calledWith(fp, [[15, 0]], true));
      });

      it('preserves multiple cursors', function() {
        const openFile = sinon.spy();
        const wrapper = mount(buildApp({multiFilePatch: mfp, openFile}));

        const editor = wrapper.find('AtomTextEditor').instance().getModel();
        editor.setCursorBufferPosition([3, 2]);
        editor.addCursorAtBufferPosition([4, 2]);
        editor.addCursorAtBufferPosition([1, 3]);
        editor.addCursorAtBufferPosition([9, 2]);
        editor.addCursorAtBufferPosition([9, 3]);

        // [9, 2] and [9, 3] should be collapsed into a single cursor at [15, 0]

        atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:jump-to-file');

        assert.isTrue(openFile.calledWith(fp, [
          [10, 2],
          [11, 2],
          [2, 3],
          [15, 0],
        ], true));
      });

      it('opens non-pending editors when opening multiple', function() {
        const openFile = sinon.spy();
        const wrapper = mount(buildApp({multiFilePatch: mfp, openFile}));

        const editor = wrapper.find('AtomTextEditor').instance().getModel();
        editor.setSelectedBufferRanges([
          [[4, 0], [4, 0]],
          [[12, 0], [12, 0]],
        ]);

        atomEnv.commands.dispatch(wrapper.getDOMNode(), 'github:jump-to-file');

        assert.isTrue(openFile.calledWith(mfp.getFilePatches()[0], [[11, 0]], false));
        assert.isTrue(openFile.calledWith(mfp.getFilePatches()[1], [[10, 0]], false));
      });

      describe('didOpenFile(selectedFilePatch)', function() {
        describe('when there is a selection in the selectedFilePatch', function() {
          it('opens the file and places the cursor corresponding to the selection', function() {
            const openFile = sinon.spy();
            const wrapper = mount(buildApp({multiFilePatch: mfp, openFile}));

            const editor = wrapper.find('AtomTextEditor').instance().getModel();
            editor.setSelectedBufferRanges([
              [[4, 0], [4, 0]], // cursor in first file patch
            ]);

            // click button for first file
            wrapper.find('.github-FilePatchHeaderView-jumpToFileButton').at(0).simulate('click');

            assert.isTrue(openFile.calledWith(mfp.getFilePatches()[0], [[11, 0]], true));
          });
        });

        describe('when there are no selections in the selectedFilePatch', function() {
          it('opens the file and places the cursor at the beginning of the first hunk', function() {
            const openFile = sinon.spy();
            const wrapper = mount(buildApp({multiFilePatch: mfp, openFile}));

            const editor = wrapper.find('AtomTextEditor').instance().getModel();
            editor.setSelectedBufferRanges([
              [[4, 0], [4, 0]], // cursor in first file patch
            ]);

            // click button for second file
            wrapper.find('.github-FilePatchHeaderView-jumpToFileButton').at(1).simulate('click');

            const secondFilePatch = mfp.getFilePatches()[1];
            const firstHunkBufferRow = secondFilePatch.getHunks()[0].getNewStartRow() - 1;

            assert.isTrue(openFile.calledWith(secondFilePatch, [[firstHunkBufferRow, 0]], true));
          });
        });
      });
    });
  });

  describe('large diff gate', function() {
    let wrapper, mfp;

    beforeEach(function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.renderStatus(DEFERRED);
        }).build();
      mfp = multiFilePatch;
      wrapper = mount(buildApp({multiFilePatch: mfp}));
    });

    it('displays diff gate when diff exceeds a certain number of lines', function() {
      assert.include(
        wrapper.find('.github-FilePatchView-controlBlock .github-FilePatchView-message').first().text(),
        'Large diffs are collapsed by default for performance reasons.',
      );
      assert.isTrue(wrapper.find('.github-FilePatchView-showDiffButton').exists());
      assert.isFalse(wrapper.find('.github-HunkHeaderView').exists());
    });

    it('loads large diff and sends event when show diff button is clicked', function() {
      const addEventStub = sinon.stub(reporterProxy, 'addEvent');
      const expandFilePatch = sinon.spy(mfp, 'expandFilePatch');

      assert.isFalse(addEventStub.called);
      wrapper.find('.github-FilePatchView-showDiffButton').first().simulate('click');
      wrapper.update();

      assert.isTrue(addEventStub.calledOnce);
      assert.deepEqual(addEventStub.lastCall.args, ['expand-file-patch', {component: 'MultiFilePatchView', package: 'github'}]);
      assert.isTrue(expandFilePatch.calledOnce);
    });

    it('does not display diff gate if diff size is below large diff threshold', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.renderStatus(EXPANDED);
        }).build();
      mfp = multiFilePatch;
      wrapper = mount(buildApp({multiFilePatch: mfp}));
      assert.isFalse(wrapper.find('.github-FilePatchView-showDiffButton').exists());
      assert.isTrue(wrapper.find('.github-HunkHeaderView').exists());
    });
  });

  describe('removed diff message', function() {
    let wrapper, mfp;

    beforeEach(function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.renderStatus(REMOVED);
        }).build();
      mfp = multiFilePatch;
      wrapper = mount(buildApp({multiFilePatch: mfp}));
    });

    it('displays the message when a file has been removed', function() {
      assert.include(
        wrapper.find('.github-FilePatchView-controlBlock .github-FilePatchView-message').first().text(),
        'This diff is too large to load at all.',
      );
      assert.isFalse(wrapper.find('.github-FilePatchView-showDiffButton').exists());
      assert.isFalse(wrapper.find('.github-HunkHeaderView').exists());
    });
  });
});
