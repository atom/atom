import {TextBuffer} from 'atom';

import Patch from '../../../lib/models/patch/patch';
import PatchBuffer from '../../../lib/models/patch/patch-buffer';
import Hunk from '../../../lib/models/patch/hunk';
import {Unchanged, Addition, Deletion, NoNewline} from '../../../lib/models/patch/region';
import {assertInPatch} from '../../helpers';

describe('Patch', function() {
  it('has some standard accessors', function() {
    const buffer = new TextBuffer({text: 'bufferText'});
    const layers = buildLayers(buffer);
    const marker = markRange(layers.patch, 0, Infinity);
    const p = new Patch({status: 'modified', hunks: [], marker});
    assert.strictEqual(p.getStatus(), 'modified');
    assert.deepEqual(p.getHunks(), []);
    assert.isTrue(p.isPresent());
  });

  it('computes the total changed line count', function() {
    const buffer = buildBuffer(15);
    const layers = buildLayers(buffer);
    const hunks = [
      new Hunk({
        oldStartRow: 0, newStartRow: 0, oldRowCount: 1, newRowCount: 1,
        sectionHeading: 'zero',
        marker: markRange(layers.hunk, 0, 5),
        regions: [
          new Unchanged(markRange(layers.unchanged, 0)),
          new Addition(markRange(layers.addition, 1)),
          new Unchanged(markRange(layers.unchanged, 2)),
          new Deletion(markRange(layers.deletion, 3, 4)),
          new Unchanged(markRange(layers.unchanged, 5)),
        ],
      }),
      new Hunk({
        oldStartRow: 0, newStartRow: 0, oldRowCount: 1, newRowCount: 1,
        sectionHeading: 'one',
        marker: markRange(layers.hunk, 6, 15),
        regions: [
          new Unchanged(markRange(layers.unchanged, 6)),
          new Deletion(markRange(layers.deletion, 7)),
          new Unchanged(markRange(layers.unchanged, 8)),
          new Deletion(markRange(layers.deletion, 9, 11)),
          new Addition(markRange(layers.addition, 12, 14)),
          new Unchanged(markRange(layers.unchanged, 15)),
        ],
      }),
    ];
    const marker = markRange(layers.patch, 0, Infinity);

    const p = new Patch({status: 'modified', hunks, marker});

    assert.strictEqual(p.getChangedLineCount(), 10);
  });

  it('computes the maximum number of digits needed to display a diff line number', function() {
    const buffer = buildBuffer(15);
    const layers = buildLayers(buffer);
    const hunks = [
      new Hunk({
        oldStartRow: 0, oldRowCount: 1, newStartRow: 0, newRowCount: 1,
        sectionHeading: 'zero',
        marker: markRange(layers.hunk, 0, 5),
        regions: [],
      }),
      new Hunk({
        oldStartRow: 98,
        oldRowCount: 5,
        newStartRow: 95,
        newRowCount: 3,
        sectionHeading: 'one',
        marker: markRange(layers.hunk, 6, 15),
        regions: [],
      }),
    ];
    const p0 = new Patch({status: 'modified', hunks, buffer, layers});
    assert.strictEqual(p0.getMaxLineNumberWidth(), 3);

    const p1 = new Patch({status: 'deleted', hunks: [], buffer, layers});
    assert.strictEqual(p1.getMaxLineNumberWidth(), 0);
  });

  it('clones itself with optionally overridden properties', function() {
    const buffer = new TextBuffer({text: 'bufferText'});
    const layers = buildLayers(buffer);
    const marker = markRange(layers.patch, 0, Infinity);

    const original = new Patch({status: 'modified', hunks: [], marker});

    const dup0 = original.clone();
    assert.notStrictEqual(dup0, original);
    assert.strictEqual(dup0.getStatus(), 'modified');
    assert.deepEqual(dup0.getHunks(), []);
    assert.strictEqual(dup0.getMarker(), marker);

    const dup1 = original.clone({status: 'added'});
    assert.notStrictEqual(dup1, original);
    assert.strictEqual(dup1.getStatus(), 'added');
    assert.deepEqual(dup1.getHunks(), []);
    assert.strictEqual(dup0.getMarker(), marker);

    const hunks = [new Hunk({regions: []})];
    const dup2 = original.clone({hunks});
    assert.notStrictEqual(dup2, original);
    assert.strictEqual(dup2.getStatus(), 'modified');
    assert.deepEqual(dup2.getHunks(), hunks);
    assert.strictEqual(dup0.getMarker(), marker);

    const nBuffer = new TextBuffer({text: 'changed'});
    const nLayers = buildLayers(nBuffer);
    const nMarker = markRange(nLayers.patch, 0, Infinity);
    const dup3 = original.clone({marker: nMarker});
    assert.notStrictEqual(dup3, original);
    assert.strictEqual(dup3.getStatus(), 'modified');
    assert.deepEqual(dup3.getHunks(), []);
    assert.strictEqual(dup3.getMarker(), nMarker);
  });

  it('clones a nullPatch as a nullPatch', function() {
    const nullPatch = Patch.createNull();
    assert.strictEqual(nullPatch, nullPatch.clone());
  });

  it('clones a nullPatch to a real Patch if properties are provided', function() {
    const nullPatch = Patch.createNull();

    const dup0 = nullPatch.clone({status: 'added'});
    assert.notStrictEqual(dup0, nullPatch);
    assert.strictEqual(dup0.getStatus(), 'added');
    assert.deepEqual(dup0.getHunks(), []);
    assert.deepEqual(dup0.getMarker().getRange().serialize(), [[0, 0], [0, 0]]);

    const hunks = [new Hunk({regions: []})];
    const dup1 = nullPatch.clone({hunks});
    assert.notStrictEqual(dup1, nullPatch);
    assert.isNull(dup1.getStatus());
    assert.deepEqual(dup1.getHunks(), hunks);
    assert.deepEqual(dup0.getMarker().getRange().serialize(), [[0, 0], [0, 0]]);

    const nBuffer = new TextBuffer({text: 'changed'});
    const nLayers = buildLayers(nBuffer);
    const nMarker = markRange(nLayers.patch, 0, Infinity);
    const dup2 = nullPatch.clone({marker: nMarker});
    assert.notStrictEqual(dup2, nullPatch);
    assert.isNull(dup2.getStatus());
    assert.deepEqual(dup2.getHunks(), []);
    assert.strictEqual(dup2.getMarker(), nMarker);
  });

  it('returns an empty Range at the beginning of its Marker', function() {
    const {patch} = buildPatchFixture();
    assert.deepEqual(patch.getStartRange().serialize(), [[0, 0], [0, 0]]);
  });

  it('determines whether or not a buffer row belongs to this patch', function() {
    const {patch} = buildPatchFixture();

    assert.isTrue(patch.containsRow(0));
    assert.isTrue(patch.containsRow(5));
    assert.isTrue(patch.containsRow(26));
    assert.isFalse(patch.containsRow(27));
  });

  describe('stage patch generation', function() {
    let stagePatchBuffer;

    beforeEach(function() {
      stagePatchBuffer = new PatchBuffer();
    });

    it('creates a patch that applies selected lines from only the first hunk', function() {
      const {patch, buffer: originalBuffer} = buildPatchFixture();
      const stagePatch = patch.buildStagePatchForLines(originalBuffer, stagePatchBuffer, new Set([2, 3, 4, 5]));
      // buffer rows:             0     1     2     3     4     5     6
      const expectedBufferText = '0000\n0001\n0002\n0003\n0004\n0005\n0006\n';
      assert.strictEqual(stagePatchBuffer.buffer.getText(), expectedBufferText);
      assertInPatch(stagePatch, stagePatchBuffer.buffer).hunks(
        {
          startRow: 0,
          endRow: 6,
          header: '@@ -3,4 +3,6 @@',
          regions: [
            {kind: 'unchanged', string: ' 0000\n 0001\n', range: [[0, 0], [1, 4]]},
            {kind: 'deletion', string: '-0002\n', range: [[2, 0], [2, 4]]},
            {kind: 'addition', string: '+0003\n+0004\n+0005\n', range: [[3, 0], [5, 4]]},
            {kind: 'unchanged', string: ' 0006\n', range: [[6, 0], [6, 4]]},
          ],
        },
      );
    });

    it('creates a patch that applies selected lines from a single non-first hunk', function() {
      const {patch, buffer: originalBuffer} = buildPatchFixture();
      const stagePatch = patch.buildStagePatchForLines(originalBuffer, stagePatchBuffer, new Set([8, 13, 14, 16]));
      // buffer rows:             0     1     2     3     4     5     6     7     8     9
      const expectedBufferText = '0007\n0008\n0010\n0011\n0012\n0013\n0014\n0015\n0016\n0018\n';
      assert.strictEqual(stagePatchBuffer.buffer.getText(), expectedBufferText);
      assertInPatch(stagePatch, stagePatchBuffer.buffer).hunks(
        {
          startRow: 0,
          endRow: 9,
          header: '@@ -12,9 +12,7 @@',
          regions: [
            {kind: 'unchanged', string: ' 0007\n', range: [[0, 0], [0, 4]]},
            {kind: 'addition', string: '+0008\n', range: [[1, 0], [1, 4]]},
            {kind: 'unchanged', string: ' 0010\n 0011\n 0012\n', range: [[2, 0], [4, 4]]},
            {kind: 'deletion', string: '-0013\n-0014\n', range: [[5, 0], [6, 4]]},
            {kind: 'unchanged', string: ' 0015\n', range: [[7, 0], [7, 4]]},
            {kind: 'deletion', string: '-0016\n', range: [[8, 0], [8, 4]]},
            {kind: 'unchanged', string: ' 0018\n', range: [[9, 0], [9, 4]]},
          ],
        },
      );
    });

    it('creates a patch that applies selected lines from several hunks', function() {
      const {patch, buffer: originalBuffer} = buildPatchFixture();
      const stagePatch = patch.buildStagePatchForLines(originalBuffer, stagePatchBuffer, new Set([1, 5, 15, 16, 17, 25]));
      const expectedBufferText =
          // buffer rows
          // 0   1     2     3     4
          '0000\n0001\n0002\n0005\n0006\n' +
          // 5   6     7     8     9     10    11    12    13    14
          '0007\n0010\n0011\n0012\n0013\n0014\n0015\n0016\n0017\n0018\n' +
          // 15  16    17
          '0024\n0025\n No newline at end of file\n';
      assert.strictEqual(stagePatchBuffer.buffer.getText(), expectedBufferText);
      assertInPatch(stagePatch, stagePatchBuffer.buffer).hunks(
        {
          startRow: 0,
          endRow: 4,
          header: '@@ -3,4 +3,4 @@',
          regions: [
            {kind: 'unchanged', string: ' 0000\n', range: [[0, 0], [0, 4]]},
            {kind: 'deletion', string: '-0001\n', range: [[1, 0], [1, 4]]},
            {kind: 'unchanged', string: ' 0002\n', range: [[2, 0], [2, 4]]},
            {kind: 'addition', string: '+0005\n', range: [[3, 0], [3, 4]]},
            {kind: 'unchanged', string: ' 0006\n', range: [[4, 0], [4, 4]]},
          ],
        },
        {
          startRow: 5,
          endRow: 14,
          header: '@@ -12,9 +12,8 @@',
          regions: [
            {kind: 'unchanged', string: ' 0007\n 0010\n 0011\n 0012\n 0013\n 0014\n', range: [[5, 0], [10, 4]]},
            {kind: 'deletion', string: '-0015\n-0016\n', range: [[11, 0], [12, 4]]},
            {kind: 'addition', string: '+0017\n', range: [[13, 0], [13, 4]]},
            {kind: 'unchanged', string: ' 0018\n', range: [[14, 0], [14, 4]]},
          ],
        },
        {
          startRow: 15,
          endRow: 17,
          header: '@@ -32,1 +31,2 @@',
          regions: [
            {kind: 'unchanged', string: ' 0024\n', range: [[15, 0], [15, 4]]},
            {kind: 'addition', string: '+0025\n', range: [[16, 0], [16, 4]]},
            {kind: 'nonewline', string: '\\ No newline at end of file\n', range: [[17, 0], [17, 26]]},
          ],
        },
      );
    });

    it('marks ranges for each change region on the correct marker layer', function() {
      const {patch, buffer: originalBuffer} = buildPatchFixture();
      patch.buildStagePatchForLines(originalBuffer, stagePatchBuffer, new Set([1, 5, 15, 16, 17, 25]));

      const layerRanges = [
        Hunk.layerName, Unchanged.layerName, Addition.layerName, Deletion.layerName, NoNewline.layerName,
      ].reduce((obj, layerName) => {
        obj[layerName] = stagePatchBuffer.findMarkers(layerName, {}).map(marker => marker.getRange().serialize());
        return obj;
      }, {});

      assert.deepEqual(layerRanges, {
        hunk: [
          [[0, 0], [4, 4]],
          [[5, 0], [14, 4]],
          [[15, 0], [17, 26]],
        ],
        unchanged: [
          [[0, 0], [0, 4]],
          [[2, 0], [2, 4]],
          [[4, 0], [4, 4]],
          [[5, 0], [10, 4]],
          [[14, 0], [14, 4]],
          [[15, 0], [15, 4]],
        ],
        addition: [
          [[3, 0], [3, 4]],
          [[13, 0], [13, 4]],
          [[16, 0], [16, 4]],
        ],
        deletion: [
          [[1, 0], [1, 4]],
          [[11, 0], [12, 4]],
        ],
        nonewline: [
          [[17, 0], [17, 26]],
        ],
      });
    });

    it('returns a modification patch if original patch is a deletion', function() {
      const buffer = new TextBuffer({text: 'line-0\nline-1\nline-2\nline-3\nline-4\nline-5\n'});
      const layers = buildLayers(buffer);
      const hunks = [
        new Hunk({
          oldStartRow: 1, oldRowCount: 5, newStartRow: 1, newRowCount: 0,
          sectionHeading: 'zero',
          marker: markRange(layers.hunk, 0, 5),
          regions: [
            new Deletion(markRange(layers.deletion, 0, 5)),
          ],
        }),
      ];
      const marker = markRange(layers.patch, 0, 5);

      const patch = new Patch({status: 'deleted', hunks, marker});

      const stagedPatch = patch.buildStagePatchForLines(buffer, stagePatchBuffer, new Set([1, 3, 4]));
      assert.strictEqual(stagedPatch.getStatus(), 'modified');
      assertInPatch(stagedPatch, stagePatchBuffer.buffer).hunks(
        {
          startRow: 0,
          endRow: 5,
          header: '@@ -1,5 +1,3 @@',
          regions: [
            {kind: 'unchanged', string: ' line-0\n', range: [[0, 0], [0, 6]]},
            {kind: 'deletion', string: '-line-1\n', range: [[1, 0], [1, 6]]},
            {kind: 'unchanged', string: ' line-2\n', range: [[2, 0], [2, 6]]},
            {kind: 'deletion', string: '-line-3\n-line-4\n', range: [[3, 0], [4, 6]]},
            {kind: 'unchanged', string: ' line-5\n', range: [[5, 0], [5, 6]]},
          ],
        },
      );
    });

    it('returns an deletion when staging an entire deletion patch', function() {
      const buffer = new TextBuffer({text: '0000\n0001\n0002\n'});
      const layers = buildLayers(buffer);
      const hunks = [
        new Hunk({
          oldStartRow: 1, oldRowCount: 3, newStartRow: 1, newRowCount: 0,
          marker: markRange(layers.hunk, 0, 2),
          regions: [
            new Deletion(markRange(layers.deletion, 0, 2)),
          ],
        }),
      ];
      const marker = markRange(layers.patch, 0, 2);
      const patch = new Patch({status: 'deleted', hunks, marker});

      const stagePatch0 = patch.buildStagePatchForLines(buffer, stagePatchBuffer, new Set([0, 1, 2]));
      assert.strictEqual(stagePatch0.getStatus(), 'deleted');
    });

    it('returns a nullPatch as a nullPatch', function() {
      const nullPatch = Patch.createNull();
      assert.strictEqual(nullPatch.buildStagePatchForLines(new Set([1, 2, 3])), nullPatch);
    });
  });

  describe('unstage patch generation', function() {
    let unstagePatchBuffer;

    beforeEach(function() {
      unstagePatchBuffer = new PatchBuffer();
    });

    it('creates a patch that updates the index to unapply selected lines from a single hunk', function() {
      const {patch, buffer: originalBuffer} = buildPatchFixture();
      const unstagePatch = patch.buildUnstagePatchForLines(originalBuffer, unstagePatchBuffer, new Set([8, 12, 13]));
      assert.strictEqual(
        unstagePatchBuffer.buffer.getText(),
        // 0   1     2     3     4     5     6     7     8
        '0007\n0008\n0009\n0010\n0011\n0012\n0013\n0017\n0018\n',
      );
      assertInPatch(unstagePatch, unstagePatchBuffer.buffer).hunks(
        {
          startRow: 0,
          endRow: 8,
          header: '@@ -13,7 +13,8 @@',
          regions: [
            {kind: 'unchanged', string: ' 0007\n', range: [[0, 0], [0, 4]]},
            {kind: 'deletion', string: '-0008\n', range: [[1, 0], [1, 4]]},
            {kind: 'unchanged', string: ' 0009\n 0010\n 0011\n', range: [[2, 0], [4, 4]]},
            {kind: 'addition', string: '+0012\n+0013\n', range: [[5, 0], [6, 4]]},
            {kind: 'unchanged', string: ' 0017\n 0018\n', range: [[7, 0], [8, 4]]},
          ],
        },
      );
    });

    it('creates a patch that updates the index to unapply lines from several hunks', function() {
      const {patch, buffer: originalBuffer} = buildPatchFixture();
      const unstagePatch = patch.buildUnstagePatchForLines(originalBuffer, unstagePatchBuffer, new Set([1, 4, 5, 16, 17, 20, 25]));
      assert.strictEqual(
        unstagePatchBuffer.buffer.getText(),
        // 0   1     2     3     4     5
        '0000\n0001\n0003\n0004\n0005\n0006\n' +
        // 6   7     8     9     10    11    12    13
        '0007\n0008\n0009\n0010\n0011\n0016\n0017\n0018\n' +
        // 14  15    16
        '0019\n0020\n0023\n' +
        // 17  18    19
        '0024\n0025\n No newline at end of file\n',
      );
      assertInPatch(unstagePatch, unstagePatchBuffer.buffer).hunks(
        {
          startRow: 0,
          endRow: 5,
          header: '@@ -3,5 +3,4 @@',
          regions: [
            {kind: 'unchanged', string: ' 0000\n', range: [[0, 0], [0, 4]]},
            {kind: 'addition', string: '+0001\n', range: [[1, 0], [1, 4]]},
            {kind: 'unchanged', string: ' 0003\n', range: [[2, 0], [2, 4]]},
            {kind: 'deletion', string: '-0004\n-0005\n', range: [[3, 0], [4, 4]]},
            {kind: 'unchanged', string: ' 0006\n', range: [[5, 0], [5, 4]]},
          ],
        },
        {
          startRow: 6,
          endRow: 13,
          header: '@@ -13,7 +12,7 @@',
          regions: [
            {kind: 'unchanged', string: ' 0007\n 0008\n 0009\n 0010\n 0011\n', range: [[6, 0], [10, 4]]},
            {kind: 'addition', string: '+0016\n', range: [[11, 0], [11, 4]]},
            {kind: 'deletion', string: '-0017\n', range: [[12, 0], [12, 4]]},
            {kind: 'unchanged', string: ' 0018\n', range: [[13, 0], [13, 4]]},
          ],
        },
        {
          startRow: 14,
          endRow: 16,
          header: '@@ -25,3 +24,2 @@',
          regions: [
            {kind: 'unchanged', string: ' 0019\n', range: [[14, 0], [14, 4]]},
            {kind: 'deletion', string: '-0020\n', range: [[15, 0], [15, 4]]},
            {kind: 'unchanged', string: ' 0023\n', range: [[16, 0], [16, 4]]},
          ],
        },
        {
          startRow: 17,
          endRow: 19,
          header: '@@ -30,2 +28,1 @@',
          regions: [
            {kind: 'unchanged', string: ' 0024\n', range: [[17, 0], [17, 4]]},
            {kind: 'deletion', string: '-0025\n', range: [[18, 0], [18, 4]]},
            {kind: 'nonewline', string: '\\ No newline at end of file\n', range: [[19, 0], [19, 26]]},
          ],
        },
      );
    });

    it('marks ranges for each change region on the correct marker layer', function() {
      const {patch, buffer: originalBuffer} = buildPatchFixture();
      patch.buildUnstagePatchForLines(originalBuffer, unstagePatchBuffer, new Set([1, 4, 5, 16, 17, 20, 25]));
      const layerRanges = [
        Hunk.layerName, Unchanged.layerName, Addition.layerName, Deletion.layerName, NoNewline.layerName,
      ].reduce((obj, layerName) => {
        obj[layerName] = unstagePatchBuffer.findMarkers(layerName, {}).map(marker => marker.getRange().serialize());
        return obj;
      }, {});

      assert.deepEqual(layerRanges, {
        hunk: [
          [[0, 0], [5, 4]],
          [[6, 0], [13, 4]],
          [[14, 0], [16, 4]],
          [[17, 0], [19, 26]],
        ],
        unchanged: [
          [[0, 0], [0, 4]],
          [[2, 0], [2, 4]],
          [[5, 0], [5, 4]],
          [[6, 0], [10, 4]],
          [[13, 0], [13, 4]],
          [[14, 0], [14, 4]],
          [[16, 0], [16, 4]],
          [[17, 0], [17, 4]],
        ],
        addition: [
          [[1, 0], [1, 4]],
          [[11, 0], [11, 4]],
        ],
        deletion: [
          [[3, 0], [4, 4]],
          [[12, 0], [12, 4]],
          [[15, 0], [15, 4]],
          [[18, 0], [18, 4]],
        ],
        nonewline: [
          [[19, 0], [19, 26]],
        ],
      });
    });

    it('returns a modification if original patch is an addition', function() {
      const buffer = new TextBuffer({text: '0000\n0001\n0002\n'});
      const layers = buildLayers(buffer);
      const hunks = [
        new Hunk({
          oldStartRow: 1, oldRowCount: 0, newStartRow: 1, newRowCount: 3,
          marker: markRange(layers.hunk, 0, 2),
          regions: [
            new Addition(markRange(layers.addition, 0, 2)),
          ],
        }),
      ];
      const marker = markRange(layers.patch, 0, 2);
      const patch = new Patch({status: 'added', hunks, marker});
      const unstagePatch = patch.buildUnstagePatchForLines(buffer, unstagePatchBuffer, new Set([1, 2]));
      assert.strictEqual(unstagePatch.getStatus(), 'modified');
      assert.strictEqual(unstagePatchBuffer.buffer.getText(), '0000\n0001\n0002\n');
      assertInPatch(unstagePatch, unstagePatchBuffer.buffer).hunks(
        {
          startRow: 0,
          endRow: 2,
          header: '@@ -1,3 +1,1 @@',
          regions: [
            {kind: 'unchanged', string: ' 0000\n', range: [[0, 0], [0, 4]]},
            {kind: 'deletion', string: '-0001\n-0002\n', range: [[1, 0], [2, 4]]},
          ],
        },
      );
    });

    it('returns a deletion when unstaging an entire addition patch', function() {
      const buffer = new TextBuffer({text: '0000\n0001\n0002\n'});
      const layers = buildLayers(buffer);
      const hunks = [
        new Hunk({
          oldStartRow: 1,
          oldRowCount: 0,
          newStartRow: 1,
          newRowCount: 3,
          marker: markRange(layers.hunk, 0, 2),
          regions: [
            new Addition(markRange(layers.addition, 0, 2)),
          ],
        }),
      ];
      const marker = markRange(layers.patch, 0, 2);
      const patch = new Patch({status: 'added', hunks, marker});

      const unstagePatch = patch.buildUnstagePatchForLines(buffer, unstagePatchBuffer, new Set([0, 1, 2]));
      assert.strictEqual(unstagePatch.getStatus(), 'deleted');
    });

    it('returns an addition when unstaging a deletion', function() {
      const buffer = new TextBuffer({text: '0000\n0001\n0002\n'});
      const layers = buildLayers(buffer);
      const hunks = [
        new Hunk({
          oldStartRow: 1,
          oldRowCount: 0,
          newStartRow: 1,
          newRowCount: 3,
          marker: markRange(layers.hunk, 0, 2),
          regions: [
            new Addition(markRange(layers.addition, 0, 2)),
          ],
        }),
      ];
      const marker = markRange(layers.patch, 0, 2);
      const patch = new Patch({status: 'deleted', hunks, marker});

      const unstagePatch = patch.buildUnstagePatchForLines(buffer, unstagePatchBuffer, new Set([0, 1, 2]));
      assert.strictEqual(unstagePatch.getStatus(), 'added');
    });

    it('returns a nullPatch as a nullPatch', function() {
      const nullPatch = Patch.createNull();
      assert.strictEqual(nullPatch.buildUnstagePatchForLines(new Set([1, 2, 3])), nullPatch);
    });
  });

  describe('getFirstChangeRange', function() {
    it('accesses the range of the first change from the first hunk', function() {
      const {patch} = buildPatchFixture();
      assert.deepEqual(patch.getFirstChangeRange().serialize(), [[1, 0], [1, Infinity]]);
    });

    it('returns the origin if the first hunk is empty', function() {
      const buffer = new TextBuffer({text: ''});
      const layers = buildLayers(buffer);
      const hunks = [
        new Hunk({
          oldStartRow: 1, oldRowCount: 0, newStartRow: 1, newRowCount: 0,
          marker: markRange(layers.hunk, 0),
          regions: [],
        }),
      ];
      const marker = markRange(layers.patch, 0);
      const patch = new Patch({status: 'modified', hunks, marker});
      assert.deepEqual(patch.getFirstChangeRange().serialize(), [[0, 0], [0, 0]]);
    });

    it('returns the origin if the patch is empty', function() {
      const buffer = new TextBuffer({text: ''});
      const layers = buildLayers(buffer);
      const marker = markRange(layers.patch, 0);
      const patch = new Patch({status: 'modified', hunks: [], marker});
      assert.deepEqual(patch.getFirstChangeRange().serialize(), [[0, 0], [0, 0]]);
    });
  });

  it('prints itself as an apply-ready string', function() {
    const buffer = buildBuffer(10);
    const layers = buildLayers(buffer);

    const hunk0 = new Hunk({
      oldStartRow: 0, newStartRow: 0, oldRowCount: 2, newRowCount: 3,
      sectionHeading: 'zero',
      marker: markRange(layers.hunk, 0, 2),
      regions: [
        new Unchanged(markRange(layers.unchanged, 0)),
        new Addition(markRange(layers.addition, 1)),
        new Unchanged(markRange(layers.unchanged, 2)),
      ],
    });

    const hunk1 = new Hunk({
      oldStartRow: 5, newStartRow: 6, oldRowCount: 4, newRowCount: 2,
      sectionHeading: 'one',
      marker: markRange(layers.hunk, 6, 9),
      regions: [
        new Unchanged(markRange(layers.unchanged, 6)),
        new Deletion(markRange(layers.deletion, 7, 8)),
        new Unchanged(markRange(layers.unchanged, 9)),
      ],
    });
    const marker = markRange(layers.patch, 0, 9);

    const p = new Patch({status: 'modified', hunks: [hunk0, hunk1], marker});

    assert.strictEqual(p.toStringIn(buffer), [
      '@@ -0,2 +0,3 @@\n',
      ' 0000\n',
      '+0001\n',
      ' 0002\n',
      '@@ -5,4 +6,2 @@\n',
      ' 0006\n',
      '-0007\n',
      '-0008\n',
      ' 0009\n',
    ].join(''));
  });

  it('correctly handles blank lines in added, removed, and unchanged regions', function() {
    const buffer = new TextBuffer({text: '\n\n\n\n\n\n'});
    const layers = buildLayers(buffer);

    const hunk = new Hunk({
      oldStartRow: 1, oldRowCount: 5, newStartRow: 1, newRowCount: 5,
      sectionHeading: 'only',
      marker: markRange(layers.hunk, 0, 5),
      regions: [
        new Unchanged(markRange(layers.unchanged, 0, 1)),
        new Addition(markRange(layers.addition, 1, 2)),
        new Deletion(markRange(layers.deletion, 3, 4)),
        new Unchanged(markRange(layers.unchanged, 5)),
      ],
    });
    const marker = markRange(layers.patch, 0, 5);

    const p = new Patch({status: 'modified', hunks: [hunk], marker});
    assert.strictEqual(p.toStringIn(buffer), [
      '@@ -1,5 +1,5 @@\n',
      ' \n',
      ' \n',
      '+\n',
      '+\n',
      '-\n',
      '-\n',
      ' \n',
    ].join(''));
  });

  it('has a stubbed nullPatch counterpart', function() {
    const nullPatch = Patch.createNull();
    assert.isNull(nullPatch.getStatus());
    assert.deepEqual(nullPatch.getMarker().getRange().serialize(), [[0, 0], [0, 0]]);
    assert.deepEqual(nullPatch.getRange().serialize(), [[0, 0], [0, 0]]);
    assert.deepEqual(nullPatch.getStartRange().serialize(), [[0, 0], [0, 0]]);
    assert.deepEqual(nullPatch.getHunks(), []);
    assert.strictEqual(nullPatch.getChangedLineCount(), 0);
    assert.isFalse(nullPatch.containsRow(0));
    assert.strictEqual(nullPatch.getMaxLineNumberWidth(), 0);
    assert.deepEqual(nullPatch.getFirstChangeRange().serialize(), [[0, 0], [0, 0]]);
    assert.strictEqual(nullPatch.toStringIn(), '');
    assert.isFalse(nullPatch.isPresent());
    assert.lengthOf(nullPatch.getStartingMarkers(), 0);
    assert.lengthOf(nullPatch.getEndingMarkers(), 0);
  });
});

