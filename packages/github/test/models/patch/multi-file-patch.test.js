import dedent from 'dedent-js';

import {multiFilePatchBuilder, filePatchBuilder} from '../../builder/patch';

import {DEFERRED, COLLAPSED, EXPANDED} from '../../../lib/models/patch/patch';
import MultiFilePatch from '../../../lib/models/patch/multi-file-patch';
import PatchBuffer from '../../../lib/models/patch/patch-buffer';

import {assertInFilePatch, assertMarkerRanges} from '../../helpers';

describe('MultiFilePatch', function() {
  it('creates an empty patch', function() {
    const empty = MultiFilePatch.createNull();
    assert.isFalse(empty.anyPresent());
    assert.lengthOf(empty.getFilePatches(), 0);
  });

  it('detects when it is not empty', function() {
    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(filePatch => {
        filePatch
          .setOldFile(file => file.path('file-0.txt'))
          .setNewFile(file => file.path('file-0.txt'));
      })
      .build();

    assert.isTrue(multiFilePatch.anyPresent());
  });

  describe('clone', function() {
    let original;

    beforeEach(function() {
      original = multiFilePatchBuilder()
        .addFilePatch()
        .addFilePatch()
        .build()
        .multiFilePatch;
    });

    it('defaults to creating an exact copy', function() {
      const dup = original.clone();

      assert.strictEqual(dup.getBuffer(), original.getBuffer());
      assert.strictEqual(dup.getPatchLayer(), original.getPatchLayer());
      assert.strictEqual(dup.getHunkLayer(), original.getHunkLayer());
      assert.strictEqual(dup.getUnchangedLayer(), original.getUnchangedLayer());
      assert.strictEqual(dup.getAdditionLayer(), original.getAdditionLayer());
      assert.strictEqual(dup.getDeletionLayer(), original.getDeletionLayer());
      assert.strictEqual(dup.getNoNewlineLayer(), original.getNoNewlineLayer());
      assert.strictEqual(dup.getFilePatches(), original.getFilePatches());
    });

    it('creates a copy with a new PatchBuffer', function() {
      const {multiFilePatch} = multiFilePatchBuilder().build();
      const dup = original.clone({patchBuffer: multiFilePatch.getPatchBuffer()});

      assert.strictEqual(dup.getBuffer(), multiFilePatch.getBuffer());
      assert.strictEqual(dup.getPatchLayer(), multiFilePatch.getPatchLayer());
      assert.strictEqual(dup.getHunkLayer(), multiFilePatch.getHunkLayer());
      assert.strictEqual(dup.getUnchangedLayer(), multiFilePatch.getUnchangedLayer());
      assert.strictEqual(dup.getAdditionLayer(), multiFilePatch.getAdditionLayer());
      assert.strictEqual(dup.getDeletionLayer(), multiFilePatch.getDeletionLayer());
      assert.strictEqual(dup.getNoNewlineLayer(), multiFilePatch.getNoNewlineLayer());
      assert.strictEqual(dup.getFilePatches(), original.getFilePatches());
    });

    it('creates a copy with a new set of file patches', function() {
      const nfp = [
        filePatchBuilder().build().filePatch,
        filePatchBuilder().build().filePatch,
      ];

      const dup = original.clone({filePatches: nfp});
      assert.strictEqual(dup.getBuffer(), original.getBuffer());
      assert.strictEqual(dup.getPatchLayer(), original.getPatchLayer());
      assert.strictEqual(dup.getHunkLayer(), original.getHunkLayer());
      assert.strictEqual(dup.getUnchangedLayer(), original.getUnchangedLayer());
      assert.strictEqual(dup.getAdditionLayer(), original.getAdditionLayer());
      assert.strictEqual(dup.getDeletionLayer(), original.getDeletionLayer());
      assert.strictEqual(dup.getNoNewlineLayer(), original.getNoNewlineLayer());
      assert.strictEqual(dup.getFilePatches(), nfp);
    });
  });

  it('has an accessor for its file patches', function() {
    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(filePatch => filePatch.setOldFile(file => file.path('file-0.txt')))
      .addFilePatch(filePatch => filePatch.setOldFile(file => file.path('file-1.txt')))
      .build();

    assert.lengthOf(multiFilePatch.getFilePatches(), 2);
    const [fp0, fp1] = multiFilePatch.getFilePatches();
    assert.strictEqual(fp0.getOldPath(), 'file-0.txt');
    assert.strictEqual(fp1.getOldPath(), 'file-1.txt');
  });

  describe('didAnyChangeExecutableMode()', function() {
    it('detects when at least one patch contains an executable mode change', function() {
      const {multiFilePatch: yes} = multiFilePatchBuilder()
        .addFilePatch(filePatch => {
          filePatch.setOldFile(file => file.path('file-0.txt'));
          filePatch.setNewFile(file => file.path('file-0.txt').executable());
        })
        .build();
      assert.isTrue(yes.didAnyChangeExecutableMode());
    });

    it('detects when none of the patches contain an executable mode change', function() {
      const {multiFilePatch: no} = multiFilePatchBuilder()
        .addFilePatch(filePatch => filePatch.setOldFile(file => file.path('file-0.txt')))
        .addFilePatch(filePatch => filePatch.setOldFile(file => file.path('file-1.txt')))
        .build();
      assert.isFalse(no.didAnyChangeExecutableMode());
    });
  });

  describe('anyHaveTypechange()', function() {
    it('detects when at least one patch contains a symlink change', function() {
      const {multiFilePatch: yes} = multiFilePatchBuilder()
        .addFilePatch(filePatch => filePatch.setOldFile(file => file.path('file-0.txt')))
        .addFilePatch(filePatch => {
          filePatch.setOldFile(file => file.path('file-0.txt'));
          filePatch.setNewFile(file => file.path('file-0.txt').symlinkTo('somewhere.txt'));
        })
        .build();
      assert.isTrue(yes.anyHaveTypechange());
    });

    it('detects when none of its patches contain a symlink change', function() {
      const {multiFilePatch: no} = multiFilePatchBuilder()
        .addFilePatch(filePatch => filePatch.setOldFile(file => file.path('file-0.txt')))
        .addFilePatch(filePatch => filePatch.setOldFile(file => file.path('file-1.txt')))
        .build();
      assert.isFalse(no.anyHaveTypechange());
    });
  });

  it('computes the maximum line number width of any hunk in any patch', function() {
    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('file-0.txt'));
        fp.addHunk(h => h.oldRow(10));
        fp.addHunk(h => h.oldRow(99));
      })
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('file-1.txt'));
        fp.addHunk(h => h.oldRow(5));
        fp.addHunk(h => h.oldRow(15));
      })
      .build();

    assert.strictEqual(multiFilePatch.getMaxLineNumberWidth(), 3);
  });

  it('locates an individual FilePatch by marker lookup', function() {
    const builder = multiFilePatchBuilder();
    for (let i = 0; i < 10; i++) {
      builder.addFilePatch(fp => {
        fp.setOldFile(f => f.path(`file-${i}.txt`));
        fp.addHunk(h => {
          h.oldRow(1).unchanged('a', 'b').added('c').deleted('d').unchanged('e');
        });
        fp.addHunk(h => {
          h.oldRow(10).unchanged('f').deleted('g', 'h', 'i').unchanged('j');
        });
      });
    }
    const {multiFilePatch} = builder.build();
    const fps = multiFilePatch.getFilePatches();

    assert.isUndefined(multiFilePatch.getFilePatchAt(-1));
    assert.strictEqual(multiFilePatch.getFilePatchAt(0), fps[0]);
    assert.strictEqual(multiFilePatch.getFilePatchAt(9), fps[0]);
    assert.strictEqual(multiFilePatch.getFilePatchAt(10), fps[1]);
    assert.strictEqual(multiFilePatch.getFilePatchAt(99), fps[9]);
    assert.isUndefined(multiFilePatch.getFilePatchAt(101));
  });

  it('creates a set of all unique paths referenced by patches', function() {
    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('file-0-before.txt'));
        fp.setNewFile(f => f.path('file-0-after.txt'));
      })
      .addFilePatch(fp => {
        fp.status('added');
        fp.nullOldFile();
        fp.setNewFile(f => f.path('file-1.txt'));
      })
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('file-2.txt'));
        fp.setNewFile(f => f.path('file-2.txt'));
      })
      .build();

    assert.sameMembers(
      Array.from(multiFilePatch.getPathSet()),
      ['file-0-before.txt', 'file-0-after.txt', 'file-1.txt', 'file-2.txt'],
    );
  });

  it('locates a Hunk by marker lookup', function() {
    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(fp => {
        fp.addHunk(h => h.oldRow(1).added('0', '1', '2', '3', '4'));
        fp.addHunk(h => h.oldRow(10).deleted('5', '6', '7', '8', '9'));
      })
      .addFilePatch(fp => {
        fp.addHunk(h => h.oldRow(5).unchanged('10', '11').added('12').deleted('13'));
        fp.addHunk(h => h.oldRow(20).unchanged('14').deleted('15'));
      })
      .addFilePatch(fp => {
        fp.status('deleted');
        fp.addHunk(h => h.oldRow(4).deleted('16', '17', '18', '19'));
      })
      .build();

    const [fp0, fp1, fp2] = multiFilePatch.getFilePatches();

    assert.isUndefined(multiFilePatch.getHunkAt(-1));
    assert.strictEqual(multiFilePatch.getHunkAt(0), fp0.getHunks()[0]);
    assert.strictEqual(multiFilePatch.getHunkAt(4), fp0.getHunks()[0]);
    assert.strictEqual(multiFilePatch.getHunkAt(5), fp0.getHunks()[1]);
    assert.strictEqual(multiFilePatch.getHunkAt(9), fp0.getHunks()[1]);
    assert.strictEqual(multiFilePatch.getHunkAt(10), fp1.getHunks()[0]);
    assert.strictEqual(multiFilePatch.getHunkAt(15), fp1.getHunks()[1]);
    assert.strictEqual(multiFilePatch.getHunkAt(16), fp2.getHunks()[0]);
    assert.strictEqual(multiFilePatch.getHunkAt(19), fp2.getHunks()[0]);
    assert.isUndefined(multiFilePatch.getHunkAt(21));
  });

  it('represents itself as an apply-ready string', function() {
    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('file-0.txt'));
        fp.addHunk(h => h.oldRow(1).unchanged('0;0;0').added('0;0;1').deleted('0;0;2').unchanged('0;0;3'));
        fp.addHunk(h => h.oldRow(10).unchanged('0;1;0').added('0;1;1').deleted('0;1;2').unchanged('0;1;3'));
      })
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('file-1.txt'));
        fp.addHunk(h => h.oldRow(1).unchanged('1;0;0').added('1;0;1').deleted('1;0;2').unchanged('1;0;3'));
        fp.addHunk(h => h.oldRow(10).unchanged('1;1;0').added('1;1;1').deleted('1;1;2').unchanged('1;1;3'));
      })
      .build();

    assert.strictEqual(multiFilePatch.toString(), dedent`
      diff --git a/file-0.txt b/file-0.txt
      --- a/file-0.txt
      +++ b/file-0.txt
      @@ -1,3 +1,3 @@
       0;0;0
      +0;0;1
      -0;0;2
       0;0;3
      @@ -10,3 +10,3 @@
       0;1;0
      +0;1;1
      -0;1;2
       0;1;3
      diff --git a/file-1.txt b/file-1.txt
      --- a/file-1.txt
      +++ b/file-1.txt
      @@ -1,3 +1,3 @@
       1;0;0
      +1;0;1
      -1;0;2
       1;0;3
      @@ -10,3 +10,3 @@
       1;1;0
      +1;1;1
      -1;1;2
       1;1;3\n
    `);
  });

  it('adopts a new buffer', function() {
    const {multiFilePatch} = multiFilePatchBuilder()
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('A0.txt'));
        fp.addHunk(h => h.unchanged('a0').added('a1').deleted('a2').unchanged('a3'));
      })
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('A1.txt'));
        fp.addHunk(h => h.unchanged('a4').deleted('a5').unchanged('a6'));
        fp.addHunk(h => h.unchanged('a7').added('a8').unchanged('a9'));
      })
      .addFilePatch(fp => {
        fp.setOldFile(f => f.path('A2.txt'));
        fp.addHunk(h => h.oldRow(99).deleted('a10').noNewline());
      })
      .build();

    const nextBuffer = new PatchBuffer();

    multiFilePatch.adoptBuffer(nextBuffer);

    assert.strictEqual(nextBuffer.getBuffer(), multiFilePatch.getBuffer());
    assert.strictEqual(nextBuffer.getLayer('patch'), multiFilePatch.getPatchLayer());
    assert.strictEqual(nextBuffer.getLayer('hunk'), multiFilePatch.getHunkLayer());
    assert.strictEqual(nextBuffer.getLayer('unchanged'), multiFilePatch.getUnchangedLayer());
    assert.strictEqual(nextBuffer.getLayer('addition'), multiFilePatch.getAdditionLayer());
    assert.strictEqual(nextBuffer.getLayer('deletion'), multiFilePatch.getDeletionLayer());
    assert.strictEqual(nextBuffer.getLayer('nonewline'), multiFilePatch.getNoNewlineLayer());

    assert.deepEqual(nextBuffer.getBuffer().getText(), dedent`
      a0
      a1
      a2
      a3
      a4
      a5
      a6
      a7
      a8
      a9
      a10
       No newline at end of file
    `);

    const assertMarkedLayerRanges = (layer, ranges) => {
      assert.deepEqual(layer.getMarkers().map(m => m.getRange().serialize()), ranges);
    };

    assertMarkedLayerRanges(nextBuffer.getLayer('patch'), [
      [[0, 0], [3, 2]], [[4, 0], [9, 2]], [[10, 0], [11, 26]],
    ]);
    assertMarkedLayerRanges(nextBuffer.getLayer('hunk'), [
      [[0, 0], [3, 2]], [[4, 0], [6, 2]], [[7, 0], [9, 2]], [[10, 0], [11, 26]],
    ]);
    assertMarkedLayerRanges(nextBuffer.getLayer('unchanged'), [
      [[0, 0], [0, 2]], [[3, 0], [3, 2]], [[4, 0], [4, 2]], [[6, 0], [6, 2]], [[7, 0], [7, 2]], [[9, 0], [9, 2]],
    ]);
    assertMarkedLayerRanges(nextBuffer.getLayer('addition'), [
      [[1, 0], [1, 2]], [[8, 0], [8, 2]],
    ]);
    assertMarkedLayerRanges(nextBuffer.getLayer('deletion'), [
      [[2, 0], [2, 2]], [[5, 0], [5, 2]], [[10, 0], [10, 3]],
    ]);
    assertMarkedLayerRanges(nextBuffer.getLayer('nonewline'), [
      [[11, 0], [11, 26]],
    ]);

    assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('A0.txt', 1), 0);
    assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('A1.txt', 5), 7);
  });

  describe('derived patch generation', function() {
    let multiFilePatch, rowSet;

    beforeEach(function() {
      // The row content pattern here is: ${fileno};${hunkno};${lineno}, with a (**) if it's selected
      multiFilePatch = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file-0.txt'));
          fp.addHunk(h => h.oldRow(1).unchanged('0;0;0').added('0;0;1').deleted('0;0;2').unchanged('0;0;3'));
          fp.addHunk(h => h.oldRow(10).unchanged('0;1;0').added('0;1;1').deleted('0;1;2').unchanged('0;1;3'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file-1.txt'));
          fp.addHunk(h => h.oldRow(1).unchanged('1;0;0').added('1;0;1 (**)').deleted('1;0;2').unchanged('1;0;3'));
          fp.addHunk(h => h.oldRow(10).unchanged('1;1;0').added('1;1;1').deleted('1;1;2 (**)').unchanged('1;1;3'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file-2.txt'));
          fp.addHunk(h => h.oldRow(1).unchanged('2;0;0').added('2;0;1').deleted('2;0;2').unchanged('2;0;3'));
          fp.addHunk(h => h.oldRow(10).unchanged('2;1;0').added('2;1;1').deleted('2;2;2').unchanged('2;1;3'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file-3.txt'));
          fp.addHunk(h => h.oldRow(1).unchanged('3;0;0').added('3;0;1 (**)').deleted('3;0;2 (**)').unchanged('3;0;3'));
          fp.addHunk(h => h.oldRow(10).unchanged('3;1;0').added('3;1;1').deleted('3;2;2').unchanged('3;1;3'));
        })
        .build()
        .multiFilePatch;

      // Buffer rows corresponding to the rows marked with (**) above
      rowSet = new Set([9, 14, 25, 26]);
    });

    it('generates a stage patch for arbitrary buffer rows', function() {
      const stagePatch = multiFilePatch.getStagePatchForLines(rowSet);

      assert.strictEqual(stagePatch.getBuffer().getText(), dedent`
        1;0;0
        1;0;1 (**)
        1;0;2
        1;0;3
        1;1;0
        1;1;2 (**)
        1;1;3
        3;0;0
        3;0;1 (**)
        3;0;2 (**)
        3;0;3

      `);

      assert.lengthOf(stagePatch.getFilePatches(), 2);
      const [fp0, fp1] = stagePatch.getFilePatches();
      assert.strictEqual(fp0.getOldPath(), 'file-1.txt');
      assertInFilePatch(fp0, stagePatch.getBuffer()).hunks(
        {
          startRow: 0, endRow: 3,
          header: '@@ -1,3 +1,4 @@',
          regions: [
            {kind: 'unchanged', string: ' 1;0;0\n', range: [[0, 0], [0, 5]]},
            {kind: 'addition', string: '+1;0;1 (**)\n', range: [[1, 0], [1, 10]]},
            {kind: 'unchanged', string: ' 1;0;2\n 1;0;3\n', range: [[2, 0], [3, 5]]},
          ],
        },
        {
          startRow: 4, endRow: 6,
          header: '@@ -10,3 +11,2 @@',
          regions: [
            {kind: 'unchanged', string: ' 1;1;0\n', range: [[4, 0], [4, 5]]},
            {kind: 'deletion', string: '-1;1;2 (**)\n', range: [[5, 0], [5, 10]]},
            {kind: 'unchanged', string: ' 1;1;3\n', range: [[6, 0], [6, 5]]},
          ],
        },
      );

      assert.strictEqual(fp1.getOldPath(), 'file-3.txt');
      assertInFilePatch(fp1, stagePatch.getBuffer()).hunks(
        {
          startRow: 7, endRow: 10,
          header: '@@ -1,3 +1,3 @@',
          regions: [
            {kind: 'unchanged', string: ' 3;0;0\n', range: [[7, 0], [7, 5]]},
            {kind: 'addition', string: '+3;0;1 (**)\n', range: [[8, 0], [8, 10]]},
            {kind: 'deletion', string: '-3;0;2 (**)\n', range: [[9, 0], [9, 10]]},
            {kind: 'unchanged', string: ' 3;0;3\n', range: [[10, 0], [10, 5]]},
          ],
        },
      );
    });

    it('generates a stage patch from an arbitrary hunk', function() {
      const hunk = multiFilePatch.getFilePatches()[0].getHunks()[1];
      const stagePatch = multiFilePatch.getStagePatchForHunk(hunk);

      assert.strictEqual(stagePatch.getBuffer().getText(), dedent`
        0;1;0
        0;1;1
        0;1;2
        0;1;3

      `);
      assert.lengthOf(stagePatch.getFilePatches(), 1);
      const [fp0] = stagePatch.getFilePatches();
      assert.strictEqual(fp0.getOldPath(), 'file-0.txt');
      assert.strictEqual(fp0.getNewPath(), 'file-0.txt');
      assertInFilePatch(fp0, stagePatch.getBuffer()).hunks(
        {
          startRow: 0, endRow: 3,
          header: '@@ -10,3 +10,3 @@',
          regions: [
            {kind: 'unchanged', string: ' 0;1;0\n', range: [[0, 0], [0, 5]]},
            {kind: 'addition', string: '+0;1;1\n', range: [[1, 0], [1, 5]]},
            {kind: 'deletion', string: '-0;1;2\n', range: [[2, 0], [2, 5]]},
            {kind: 'unchanged', string: ' 0;1;3\n', range: [[3, 0], [3, 5]]},
          ],
        },
      );
    });

    it('generates an unstage patch for arbitrary buffer rows', function() {
      const unstagePatch = multiFilePatch.getUnstagePatchForLines(rowSet);

      assert.strictEqual(unstagePatch.getBuffer().getText(), dedent`
        1;0;0
        1;0;1 (**)
        1;0;3
        1;1;0
        1;1;1
        1;1;2 (**)
        1;1;3
        3;0;0
        3;0;1 (**)
        3;0;2 (**)
        3;0;3

      `);

      assert.lengthOf(unstagePatch.getFilePatches(), 2);
      const [fp0, fp1] = unstagePatch.getFilePatches();
      assert.strictEqual(fp0.getOldPath(), 'file-1.txt');
      assertInFilePatch(fp0, unstagePatch.getBuffer()).hunks(
        {
          startRow: 0, endRow: 2,
          header: '@@ -1,3 +1,2 @@',
          regions: [
            {kind: 'unchanged', string: ' 1;0;0\n', range: [[0, 0], [0, 5]]},
            {kind: 'deletion', string: '-1;0;1 (**)\n', range: [[1, 0], [1, 10]]},
            {kind: 'unchanged', string: ' 1;0;3\n', range: [[2, 0], [2, 5]]},
          ],
        },
        {
          startRow: 3, endRow: 6,
          header: '@@ -10,3 +9,4 @@',
          regions: [
            {kind: 'unchanged', string: ' 1;1;0\n 1;1;1\n', range: [[3, 0], [4, 5]]},
            {kind: 'addition', string: '+1;1;2 (**)\n', range: [[5, 0], [5, 10]]},
            {kind: 'unchanged', string: ' 1;1;3\n', range: [[6, 0], [6, 5]]},
          ],
        },
      );

      assert.strictEqual(fp1.getOldPath(), 'file-3.txt');
      assertInFilePatch(fp1, unstagePatch.getBuffer()).hunks(
        {
          startRow: 7, endRow: 10,
          header: '@@ -1,3 +1,3 @@',
          regions: [
            {kind: 'unchanged', string: ' 3;0;0\n', range: [[7, 0], [7, 5]]},
            {kind: 'deletion', string: '-3;0;1 (**)\n', range: [[8, 0], [8, 10]]},
            {kind: 'addition', string: '+3;0;2 (**)\n', range: [[9, 0], [9, 10]]},
            {kind: 'unchanged', string: ' 3;0;3\n', range: [[10, 0], [10, 5]]},
          ],
        },
      );
    });

    it('generates an unstage patch for an arbitrary hunk', function() {
      const hunk = multiFilePatch.getFilePatches()[1].getHunks()[0];
      const unstagePatch = multiFilePatch.getUnstagePatchForHunk(hunk);

      assert.strictEqual(unstagePatch.getBuffer().getText(), dedent`
        1;0;0
        1;0;1 (**)
        1;0;2
        1;0;3

      `);
      assert.lengthOf(unstagePatch.getFilePatches(), 1);
      const [fp0] = unstagePatch.getFilePatches();
      assert.strictEqual(fp0.getOldPath(), 'file-1.txt');
      assert.strictEqual(fp0.getNewPath(), 'file-1.txt');
      assertInFilePatch(fp0, unstagePatch.getBuffer()).hunks(
        {
          startRow: 0, endRow: 3,
          header: '@@ -1,3 +1,3 @@',
          regions: [
            {kind: 'unchanged', string: ' 1;0;0\n', range: [[0, 0], [0, 5]]},
            {kind: 'deletion', string: '-1;0;1 (**)\n', range: [[1, 0], [1, 10]]},
            {kind: 'addition', string: '+1;0;2\n', range: [[2, 0], [2, 5]]},
            {kind: 'unchanged', string: ' 1;0;3\n', range: [[3, 0], [3, 5]]},
          ],
        },
      );
    });
  });

  describe('maximum selection index', function() {
    it('returns zero if there are no selections', function() {
      const {multiFilePatch} = multiFilePatchBuilder().addFilePatch().build();
      assert.strictEqual(multiFilePatch.getMaxSelectionIndex(new Set()), 0);
    });

    it('returns the ordinal index of the highest selected change row', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.addHunk(h => h.unchanged('.').added('0', '1', 'x *').unchanged('.'));
          fp.addHunk(h => h.unchanged('.').deleted('2').added('3').unchanged('.'));
        })
        .addFilePatch(fp => {
          fp.addHunk(h => h.unchanged('.').deleted('4', '5 *', '6').unchanged('.'));
          fp.addHunk(h => h.unchanged('.').added('7').unchanged('.'));
        })
        .build();

      assert.strictEqual(multiFilePatch.getMaxSelectionIndex(new Set([3])), 2);
      assert.strictEqual(multiFilePatch.getMaxSelectionIndex(new Set([3, 11])), 5);
    });
  });

  describe('selection range by change index', function() {
    it('selects the last change row if no longer present', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.addHunk(h => h.unchanged('.').added('0', '1', '2').unchanged('.'));
          fp.addHunk(h => h.unchanged('.').deleted('3').added('4').unchanged('.'));
        })
        .addFilePatch(fp => {
          fp.addHunk(h => h.unchanged('.').deleted('5', '6', '7').unchanged('.'));
          fp.addHunk(h => h.unchanged('.').added('8').unchanged('.'));
        })
        .build();

      assert.deepEqual(multiFilePatch.getSelectionRangeForIndex(9).serialize(), [[15, 0], [15, Infinity]]);
    });

    it('returns the range of the change row by ordinal', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.addHunk(h => h.unchanged('.').added('0', '1', '2').unchanged('.'));
          fp.addHunk(h => h.unchanged('.').deleted('3').added('4').unchanged('.'));
        })
        .addFilePatch(fp => {
          fp.addHunk(h => h.unchanged('.').deleted('5', '6', '7').unchanged('.'));
          fp.addHunk(h => h.unchanged('.').added('8').unchanged('.'));
        })
        .build();

      assert.deepEqual(multiFilePatch.getSelectionRangeForIndex(0).serialize(), [[1, 0], [1, Infinity]]);
      assert.deepEqual(multiFilePatch.getSelectionRangeForIndex(1).serialize(), [[2, 0], [2, Infinity]]);
      assert.deepEqual(multiFilePatch.getSelectionRangeForIndex(2).serialize(), [[3, 0], [3, Infinity]]);
      assert.deepEqual(multiFilePatch.getSelectionRangeForIndex(3).serialize(), [[6, 0], [6, Infinity]]);
      assert.deepEqual(multiFilePatch.getSelectionRangeForIndex(4).serialize(), [[7, 0], [7, Infinity]]);
      assert.deepEqual(multiFilePatch.getSelectionRangeForIndex(5).serialize(), [[10, 0], [10, Infinity]]);
      assert.deepEqual(multiFilePatch.getSelectionRangeForIndex(6).serialize(), [[11, 0], [11, Infinity]]);
      assert.deepEqual(multiFilePatch.getSelectionRangeForIndex(7).serialize(), [[12, 0], [12, Infinity]]);
      assert.deepEqual(multiFilePatch.getSelectionRangeForIndex(8).serialize(), [[15, 0], [15, Infinity]]);
    });
  });

  describe('file-patch spanning selection detection', function() {
    let multiFilePatch;

    beforeEach(function() {
      multiFilePatch = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file-0'));
          fp.addHunk(h => h.unchanged('0').added('1').deleted('2', '3').unchanged('4'));
          fp.addHunk(h => h.unchanged('5').added('6').unchanged('7'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file-1'));
          fp.addHunk(h => h.unchanged('8').deleted('9', '10').unchanged('11'));
        })
        .build()
        .multiFilePatch;
    });

    it('with buffer positions belonging to a single patch', function() {
      assert.isFalse(multiFilePatch.spansMultipleFiles([1, 5]));
    });

    it('with buffer positions belonging to multiple patches', function() {
      assert.isTrue(multiFilePatch.spansMultipleFiles([6, 10]));
    });
  });

  describe('isPatchVisible', function() {
    it('returns false if patch exceeds large diff threshold', function() {
      const multiFilePatch = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file-0'));
          fp.renderStatus(DEFERRED);
        })
        .build()
        .multiFilePatch;
      assert.isFalse(multiFilePatch.isPatchVisible('file-0'));
    });

    it('returns false if patch is collapsed', function() {
      const multiFilePatch = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file-0'));
          fp.renderStatus(COLLAPSED);
        }).build().multiFilePatch;

      assert.isFalse(multiFilePatch.isPatchVisible('file-0'));
    });

    it('returns true if patch is expanded', function() {
      const multiFilePatch = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file-0'));
          fp.renderStatus(EXPANDED);
        })
        .build()
        .multiFilePatch;

      assert.isTrue(multiFilePatch.isPatchVisible('file-0'));
    });

    it('multiFilePatch with multiple hunks returns correct values', function() {
      const multiFilePatch = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('expanded-file'));
          fp.renderStatus(EXPANDED);
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('too-large-file'));
          fp.renderStatus(DEFERRED);
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('collapsed-file'));
          fp.renderStatus(COLLAPSED);
        })
        .build()
        .multiFilePatch;

      assert.isTrue(multiFilePatch.isPatchVisible('expanded-file'));
      assert.isFalse(multiFilePatch.isPatchVisible('too-large-file'));
      assert.isFalse(multiFilePatch.isPatchVisible('collapsed-file'));
    });

    it('returns false if patch does not exist', function() {
      const multiFilePatch = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file-0'));
          fp.renderStatus(EXPANDED);
        })
        .build()
        .multiFilePatch;
      assert.isFalse(multiFilePatch.isPatchVisible('invalid-file-path'));
    });
  });

  describe('getPreviewPatchBuffer', function() {
    it('returns a PatchBuffer containing nearby rows of the MultiFilePatch', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file.txt'));
          fp.addHunk(h => h.unchanged('0').added('1', '2').unchanged('3').deleted('4', '5').unchanged('6'));
          fp.addHunk(h => h.unchanged('7').deleted('8').unchanged('9', '10'));
        })
        .build();

      const subPatch = multiFilePatch.getPreviewPatchBuffer('file.txt', 6, 4);
      assert.strictEqual(subPatch.getBuffer().getText(), dedent`
        2
        3
        4
        5
      `);
      assertMarkerRanges(subPatch.getLayer('patch'), [[0, 0], [3, 1]]);
      assertMarkerRanges(subPatch.getLayer('hunk'), [[0, 0], [3, 1]]);
      assertMarkerRanges(subPatch.getLayer('unchanged'), [[1, 0], [1, 1]]);
      assertMarkerRanges(subPatch.getLayer('addition'), [[0, 0], [0, 1]]);
      assertMarkerRanges(subPatch.getLayer('deletion'), [[2, 0], [3, 1]]);
      assertMarkerRanges(subPatch.getLayer('nonewline'));
    });

    it('truncates the returned buffer at hunk boundaries', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file.txt'));
          fp.addHunk(h => h.unchanged('0').added('1', '2').unchanged('3'));
          fp.addHunk(h => h.unchanged('7').deleted('8').unchanged('9', '10'));
        })
        .build();

      // diff row 8 = buffer row 9
      const subPatch = multiFilePatch.getPreviewPatchBuffer('file.txt', 8, 4);

      assert.strictEqual(subPatch.getBuffer().getText(), dedent`
        7
        8
        9
      `);
      assertMarkerRanges(subPatch.getLayer('patch'), [[0, 0], [2, 1]]);
      assertMarkerRanges(subPatch.getLayer('hunk'), [[0, 0], [2, 1]]);
      assertMarkerRanges(subPatch.getLayer('unchanged'), [[0, 0], [0, 1]], [[2, 0], [2, 1]]);
      assertMarkerRanges(subPatch.getLayer('addition'));
      assertMarkerRanges(subPatch.getLayer('deletion'), [[1, 0], [1, 1]]);
      assertMarkerRanges(subPatch.getLayer('nonewline'));
    });

    it('excludes zero-length markers from adjacent patches, hunks, and regions', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('mode-change-0.txt'));
          fp.setNewFile(f => f.path('mode-change-0.txt').executable());
          fp.empty();
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file.txt'));
          fp.addHunk(h => h.unchanged('0').added('1', '2').unchanged('3'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('mode-change-1.txt').executable());
          fp.setNewFile(f => f.path('mode-change-1.txt'));
          fp.empty();
        })
        .build();

      // diff row 4 = buffer row 3
      const subPatch = multiFilePatch.getPreviewPatchBuffer('file.txt', 4, 4);

      assert.strictEqual(subPatch.getBuffer().getText(), dedent`
        0
        1
        2
        3
      `);
      assertMarkerRanges(subPatch.getLayer('patch'), [[0, 0], [3, 1]]);
      assertMarkerRanges(subPatch.getLayer('hunk'), [[0, 0], [3, 1]]);
      assertMarkerRanges(subPatch.getLayer('unchanged'), [[0, 0], [0, 1]], [[3, 0], [3, 1]]);
      assertMarkerRanges(subPatch.getLayer('addition'), [[1, 0], [2, 1]]);
      assertMarkerRanges(subPatch.getLayer('deletion'));
      assertMarkerRanges(subPatch.getLayer('nonewline'));
    });

    it('logs and returns an empty buffer when called with invalid arguments', function() {
      sinon.stub(console, 'error');

      const {multiFilePatch} = multiFilePatchBuilder().build();
      const subPatch = multiFilePatch.getPreviewPatchBuffer('file.txt', 6, 4);
      assert.strictEqual(subPatch.getBuffer().getText(), '');

      // eslint-disable-next-line no-console
      assert.isTrue(console.error.called);
    });
  });

  describe('diff position translation', function() {
    it('offsets rows in the first hunk by the first hunk header', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file.txt'));
          fp.addHunk(h => {
            h.unchanged('0 (1)').added('1 (2)', '2 (3)').deleted('3 (4)', '4 (5)', '5 (6)').unchanged('6 (7)');
          });
        })
        .build();

      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('file.txt', 1), 0);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('file.txt', 7), 6);
    });

    it('offsets rows by the number of hunks before the diff row', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file.txt'));
          fp.addHunk(h => h.unchanged('0 (1)').added('1 (2)', '2 (3)').deleted('3 (4)').unchanged('4 (5)'));
          fp.addHunk(h => h.unchanged('5 (7)').added('6 (8)', '7 (9)', '8 (10)').unchanged('9 (11)'));
          fp.addHunk(h => h.unchanged('10 (13)').deleted('11 (14)').unchanged('12 (15)'));
        })
        .build();

      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('file.txt', 7), 5);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('file.txt', 11), 9);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('file.txt', 13), 10);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('file.txt', 15), 12);
    });

    it('resets the offset at the start of each file patch', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('0.txt'));
          fp.addHunk(h => h.unchanged('0 (1)').added('1 (2)', '2 (3)').unchanged('3 (4)')); // Offset +1
          fp.addHunk(h => h.unchanged('4 (6)').deleted('5 (7)', '6 (8)', '7 (9)').unchanged('8 (10)')); // Offset +2
          fp.addHunk(h => h.unchanged('9 (12)').deleted('10 (13)').unchanged('11 (14)')); // Offset +3
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('1.txt'));
          fp.addHunk(h => h.unchanged('12 (1)').added('13 (2)').unchanged('14 (3)')); // Offset +1
          fp.addHunk(h => h.unchanged('15 (5)').deleted('16 (6)', '17 (7)', '18 (8)').unchanged('19 (9)')); // Offset +2
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('2.txt'));
          fp.addHunk(h => h.unchanged('20 (1)').added('21 (2)', '22 (3)', '23 (4)', '24 (5)').unchanged('25 (6)')); // Offset +1
          fp.addHunk(h => h.unchanged('26 (8)').deleted('27 (9)', '28 (10)').unchanged('29 (11)')); // Offset +2
          fp.addHunk(h => h.unchanged('30 (13)').added('31 (14)').unchanged('32 (15)')); // Offset +3
        })
        .build();

      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('0.txt', 1), 0);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('0.txt', 4), 3);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('0.txt', 6), 4);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('0.txt', 10), 8);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('0.txt', 12), 9);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('0.txt', 14), 11);

      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('1.txt', 1), 12);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('1.txt', 3), 14);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('1.txt', 5), 15);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('1.txt', 9), 19);

      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('2.txt', 1), 20);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('2.txt', 6), 25);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('2.txt', 8), 26);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('2.txt', 11), 29);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('2.txt', 13), 30);
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('2.txt', 15), 32);
    });

    it('set the offset for diff-gated file patch upon expanding', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('1.txt'));
          fp.addHunk(h => h.unchanged('0 (1)').added('1 (2)', '2 (3)').deleted('3 (4)').unchanged('4 (5)'));
          fp.addHunk(h => h.unchanged('5 (7)').added('6 (8)', '7 (9)', '8 (10)').unchanged('9 (11)'));
          fp.addHunk(h => h.unchanged('10 (13)').deleted('11 (14)').unchanged('12 (15)'));
          fp.renderStatus(DEFERRED);
        })
        .build();
      assert.isTrue(multiFilePatch.isDiffRowOffsetIndexEmpty('1.txt'));
      const [fp] = multiFilePatch.getFilePatches();
      multiFilePatch.expandFilePatch(fp);
      assert.isFalse(multiFilePatch.isDiffRowOffsetIndexEmpty('1.txt'));
      assert.strictEqual(multiFilePatch.getBufferRowForDiffPosition('1.txt', 11), 9);
    });

    it('does not reset the offset for normally collapsed file patch upon expanding', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('0.txt'));
          fp.addHunk(h => h.oldRow(1).unchanged('0-0').deleted('0-1', '0-2').unchanged('0-3'));
        })
        .build();

      const [fp] = multiFilePatch.getFilePatches();
      const stub = sinon.stub(multiFilePatch, 'populateDiffRowOffsetIndices');

      multiFilePatch.collapseFilePatch(fp);
      assert.strictEqual(multiFilePatch.getBuffer().getText(), '');

      multiFilePatch.expandFilePatch(fp);
      assert.isFalse(stub.called);
    });

    it('returns null when called with an unrecognized filename', function() {
      sinon.stub(console, 'error');

      const {multiFilePatch} = multiFilePatchBuilder().build();
      assert.isNull(multiFilePatch.getBufferRowForDiffPosition('file.txt', 1));

      // eslint-disable-next-line no-console
      assert.isTrue(console.error.called);
    });

    it('returns null when called with an out of range diff row', function() {
      sinon.stub(console, 'error');

      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file.txt'));
          fp.addHunk(h => {
            h.unchanged('0').added('1').unchanged('2');
          });
        })
        .build();

      assert.isNull(multiFilePatch.getBufferRowForDiffPosition('file.txt', 5));

      // eslint-disable-next-line no-console
      assert.isTrue(console.error.called);
    });
  });

  describe('collapsing and expanding file patches', function() {
    function hunk({index, start, last}) {
      return {
        startRow: start, endRow: start + 3,
        header: '@@ -1,4 +1,2 @@',
        regions: [
          {kind: 'unchanged', string: ` ${index}-0\n`, range: [[start, 0], [start, 3]]},
          {kind: 'deletion', string: `-${index}-1\n-${index}-2\n`, range: [[start + 1, 0], [start + 2, 3]]},
          {kind: 'unchanged', string: ` ${index}-3${last ? '' : '\n'}`, range: [[start + 3, 0], [start + 3, 3]]},
        ],
      };
    }

    function patchTextForIndexes(indexes) {
      return indexes.map(index => {
        return dedent`
        ${index}-0
        ${index}-1
        ${index}-2
        ${index}-3
        `;
      }).join('\n');
    }

    describe('when there is a single file patch', function() {
      it('collapses and expands the only file patch', function() {
        const {multiFilePatch} = multiFilePatchBuilder()
          .addFilePatch(fp => {
            fp.setOldFile(f => f.path('0.txt'));
            fp.addHunk(h => h.oldRow(1).unchanged('0-0').deleted('0-1', '0-2').unchanged('0-3'));
          })
          .build();

        const [fp0] = multiFilePatch.getFilePatches();

        multiFilePatch.collapseFilePatch(fp0);
        assert.strictEqual(multiFilePatch.getBuffer().getText(), '');
        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks();

        multiFilePatch.expandFilePatch(fp0);
        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([0]));
        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0, last: true}));
      });
    });

    describe('when there are multiple file patches', function() {
      let multiFilePatch, fp0, fp1, fp2, fp3;
      beforeEach(function() {
        const {multiFilePatch: mfp} = multiFilePatchBuilder()
          .addFilePatch(fp => {
            fp.setOldFile(f => f.path('0.txt'));
            fp.addHunk(h => h.oldRow(1).unchanged('0-0').deleted('0-1', '0-2').unchanged('0-3'));
          })
          .addFilePatch(fp => {
            fp.setOldFile(f => f.path('1.txt'));
            fp.addHunk(h => h.oldRow(1).unchanged('1-0').deleted('1-1', '1-2').unchanged('1-3'));
          })
          .addFilePatch(fp => {
            fp.setOldFile(f => f.path('2.txt'));
            fp.addHunk(h => h.oldRow(1).unchanged('2-0').deleted('2-1', '2-2').unchanged('2-3'));
          })
          .addFilePatch(fp => {
            fp.setOldFile(f => f.path('3.txt'));
            fp.addHunk(h => h.oldRow(1).unchanged('3-0').deleted('3-1', '3-2').unchanged('3-3'));
          })
          .build();

        multiFilePatch = mfp;
        const patches = multiFilePatch.getFilePatches();
        fp0 = patches[0];
        fp1 = patches[1];
        fp2 = patches[2];
        fp3 = patches[3];
      });

      it('collapses and expands the first file patch with all following expanded', function() {
        multiFilePatch.collapseFilePatch(fp0);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([1, 2, 3]));
        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks();
        assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 0}));
        assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks(hunk({index: 2, start: 4}));
        assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 8, last: true}));

        multiFilePatch.expandFilePatch(fp0);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([0, 1, 2, 3]));

        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0}));
        assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 4}));
        assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks(hunk({index: 2, start: 8}));
        assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 12, last: true}));
      });

      it('collapses and expands an intermediate file patch while all previous patches are collapsed', function() {
        // collapse pervious files
        multiFilePatch.collapseFilePatch(fp0);
        multiFilePatch.collapseFilePatch(fp1);

        // collapse intermediate file
        multiFilePatch.collapseFilePatch(fp2);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([3]));
        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks();
        assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks();
        assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks();
        assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 0, last: true}));

        multiFilePatch.expandFilePatch(fp2);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([2, 3]));

        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks();
        assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks();
        assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks(hunk({index: 2, start: 0}));
        assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 4, last: true}));
      });

      it('collapses and expands an intermediate file patch while all following patches are collapsed', function() {
        // collapse following files
        multiFilePatch.collapseFilePatch(fp2);
        multiFilePatch.collapseFilePatch(fp3);

        // collapse intermediate file
        multiFilePatch.collapseFilePatch(fp1);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([0]));
        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0, last: true}));
        assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks();
        assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks();
        assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks();

        multiFilePatch.expandFilePatch(fp1);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([0, 1]));

        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0}));
        assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 4, last: true}));
        assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks();
        assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks();
      });

      it('collapses and expands a file patch with uncollapsed file patches before and after it', function() {
        multiFilePatch.collapseFilePatch(fp2);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([0, 1, 3]));
        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0}));
        assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 4}));
        assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks();
        assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 8, last: true}));

        multiFilePatch.expandFilePatch(fp2);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([0, 1, 2, 3]));

        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0}));
        assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 4}));
        assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks(hunk({index: 2, start: 8}));
        assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 12, last: true}));
      });

      it('collapses and expands the final file patch with all previous expanded', function() {
        multiFilePatch.collapseFilePatch(fp3);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([0, 1, 2]));
        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0}));
        assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 4}));
        assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks(hunk({index: 2, start: 8, last: true}));
        assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks();

        multiFilePatch.expandFilePatch(fp3);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([0, 1, 2, 3]));

        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0}));
        assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 4}));
        assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks(hunk({index: 2, start: 8}));
        assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 12, last: true}));
      });

      it('collapses and expands the final two file patches', function() {
        multiFilePatch.collapseFilePatch(fp3);
        multiFilePatch.collapseFilePatch(fp2);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([0, 1]));
        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0}));
        assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 4, last: true}));
        assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks();
        assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks();

        multiFilePatch.expandFilePatch(fp3);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([0, 1, 3]));
        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0}));
        assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 4}));
        assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks();
        assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 8, last: true}));

        multiFilePatch.expandFilePatch(fp2);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([0, 1, 2, 3]));
        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0}));
        assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 4}));
        assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks(hunk({index: 2, start: 8}));
        assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 12, last: true}));
      });

      describe('when all patches are collapsed', function() {
        beforeEach(function() {
          multiFilePatch.collapseFilePatch(fp0);
          multiFilePatch.collapseFilePatch(fp1);
          multiFilePatch.collapseFilePatch(fp2);
          multiFilePatch.collapseFilePatch(fp3);
        });

        it('expands the first file patch', function() {
          assert.strictEqual(multiFilePatch.getBuffer().getText(), '');

          multiFilePatch.expandFilePatch(fp0);

          assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([0]));

          assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0, last: true}));
          assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks();
        });

        it('expands a non-first file patch', function() {
          assert.strictEqual(multiFilePatch.getBuffer().getText(), '');

          multiFilePatch.expandFilePatch(fp2);

          assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([2]));

          assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks(hunk({index: 2, start: 0, last: true}));
          assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks();
        });

        it('expands the final file patch', function() {
          assert.strictEqual(multiFilePatch.getBuffer().getText(), '');

          multiFilePatch.expandFilePatch(fp3);

          assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes([3]));

          assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 0, last: true}));
        });

        it('expands all patches in order', function() {
          assert.strictEqual(multiFilePatch.getBuffer().getText(), '');

          multiFilePatch.expandFilePatch(fp0);
          assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0, last: true}));
          assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks();

          multiFilePatch.expandFilePatch(fp1);
          assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0}));
          assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 4, last: true}));
          assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks();

          multiFilePatch.expandFilePatch(fp2);
          assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0}));
          assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 4}));
          assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks(hunk({index: 2, start: 8, last: true}));
          assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks();

          multiFilePatch.expandFilePatch(fp3);
          assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0}));
          assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 4}));
          assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks(hunk({index: 2, start: 8}));
          assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 12, last: true}));
        });

        it('expands all patches in reverse order', function() {
          assert.strictEqual(multiFilePatch.getBuffer().getText(), '');

          multiFilePatch.expandFilePatch(fp3);
          assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 0, last: true}));

          multiFilePatch.expandFilePatch(fp2);
          assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks(hunk({index: 2, start: 0}));
          assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 4, last: true}));

          multiFilePatch.expandFilePatch(fp1);
          assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks();
          assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 0}));
          assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks(hunk({index: 2, start: 4}));
          assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 8, last: true}));

          multiFilePatch.expandFilePatch(fp0);
          assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks(hunk({index: 0, start: 0}));
          assertInFilePatch(fp1, multiFilePatch.getBuffer()).hunks(hunk({index: 1, start: 4}));
          assertInFilePatch(fp2, multiFilePatch.getBuffer()).hunks(hunk({index: 2, start: 8}));
          assertInFilePatch(fp3, multiFilePatch.getBuffer()).hunks(hunk({index: 3, start: 12, last: true}));
        });
      });

      it('is deterministic regardless of the order in which collapse and expand operations are performed', function() {
        this.timeout(60000);

        const patches = multiFilePatch.getFilePatches();

        function expectVisibleAfter(ops, i) {
          return ops.reduce((visible, op) => (op.index === i ? op.visibleAfter : visible), true);
        }

        const operations = [];
        for (let i = 0; i < patches.length; i++) {
          operations.push({
            index: i,
            visibleAfter: false,
            name: `collapse fp${i}`,
            canHappenAfter: ops => expectVisibleAfter(ops, i),
            action: () => multiFilePatch.collapseFilePatch(patches[i]),
          });

          operations.push({
            index: i,
            visibleAfter: true,
            name: `expand fp${i}`,
            canHappenAfter: ops => !expectVisibleAfter(ops, i),
            action: () => multiFilePatch.expandFilePatch(patches[i]),
          });
        }

        const operationSequences = [];

        function generateSequencesAfter(prefix) {
          const possible = operations
            .filter(op => !prefix.includes(op))
            .filter(op => op.canHappenAfter(prefix));
          if (possible.length === 0) {
            operationSequences.push(prefix);
          } else {
            for (const next of possible) {
              generateSequencesAfter([...prefix, next]);
            }
          }
        }
        generateSequencesAfter([]);

        for (const sequence of operationSequences) {
          // Uncomment to see which sequence is causing problems
          // console.log(sequence.map(op => op.name).join(' -> '));

          // Reset to the all-expanded state
          multiFilePatch.expandFilePatch(fp0);
          multiFilePatch.expandFilePatch(fp1);
          multiFilePatch.expandFilePatch(fp2);
          multiFilePatch.expandFilePatch(fp3);

          // Perform the operations
          for (const operation of sequence) {
            operation.action();
          }

          // Ensure the TextBuffer and Markers are in the expected states
          const visibleIndexes = [];
          for (let i = 0; i < patches.length; i++) {
            if (patches[i].getRenderStatus().isVisible()) {
              visibleIndexes.push(i);
            }
          }
          const lastVisibleIndex = Math.max(...visibleIndexes);

          assert.strictEqual(multiFilePatch.getBuffer().getText(), patchTextForIndexes(visibleIndexes));

          let start = 0;
          for (let i = 0; i < patches.length; i++) {
            const patchAssertions = assertInFilePatch(patches[i], multiFilePatch.getBuffer());
            if (patches[i].getRenderStatus().isVisible()) {
              patchAssertions.hunks(hunk({index: i, start, last: lastVisibleIndex === i}));
              start += 4;
            } else {
              patchAssertions.hunks();
            }
          }
        }
      });
    });

    describe('when a file patch has no content', function() {
      it('collapses and expands', function() {
        const {multiFilePatch} = multiFilePatchBuilder()
          .addFilePatch(fp => {
            fp.setOldFile(f => f.path('0.txt').executable());
            fp.setNewFile(f => f.path('0.txt'));
            fp.empty();
          })
          .build();

        assert.strictEqual(multiFilePatch.getBuffer().getText(), '');

        const [fp0] = multiFilePatch.getFilePatches();

        multiFilePatch.collapseFilePatch(fp0);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), '');
        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks();
        assert.deepEqual(fp0.getMarker().getRange().serialize(), [[0, 0], [0, 0]]);
        assert.isTrue(fp0.getMarker().isValid());
        assert.isFalse(fp0.getMarker().isDestroyed());

        multiFilePatch.expandFilePatch(fp0);

        assert.strictEqual(multiFilePatch.getBuffer().getText(), '');
        assertInFilePatch(fp0, multiFilePatch.getBuffer()).hunks();
        assert.deepEqual(fp0.getMarker().getRange().serialize(), [[0, 0], [0, 0]]);
        assert.isTrue(fp0.getMarker().isValid());
        assert.isFalse(fp0.getMarker().isDestroyed());
      });

      it('does not insert a trailing newline when expanding a final content-less patch', function() {
        const {multiFilePatch} = multiFilePatchBuilder()
          .addFilePatch(fp => {
            fp.setOldFile(f => f.path('0.txt'));
            fp.addHunk(h => h.unchanged('0').added('1').unchanged('2'));
          })
          .addFilePatch(fp => {
            fp.setOldFile(f => f.path('1.txt').executable());
            fp.setNewFile(f => f.path('1.txt'));
            fp.empty();
          })
          .build();
        const [fp0, fp1] = multiFilePatch.getFilePatches();

        assert.isTrue(fp1.getRenderStatus().isVisible());
        assert.strictEqual(multiFilePatch.getBuffer().getText(), dedent`
          0
          1
          2
        `);
        assert.deepEqual(fp0.getMarker().getRange().serialize(), [[0, 0], [2, 1]]);
        assert.deepEqual(fp1.getMarker().getRange().serialize(), [[2, 1], [2, 1]]);

        multiFilePatch.collapseFilePatch(fp1);

        assert.isFalse(fp1.getRenderStatus().isVisible());
        assert.strictEqual(multiFilePatch.getBuffer().getText(), dedent`
          0
          1
          2
        `);
        assert.deepEqual(fp0.getMarker().getRange().serialize(), [[0, 0], [2, 1]]);
        assert.deepEqual(fp1.getMarker().getRange().serialize(), [[2, 1], [2, 1]]);

        multiFilePatch.expandFilePatch(fp1);

        assert.isTrue(fp1.getRenderStatus().isVisible());
        assert.strictEqual(multiFilePatch.getBuffer().getText(), dedent`
          0
          1
          2
        `);
        assert.deepEqual(fp0.getMarker().getRange().serialize(), [[0, 0], [2, 1]]);
        assert.deepEqual(fp1.getMarker().getRange().serialize(), [[2, 1], [2, 1]]);
      });
    });
  });
});
