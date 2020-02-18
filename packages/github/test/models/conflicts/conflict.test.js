import EventEmitter from 'events';
import path from 'path';

import Conflict from '../../../lib/models/conflicts/conflict';
import {TOP, MIDDLE, BOTTOM} from '../../../lib/models/conflicts/position';
import {OURS, BASE, THEIRS} from '../../../lib/models/conflicts/source';

describe('Conflict', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  const editorOnFixture = function(name) {
    const fullPath = path.join(path.dirname(__filename), '..', '..', 'fixtures', 'conflict-marker-examples', name);
    return atomEnv.workspace.open(fullPath);
  };

  const assertConflictOnRows = function(conflict, description) {
    const isRangeOnRows = function(range, startRow, endRow, rangeName) {
      assert.isTrue(
        range.start.row === startRow && range.end.row === endRow,
        `expected conflict's ${rangeName} range to cover rows ${startRow} to ${endRow}, but it was ${range}`,
      );
    };

    const isRangeOnRow = function(range, row, rangeName) {
      return isRangeOnRows(range, row, row + 1, rangeName);
    };

    const isPointOnRow = function(range, row, rangeName) {
      return isRangeOnRows(range, row, row, rangeName);
    };

    const ourBannerRange = conflict.getSide(OURS).getBannerMarker().getBufferRange();
    isRangeOnRow(ourBannerRange, description.ourBannerRow, '"ours" banner');

    const ourSideRange = conflict.getSide(OURS).getMarker().getBufferRange();
    isRangeOnRows(ourSideRange, description.ourSideRows[0], description.ourSideRows[1], '"ours"');
    assert.strictEqual(conflict.getSide(OURS).position, description.ourPosition || TOP, '"ours" in expected position');

    const ourBlockRange = conflict.getSide(OURS).getBlockMarker().getBufferRange();
    isPointOnRow(ourBlockRange, description.ourBannerRow, '"ours" block range');

    const theirBannerRange = conflict.getSide(THEIRS).getBannerMarker().getBufferRange();
    isRangeOnRow(theirBannerRange, description.theirBannerRow, '"theirs" banner');

    const theirSideRange = conflict.getSide(THEIRS).getMarker().getBufferRange();
    isRangeOnRows(theirSideRange, description.theirSideRows[0], description.theirSideRows[1], '"theirs"');
    assert.strictEqual(conflict.getSide(THEIRS).position, description.theirPosition || BOTTOM, '"theirs" in expected position');

    const theirBlockRange = conflict.getSide(THEIRS).getBlockMarker().getBufferRange();
    isPointOnRow(theirBlockRange, description.theirBannerRow, '"theirs" block range');

    if (description.baseBannerRow || description.baseSideRows) {
      assert.isNotNull(conflict.getSide(BASE), "expected conflict's base side to be non-null");

      const baseBannerRange = conflict.getSide(BASE).getBannerMarker().getBufferRange();
      isRangeOnRow(baseBannerRange, description.baseBannerRow, '"base" banner');

      const baseSideRange = conflict.getSide(BASE).getMarker().getBufferRange();
      isRangeOnRows(baseSideRange, description.baseSideRows[0], description.baseSideRows[1], '"base"');
      assert.strictEqual(conflict.getSide(BASE).position, MIDDLE, '"base" in MIDDLE position');
    } else {
      assert.isUndefined(conflict.getSide(BASE), "expected conflict's base side to be undefined");
    }

    const separatorRange = conflict.separator.marker.getBufferRange();
    isRangeOnRow(separatorRange, description.separatorRow, 'separator');
  };

  it('parses 2-way diff markings', async function() {
    const editor = await editorOnFixture('single-2way-diff.txt');
    const conflicts = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false);

    assert.equal(conflicts.length, 1);
    assertConflictOnRows(conflicts[0], {
      ourBannerRow: 2,
      ourSideRows: [3, 4],
      separatorRow: 4,
      theirSideRows: [5, 6],
      theirBannerRow: 6,
    });
  });

  it('parses multiple 2-way diff markings', async function() {
    const editor = await editorOnFixture('multi-2way-diff.txt');
    const conflicts = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false);

    assert.equal(conflicts.length, 2);
    assertConflictOnRows(conflicts[0], {
      ourBannerRow: 4,
      ourSideRows: [5, 7],
      separatorRow: 7,
      theirSideRows: [8, 9],
      theirBannerRow: 9,
    });
    assertConflictOnRows(conflicts[1], {
      ourBannerRow: 13,
      ourSideRows: [14, 15],
      separatorRow: 15,
      theirSideRows: [16, 17],
      theirBannerRow: 17,
    });
  });

  it('parses 3-way diff markings', async function() {
    const editor = await editorOnFixture('single-3way-diff.txt');
    const conflicts = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false);
    assert.equal(conflicts.length, 1);
    assertConflictOnRows(conflicts[0], {
      ourBannerRow: 0,
      ourSideRows: [1, 2],
      baseBannerRow: 2,
      baseSideRows: [3, 4],
      separatorRow: 4,
      theirSideRows: [5, 6],
      theirBannerRow: 6,
    });
  });

  it('parses recursive 3-way diff markings', async function() {
    const editor = await editorOnFixture('single-3way-diff-complex.txt');
    const conflicts = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false);
    assert.equal(conflicts.length, 1);

    assertConflictOnRows(conflicts[0], {
      ourBannerRow: 0,
      ourSideRows: [1, 2],
      baseBannerRow: 2,
      baseSideRows: [3, 18],
      separatorRow: 18,
      theirSideRows: [19, 20],
      theirBannerRow: 20,
    });
  });

  it('flips "ours" and "theirs" sides when rebasing', async function() {
    const editor = await editorOnFixture('rebase-2way-diff.txt');
    const conflicts = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), true);

    assert.equal(conflicts.length, 1);
    assertConflictOnRows(conflicts[0], {
      theirBannerRow: 2,
      theirSideRows: [3, 4],
      theirPosition: TOP,
      separatorRow: 4,
      ourSideRows: [5, 6],
      ourBannerRow: 6,
      ourPosition: BOTTOM,
    });
  });

  it('is resilient to malformed 2-way diff markings', async function() {
    const editor = await editorOnFixture('corrupted-2way-diff.txt');
    const conflicts = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), true);

    assert.equal(conflicts.length, 0);
  });

  it('is resilient to malformed 3-way diff markings', async function() {
    const editor = await editorOnFixture('corrupted-3way-diff.txt');
    const conflicts = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), true);

    assert.equal(conflicts.length, 0);
  });

  describe('counting conflicts', function() {
    let readStream, countPromise;

    beforeEach(function() {
      readStream = new EventEmitter();
      countPromise = Conflict.countFromStream(readStream);
    });

    it('counts conflicts from a streamed file', async function() {
      readStream.emit('data', `
before
before
<<<<<<< HEAD
aaa
=======
bbb
>>>>>>> master
middle
middle
      `);

      readStream.emit('data', `
middle
middle
<<<<<<< HEAD
aaa
=======
bbb
>>>>>>> master
end
end
      `);

      readStream.emit('end');

      assert.equal(await countPromise, 2);
    });

    it('counts conflicts that span stream chunks', async function() {
      readStream.emit('data', `
before
before
<<<<<<< HEAD
aaa
=======
`);

      readStream.emit('data', `bbb
>>>>>>> master
end
end
      `);

      readStream.emit('end');

      assert.equal(await countPromise, 1);
    });

    it('handles conflict markers broken across chunks', async function() {
      readStream.emit('data', `
before
<<<`);

      readStream.emit('data', `<<<< HEAD
aaa
=======
bbb
>>>>>>> master
end
end
      `);

      readStream.emit('end');

      assert.equal(await countPromise, 1);
    });
  });

  describe('change detection', function() {
    let editor, conflict;

    beforeEach(async function() {
      editor = await editorOnFixture('single-2way-diff.txt');
      conflict = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false)[0];
    });

    it('detects when a side has been modified', function() {
      assert.isFalse(conflict.getSide(OURS).isBannerModified());
      assert.isFalse(conflict.getSide(OURS).isModified());

      editor.setCursorBufferPosition([3, 1]);
      editor.insertText('nah');

      assert.isFalse(conflict.getSide(OURS).isBannerModified());
      assert.isTrue(conflict.getSide(OURS).isModified());
    });

    it('detects when a banner has been modified', function() {
      assert.isFalse(conflict.getSide(OURS).isBannerModified());
      assert.isFalse(conflict.getSide(OURS).isModified());

      editor.setCursorBufferPosition([2, 1]);
      editor.insertText('your problem now');

      assert.isTrue(conflict.getSide(OURS).isBannerModified());
      assert.isFalse(conflict.getSide(OURS).isModified());
    });

    it('detects when a separator has been modified', function() {
      assert.isFalse(conflict.getSeparator().isModified());

      editor.setCursorBufferPosition([4, 3]);
      editor.insertText('wat');

      assert.isTrue(conflict.getSeparator().isModified());
    });
  });

  describe('contextual block position and CSS class generation', function() {
    let editor, conflict;

    describe('from a merge', function() {
      beforeEach(async function() {
        editor = await editorOnFixture('single-3way-diff.txt');
        conflict = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false)[0];
      });

      it('accesses the block decoration position', function() {
        assert.strictEqual(conflict.getSide(OURS).getBlockPosition(), 'before');
        assert.strictEqual(conflict.getSide(BASE).getBlockPosition(), 'before');
        assert.strictEqual(conflict.getSide(THEIRS).getBlockPosition(), 'after');
      });

      it('accesses the line decoration CSS class', function() {
        assert.strictEqual(conflict.getSide(OURS).getLineCSSClass(), 'github-ConflictOurs');
        assert.strictEqual(conflict.getSide(BASE).getLineCSSClass(), 'github-ConflictBase');
        assert.strictEqual(conflict.getSide(THEIRS).getLineCSSClass(), 'github-ConflictTheirs');
      });

      it('accesses the line decoration CSS class when modified', function() {
        for (const position of [[5, 1], [3, 1], [1, 1]]) {
          editor.setCursorBufferPosition(position);
          editor.insertText('change');
        }

        assert.strictEqual(conflict.getSide(OURS).getLineCSSClass(), 'github-ConflictModified');
        assert.strictEqual(conflict.getSide(BASE).getLineCSSClass(), 'github-ConflictModified');
        assert.strictEqual(conflict.getSide(THEIRS).getLineCSSClass(), 'github-ConflictModified');
      });

      it('accesses the line decoration CSS class when the banner is modified', function() {
        for (const position of [[6, 1], [2, 1], [0, 1]]) {
          editor.setCursorBufferPosition(position);
          editor.insertText('change');
        }

        assert.strictEqual(conflict.getSide(OURS).getLineCSSClass(), 'github-ConflictModified');
        assert.strictEqual(conflict.getSide(BASE).getLineCSSClass(), 'github-ConflictModified');
        assert.strictEqual(conflict.getSide(THEIRS).getLineCSSClass(), 'github-ConflictModified');
      });

      it('accesses the banner CSS class', function() {
        assert.strictEqual(conflict.getSide(OURS).getBannerCSSClass(), 'github-ConflictOursBanner');
        assert.strictEqual(conflict.getSide(BASE).getBannerCSSClass(), 'github-ConflictBaseBanner');
        assert.strictEqual(conflict.getSide(THEIRS).getBannerCSSClass(), 'github-ConflictTheirsBanner');
      });

      it('accesses the banner CSS class when modified', function() {
        for (const position of [[5, 1], [3, 1], [1, 1]]) {
          editor.setCursorBufferPosition(position);
          editor.insertText('change');
        }

        assert.strictEqual(conflict.getSide(OURS).getBannerCSSClass(), 'github-ConflictModifiedBanner');
        assert.strictEqual(conflict.getSide(BASE).getBannerCSSClass(), 'github-ConflictModifiedBanner');
        assert.strictEqual(conflict.getSide(THEIRS).getBannerCSSClass(), 'github-ConflictModifiedBanner');
      });

      it('accesses the banner CSS class when the banner is modified', function() {
        for (const position of [[6, 1], [2, 1], [0, 1]]) {
          editor.setCursorBufferPosition(position);
          editor.insertText('change');
        }

        assert.strictEqual(conflict.getSide(OURS).getBannerCSSClass(), 'github-ConflictModifiedBanner');
        assert.strictEqual(conflict.getSide(BASE).getBannerCSSClass(), 'github-ConflictModifiedBanner');
        assert.strictEqual(conflict.getSide(THEIRS).getBannerCSSClass(), 'github-ConflictModifiedBanner');
      });

      it('accesses the block CSS classes', function() {
        assert.strictEqual(
          conflict.getSide(OURS).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictOursBlock github-ConflictTopBlock',
        );
        assert.strictEqual(
          conflict.getSide(BASE).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictBaseBlock github-ConflictMiddleBlock',
        );
        assert.strictEqual(
          conflict.getSide(THEIRS).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictTheirsBlock github-ConflictBottomBlock',
        );
      });

      it('accesses the block CSS classes when modified', function() {
        for (const position of [[5, 1], [3, 1], [1, 1]]) {
          editor.setCursorBufferPosition(position);
          editor.insertText('change');
        }

        assert.strictEqual(
          conflict.getSide(OURS).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictOursBlock github-ConflictTopBlock github-ConflictModifiedBlock',
        );
        assert.strictEqual(
          conflict.getSide(BASE).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictBaseBlock github-ConflictMiddleBlock github-ConflictModifiedBlock',
        );
        assert.strictEqual(
          conflict.getSide(THEIRS).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictTheirsBlock github-ConflictBottomBlock github-ConflictModifiedBlock',
        );
      });

      it('accesses the block CSS classes when the banner is modified', function() {
        for (const position of [[6, 1], [2, 1], [0, 1]]) {
          editor.setCursorBufferPosition(position);
          editor.insertText('change');
        }

        assert.strictEqual(
          conflict.getSide(OURS).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictOursBlock github-ConflictTopBlock github-ConflictModifiedBlock',
        );
        assert.strictEqual(
          conflict.getSide(BASE).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictBaseBlock github-ConflictMiddleBlock github-ConflictModifiedBlock',
        );
        assert.strictEqual(
          conflict.getSide(THEIRS).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictTheirsBlock github-ConflictBottomBlock github-ConflictModifiedBlock',
        );
      });
    });

    describe('from a rebase', function() {
      beforeEach(async function() {
        editor = await editorOnFixture('single-3way-diff.txt');
        conflict = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), true)[0];
      });

      it('accesses the block decoration position', function() {
        assert.strictEqual(conflict.getSide(THEIRS).getBlockPosition(), 'before');
        assert.strictEqual(conflict.getSide(BASE).getBlockPosition(), 'before');
        assert.strictEqual(conflict.getSide(OURS).getBlockPosition(), 'after');
      });

      it('accesses the line decoration CSS class', function() {
        assert.strictEqual(conflict.getSide(THEIRS).getLineCSSClass(), 'github-ConflictTheirs');
        assert.strictEqual(conflict.getSide(BASE).getLineCSSClass(), 'github-ConflictBase');
        assert.strictEqual(conflict.getSide(OURS).getLineCSSClass(), 'github-ConflictOurs');
      });

      it('accesses the line decoration CSS class when modified', function() {
        for (const position of [[5, 1], [3, 1], [1, 1]]) {
          editor.setCursorBufferPosition(position);
          editor.insertText('change');
        }

        assert.strictEqual(conflict.getSide(THEIRS).getLineCSSClass(), 'github-ConflictModified');
        assert.strictEqual(conflict.getSide(BASE).getLineCSSClass(), 'github-ConflictModified');
        assert.strictEqual(conflict.getSide(OURS).getLineCSSClass(), 'github-ConflictModified');
      });

      it('accesses the line decoration CSS class when the banner is modified', function() {
        for (const position of [[6, 1], [2, 1], [0, 1]]) {
          editor.setCursorBufferPosition(position);
          editor.insertText('change');
        }

        assert.strictEqual(conflict.getSide(THEIRS).getLineCSSClass(), 'github-ConflictModified');
        assert.strictEqual(conflict.getSide(BASE).getLineCSSClass(), 'github-ConflictModified');
        assert.strictEqual(conflict.getSide(OURS).getLineCSSClass(), 'github-ConflictModified');
      });

      it('accesses the banner CSS class', function() {
        assert.strictEqual(conflict.getSide(THEIRS).getBannerCSSClass(), 'github-ConflictTheirsBanner');
        assert.strictEqual(conflict.getSide(BASE).getBannerCSSClass(), 'github-ConflictBaseBanner');
        assert.strictEqual(conflict.getSide(OURS).getBannerCSSClass(), 'github-ConflictOursBanner');
      });

      it('accesses the banner CSS class when modified', function() {
        for (const position of [[5, 1], [3, 1], [1, 1]]) {
          editor.setCursorBufferPosition(position);
          editor.insertText('change');
        }

        assert.strictEqual(conflict.getSide(THEIRS).getBannerCSSClass(), 'github-ConflictModifiedBanner');
        assert.strictEqual(conflict.getSide(BASE).getBannerCSSClass(), 'github-ConflictModifiedBanner');
        assert.strictEqual(conflict.getSide(OURS).getBannerCSSClass(), 'github-ConflictModifiedBanner');
      });

      it('accesses the banner CSS class when the banner is modified', function() {
        for (const position of [[6, 1], [2, 1], [0, 1]]) {
          editor.setCursorBufferPosition(position);
          editor.insertText('change');
        }

        assert.strictEqual(conflict.getSide(THEIRS).getBannerCSSClass(), 'github-ConflictModifiedBanner');
        assert.strictEqual(conflict.getSide(BASE).getBannerCSSClass(), 'github-ConflictModifiedBanner');
        assert.strictEqual(conflict.getSide(OURS).getBannerCSSClass(), 'github-ConflictModifiedBanner');
      });

      it('accesses the block CSS classes', function() {
        assert.strictEqual(
          conflict.getSide(THEIRS).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictTheirsBlock github-ConflictTopBlock',
        );
        assert.strictEqual(
          conflict.getSide(BASE).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictBaseBlock github-ConflictMiddleBlock',
        );
        assert.strictEqual(
          conflict.getSide(OURS).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictOursBlock github-ConflictBottomBlock',
        );
      });

      it('accesses the block CSS classes when modified', function() {
        for (const position of [[5, 1], [3, 1], [1, 1]]) {
          editor.setCursorBufferPosition(position);
          editor.insertText('change');
        }

        assert.strictEqual(
          conflict.getSide(THEIRS).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictTheirsBlock github-ConflictTopBlock github-ConflictModifiedBlock',
        );
        assert.strictEqual(
          conflict.getSide(BASE).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictBaseBlock github-ConflictMiddleBlock github-ConflictModifiedBlock',
        );
        assert.strictEqual(
          conflict.getSide(OURS).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictOursBlock github-ConflictBottomBlock github-ConflictModifiedBlock',
        );
      });

      it('accesses the block CSS classes when the banner is modified', function() {
        for (const position of [[6, 1], [2, 1], [0, 1]]) {
          editor.setCursorBufferPosition(position);
          editor.insertText('change');
        }

        assert.strictEqual(
          conflict.getSide(THEIRS).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictTheirsBlock github-ConflictTopBlock github-ConflictModifiedBlock',
        );
        assert.strictEqual(
          conflict.getSide(BASE).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictBaseBlock github-ConflictMiddleBlock github-ConflictModifiedBlock',
        );
        assert.strictEqual(
          conflict.getSide(OURS).getBlockCSSClasses(),
          'github-ConflictBlock github-ConflictOursBlock github-ConflictBottomBlock github-ConflictModifiedBlock',
        );
      });
    });
  });

  it('accesses a side range that encompasses the banner and content', async function() {
    const editor = await editorOnFixture('single-3way-diff.txt');
    const conflict = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false)[0];

    assert.deepEqual(conflict.getSide(OURS).getRange().serialize(), [[0, 0], [2, 0]]);
    assert.deepEqual(conflict.getSide(BASE).getRange().serialize(), [[2, 0], [4, 0]]);
    assert.deepEqual(conflict.getSide(THEIRS).getRange().serialize(), [[5, 0], [7, 0]]);
  });

  it('determines the inclusion of points', async function() {
    const editor = await editorOnFixture('single-3way-diff.txt');
    const conflict = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false)[0];

    assert.isTrue(conflict.getSide(OURS).includesPoint([0, 1]));
    assert.isTrue(conflict.getSide(OURS).includesPoint([1, 3]));
    assert.isFalse(conflict.getSide(OURS).includesPoint([2, 1]));
  });

  it('detects when a side is empty', async function() {
    const editor = await editorOnFixture('single-2way-diff-empty.txt');
    const conflict = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false)[0];

    assert.isFalse(conflict.getSide(OURS).isEmpty());
    assert.isTrue(conflict.getSide(THEIRS).isEmpty());
  });

  it('reverts a modified Side', async function() {
    const editor = await editorOnFixture('single-3way-diff.txt');
    const conflict = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false)[0];

    editor.setCursorBufferPosition([5, 10]);
    editor.insertText('MY-CHANGE');

    assert.isTrue(conflict.getSide(THEIRS).isModified());
    assert.match(editor.getText(), /MY-CHANGE/);

    conflict.getSide(THEIRS).revert();

    assert.isFalse(conflict.getSide(THEIRS).isModified());
    assert.notMatch(editor.getText(), /MY-CHANGE/);
  });

  it('reverts a modified Side banner', async function() {
    const editor = await editorOnFixture('single-3way-diff.txt');
    const conflict = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false)[0];

    editor.setCursorBufferPosition([6, 4]);
    editor.insertText('MY-CHANGE');

    assert.isTrue(conflict.getSide(THEIRS).isBannerModified());
    assert.match(editor.getText(), /MY-CHANGE/);

    conflict.getSide(THEIRS).revertBanner();

    assert.isFalse(conflict.getSide(THEIRS).isBannerModified());
    assert.notMatch(editor.getText(), /MY-CHANGE/);
  });

  it('deletes a banner', async function() {
    const editor = await editorOnFixture('single-3way-diff.txt');
    const conflict = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false)[0];

    assert.match(editor.getText(), /<<<<<<< HEAD/);
    conflict.getSide(OURS).deleteBanner();
    assert.notMatch(editor.getText(), /<<<<<<< HEAD/);
  });

  it('deletes a side', async function() {
    const editor = await editorOnFixture('single-3way-diff.txt');
    const conflict = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false)[0];

    assert.match(editor.getText(), /your/);
    conflict.getSide(THEIRS).delete();
    assert.notMatch(editor.getText(), /your/);
  });

  it('appends text to a side', async function() {
    const editor = await editorOnFixture('single-3way-diff.txt');
    const conflict = Conflict.allFromEditor(editor, editor.getDefaultMarkerLayer(), false)[0];

    assert.notMatch(editor.getText(), /APPENDED/);
    conflict.getSide(THEIRS).appendText('APPENDED\n');
    assert.match(editor.getText(), /APPENDED/);

    assert.isTrue(conflict.getSide(THEIRS).isModified());
    assert.strictEqual(conflict.getSide(THEIRS).getText(), 'These are your changes\nAPPENDED\n');
    assert.isFalse(conflict.getSide(THEIRS).isBannerModified());
  });
});