function buildBuffer(lines, noNewline = false) {
  const buffer = new TextBuffer();
  for (let i = 0; i < lines; i++) {
    const iStr = i.toString(10);
    let padding = '';
    for (let p = iStr.length; p < 4; p++) {
      padding += '0';
    }
    buffer.append(padding);
    buffer.append(iStr);
    buffer.append('\n');
  }
  if (noNewline) {
    buffer.append(' No newline at end of file\n');
  }
  return buffer;
}

function buildLayers(buffer) {
  return {
    patch: buffer.addMarkerLayer(),
    hunk: buffer.addMarkerLayer(),
    unchanged: buffer.addMarkerLayer(),
    addition: buffer.addMarkerLayer(),
    deletion: buffer.addMarkerLayer(),
    noNewline: buffer.addMarkerLayer(),
  };
}

function markRange(buffer, start, end = start) {
  return buffer.markRange([[start, 0], [end, Infinity]]);
}

function buildPatchFixture() {
  const buffer = buildBuffer(26, true);
  buffer.append('\n\n\n\n\n\n');

  const layers = buildLayers(buffer);

  const hunks = [
    new Hunk({
      oldStartRow: 3, oldRowCount: 4, newStartRow: 3, newRowCount: 5,
      sectionHeading: 'zero',
      marker: markRange(layers.hunk, 0, 6),
      regions: [
        new Unchanged(markRange(layers.unchanged, 0)),
        new Deletion(markRange(layers.deletion, 1, 2)),
        new Addition(markRange(layers.addition, 3, 5)),
        new Unchanged(markRange(layers.unchanged, 6)),
      ],
    }),
    new Hunk({
      oldStartRow: 12, oldRowCount: 9, newStartRow: 13, newRowCount: 7,
      sectionHeading: 'one',
      marker: markRange(layers.hunk, 7, 18),
      regions: [
        new Unchanged(markRange(layers.unchanged, 7)),
        new Addition(markRange(layers.addition, 8, 9)),
        new Unchanged(markRange(layers.unchanged, 10, 11)),
        new Deletion(markRange(layers.deletion, 12, 16)),
        new Addition(markRange(layers.addition, 17, 17)),
        new Unchanged(markRange(layers.unchanged, 18)),
      ],
    }),
    new Hunk({
      oldStartRow: 26, oldRowCount: 4, newStartRow: 25, newRowCount: 3,
      sectionHeading: 'two',
      marker: markRange(layers.hunk, 19, 23),
      regions: [
        new Unchanged(markRange(layers.unchanged, 19)),
        new Addition(markRange(layers.addition, 20)),
        new Deletion(markRange(layers.deletion, 21, 22)),
        new Unchanged(markRange(layers.unchanged, 23)),
      ],
    }),
    new Hunk({
      oldStartRow: 32, oldRowCount: 1, newStartRow: 30, newRowCount: 2,
      sectionHeading: 'three',
      marker: markRange(layers.hunk, 24, 26),
      regions: [
        new Unchanged(markRange(layers.unchanged, 24)),
        new Addition(markRange(layers.addition, 25)),
        new NoNewline(markRange(layers.noNewline, 26)),
      ],
    }),
  ];
  const marker = markRange(layers.patch, 0, 26);

  return {
    patch: new Patch({status: 'modified', hunks, marker}),
    buffer,
    layers,
    marker,
  };
}
