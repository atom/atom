import {buildFilePatch, buildMultiFilePatch} from '../../../lib/models/patch';
import {DEFERRED, EXPANDED, REMOVED} from '../../../lib/models/patch/patch';
import {multiFilePatchBuilder} from '../../builder/patch';
import {assertInPatch, assertInFilePatch} from '../../helpers';

describe('buildFilePatch', function() {
  it('returns a null patch for an empty diff list', function() {
    const multiFilePatch = buildFilePatch([]);
    const [filePatch] = multiFilePatch.getFilePatches();

    assert.isFalse(filePatch.getOldFile().isPresent());
    assert.isFalse(filePatch.getNewFile().isPresent());
    assert.isFalse(filePatch.getPatch().isPresent());
  });

  describe('with a single diff', function() {
    it('assembles a patch from non-symlink sides', function() {
      const multiFilePatch = buildFilePatch([{
        oldPath: 'old/path',
        oldMode: '100644',
        newPath: 'new/path',
        newMode: '100755',
        status: 'modified',
        hunks: [
          {
            oldStartLine: 0,
            newStartLine: 0,
            oldLineCount: 7,
            newLineCount: 6,
            lines: [
              ' line-0',
              '-line-1',
              '-line-2',
              '-line-3',
              ' line-4',
              '+line-5',
              '+line-6',
              ' line-7',
              ' line-8',
            ],
          },
          {
            oldStartLine: 10,
            newStartLine: 11,
            oldLineCount: 3,
            newLineCount: 3,
            lines: [
              '-line-9',
              ' line-10',
              ' line-11',
              '+line-12',
            ],
          },
          {
            oldStartLine: 20,
            newStartLine: 21,
            oldLineCount: 4,
            newLineCount: 4,
            lines: [
              ' line-13',
              '-line-14',
              '-line-15',
              '+line-16',
              '+line-17',
              ' line-18',
            ],
          },
        ],
      }]);

      assert.lengthOf(multiFilePatch.getFilePatches(), 1);
      const [p] = multiFilePatch.getFilePatches();
      const buffer = multiFilePatch.getBuffer();

      assert.strictEqual(p.getOldPath(), 'old/path');
      assert.strictEqual(p.getOldMode(), '100644');
      assert.strictEqual(p.getNewPath(), 'new/path');
      assert.strictEqual(p.getNewMode(), '100755');
      assert.strictEqual(p.getPatch().getStatus(), 'modified');

      const bufferText =
        'line-0\nline-1\nline-2\nline-3\nline-4\nline-5\nline-6\nline-7\nline-8\nline-9\nline-10\n' +
        'line-11\nline-12\nline-13\nline-14\nline-15\nline-16\nline-17\nline-18';
      assert.strictEqual(buffer.getText(), bufferText);

      assertInPatch(p, buffer).hunks(
        {
          startRow: 0,
          endRow: 8,
          header: '@@ -0,7 +0,6 @@',
          regions: [
            {kind: 'unchanged', string: ' line-0\n', range: [[0, 0], [0, 6]]},
            {kind: 'deletion', string: '-line-1\n-line-2\n-line-3\n', range: [[1, 0], [3, 6]]},
            {kind: 'unchanged', string: ' line-4\n', range: [[4, 0], [4, 6]]},
            {kind: 'addition', string: '+line-5\n+line-6\n', range: [[5, 0], [6, 6]]},
            {kind: 'unchanged', string: ' line-7\n line-8\n', range: [[7, 0], [8, 6]]},
          ],
        },
        {
          startRow: 9,
          endRow: 12,
          header: '@@ -10,3 +11,3 @@',
          regions: [
            {kind: 'deletion', string: '-line-9\n', range: [[9, 0], [9, 6]]},
            {kind: 'unchanged', string: ' line-10\n line-11\n', range: [[10, 0], [11, 7]]},
            {kind: 'addition', string: '+line-12\n', range: [[12, 0], [12, 7]]},
          ],
        },
        {
          startRow: 13,
          endRow: 18,
          header: '@@ -20,4 +21,4 @@',
          regions: [
            {kind: 'unchanged', string: ' line-13\n', range: [[13, 0], [13, 7]]},
            {kind: 'deletion', string: '-line-14\n-line-15\n', range: [[14, 0], [15, 7]]},
            {kind: 'addition', string: '+line-16\n+line-17\n', range: [[16, 0], [17, 7]]},
            {kind: 'unchanged', string: ' line-18', range: [[18, 0], [18, 7]]},
          ],
        },
      );
    });

    it('assembles a patch containing a blank context line', function() {
      const {raw} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('file.txt'));
          fp.addHunk(h => h.oldRow(10).unchanged('', '').added('').deleted('', '').added('', '', '').unchanged(''));
        })
        .build();
      const mfp = buildFilePatch(raw, {});

      assert.lengthOf(mfp.getFilePatches(), 1);
      const [fp] = mfp.getFilePatches();

      assertInFilePatch(fp, mfp.getBuffer()).hunks(
        {
          startRow: 0, endRow: 8, header: '@@ -10,5 +10,7 @@',
          regions: [
            {kind: 'unchanged', string: ' \n \n', range: [[0, 0], [1, 0]]},
            {kind: 'addition', string: '+\n', range: [[2, 0], [2, 0]]},
            {kind: 'deletion', string: '-\n-\n', range: [[3, 0], [4, 0]]},
            {kind: 'addition', string: '+\n+\n+\n', range: [[5, 0], [7, 0]]},
            {kind: 'unchanged', string: ' ', range: [[8, 0], [8, 0]]},
          ],
        },
      );
    });

    it("sets the old file's symlink destination", function() {
      const multiFilePatch = buildFilePatch([{
        oldPath: 'old/path',
        oldMode: '120000',
        newPath: 'new/path',
        newMode: '100644',
        status: 'modified',
        hunks: [
          {
            oldStartLine: 0,
            newStartLine: 0,
            oldLineCount: 0,
            newLineCount: 0,
            lines: [' old/destination'],
          },
        ],
      }]);

      assert.lengthOf(multiFilePatch.getFilePatches(), 1);
      const [p] = multiFilePatch.getFilePatches();
      assert.strictEqual(p.getOldSymlink(), 'old/destination');
      assert.isNull(p.getNewSymlink());
    });

    it("sets the new file's symlink destination", function() {
      const multiFilePatch = buildFilePatch([{
        oldPath: 'old/path',
        oldMode: '100644',
        newPath: 'new/path',
        newMode: '120000',
        status: 'modified',
        hunks: [
          {
            oldStartLine: 0,
            newStartLine: 0,
            oldLineCount: 0,
            newLineCount: 0,
            lines: [' new/destination'],
          },
        ],
      }]);

      assert.lengthOf(multiFilePatch.getFilePatches(), 1);
      const [p] = multiFilePatch.getFilePatches();
      assert.isNull(p.getOldSymlink());
      assert.strictEqual(p.getNewSymlink(), 'new/destination');
    });

    it("sets both files' symlink destinations", function() {
      const multiFilePatch = buildFilePatch([{
        oldPath: 'old/path',
        oldMode: '120000',
        newPath: 'new/path',
        newMode: '120000',
        status: 'modified',
        hunks: [
          {
            oldStartLine: 0,
            newStartLine: 0,
            oldLineCount: 0,
            newLineCount: 0,
            lines: [
              ' old/destination',
              ' --',
              ' new/destination',
            ],
          },
        ],
      }]);

      assert.lengthOf(multiFilePatch.getFilePatches(), 1);
      const [p] = multiFilePatch.getFilePatches();
      assert.strictEqual(p.getOldSymlink(), 'old/destination');
      assert.strictEqual(p.getNewSymlink(), 'new/destination');
    });

    it('assembles a patch from a file deletion', function() {
      const multiFilePatch = buildFilePatch([{
        oldPath: 'old/path',
        oldMode: '100644',
        newPath: null,
        newMode: null,
        status: 'deleted',
        hunks: [
          {
            oldStartLine: 1,
            oldLineCount: 5,
            newStartLine: 0,
            newLineCount: 0,
            lines: [
              '-line-0',
              '-line-1',
              '-line-2',
              '-line-3',
              '-',
            ],
          },
        ],
      }]);

      assert.lengthOf(multiFilePatch.getFilePatches(), 1);
      const [p] = multiFilePatch.getFilePatches();
      const buffer = multiFilePatch.getBuffer();

      assert.isTrue(p.getOldFile().isPresent());
      assert.strictEqual(p.getOldPath(), 'old/path');
      assert.strictEqual(p.getOldMode(), '100644');
      assert.isFalse(p.getNewFile().isPresent());
      assert.strictEqual(p.getPatch().getStatus(), 'deleted');

      const bufferText = 'line-0\nline-1\nline-2\nline-3\n';
      assert.strictEqual(buffer.getText(), bufferText);

      assertInPatch(p, buffer).hunks(
        {
          startRow: 0,
          endRow: 4,
          header: '@@ -1,5 +0,0 @@',
          regions: [
            {kind: 'deletion', string: '-line-0\n-line-1\n-line-2\n-line-3\n-', range: [[0, 0], [4, 0]]},
          ],
        },
      );
    });

    it('assembles a patch from a file addition', function() {
      const multiFilePatch = buildFilePatch([{
        oldPath: null,
        oldMode: null,
        newPath: 'new/path',
        newMode: '100755',
        status: 'added',
        hunks: [
          {
            oldStartLine: 0,
            oldLineCount: 0,
            newStartLine: 1,
            newLineCount: 3,
            lines: [
              '+line-0',
              '+line-1',
              '+line-2',
            ],
          },
        ],
      }]);

      assert.lengthOf(multiFilePatch.getFilePatches(), 1);
      const [p] = multiFilePatch.getFilePatches();
      const buffer = multiFilePatch.getBuffer();

      assert.isFalse(p.getOldFile().isPresent());
      assert.isTrue(p.getNewFile().isPresent());
      assert.strictEqual(p.getNewPath(), 'new/path');
      assert.strictEqual(p.getNewMode(), '100755');
      assert.strictEqual(p.getPatch().getStatus(), 'added');

      const bufferText = 'line-0\nline-1\nline-2';
      assert.strictEqual(buffer.getText(), bufferText);

      assertInPatch(p, buffer).hunks(
        {
          startRow: 0,
          endRow: 2,
          header: '@@ -0,0 +1,3 @@',
          regions: [
            {kind: 'addition', string: '+line-0\n+line-1\n+line-2', range: [[0, 0], [2, 6]]},
          ],
        },
      );
    });

    it('throws an error with an unknown diff status character', function() {
      assert.throws(() => {
        buildFilePatch([{
          oldPath: 'old/path',
          oldMode: '100644',
          newPath: 'new/path',
          newMode: '100644',
          status: 'modified',
          hunks: [{oldStartLine: 0, newStartLine: 0, oldLineCount: 1, newLineCount: 1, lines: ['xline-0']}],
        }]);
      }, /diff status character: "x"/);
    });

    it('parses a no-newline marker', function() {
      const multiFilePatch = buildFilePatch([{
        oldPath: 'old/path',
        oldMode: '100644',
        newPath: 'new/path',
        newMode: '100644',
        status: 'modified',
        hunks: [{oldStartLine: 0, newStartLine: 0, oldLineCount: 1, newLineCount: 1, lines: [
          '+line-0', '-line-1', '\\ No newline at end of file',
        ]}],
      }]);

      assert.lengthOf(multiFilePatch.getFilePatches(), 1);
      const [p] = multiFilePatch.getFilePatches();
      const buffer = multiFilePatch.getBuffer();
      assert.strictEqual(buffer.getText(), 'line-0\nline-1\n No newline at end of file');

      assertInPatch(p, buffer).hunks({
        startRow: 0,
        endRow: 2,
        header: '@@ -0,1 +0,1 @@',
        regions: [
          {kind: 'addition', string: '+line-0\n', range: [[0, 0], [0, 6]]},
          {kind: 'deletion', string: '-line-1\n', range: [[1, 0], [1, 6]]},
          {kind: 'nonewline', string: '\\ No newline at end of file', range: [[2, 0], [2, 26]]},
        ],
      });
    });
  });

  describe('with a mode change and a content diff', function() {
    it('identifies a file that was deleted and replaced by a symlink', function() {
      const multiFilePatch = buildFilePatch([
        {
          oldPath: 'the-path',
          oldMode: '000000',
          newPath: 'the-path',
          newMode: '120000',
          status: 'added',
          hunks: [
            {
              oldStartLine: 0,
              newStartLine: 0,
              oldLineCount: 0,
              newLineCount: 0,
              lines: [' the-destination'],
            },
          ],
        },
        {
          oldPath: 'the-path',
          oldMode: '100644',
          newPath: 'the-path',
          newMode: '000000',
          status: 'deleted',
          hunks: [
            {
              oldStartLine: 0,
              newStartLine: 0,
              oldLineCount: 0,
              newLineCount: 2,
              lines: ['+line-0', '+line-1'],
            },
          ],
        },
      ]);

      assert.lengthOf(multiFilePatch.getFilePatches(), 1);
      const [p] = multiFilePatch.getFilePatches();
      const buffer = multiFilePatch.getBuffer();

      assert.strictEqual(p.getOldPath(), 'the-path');
      assert.strictEqual(p.getOldMode(), '100644');
      assert.isNull(p.getOldSymlink());
      assert.strictEqual(p.getNewPath(), 'the-path');
      assert.strictEqual(p.getNewMode(), '120000');
      assert.strictEqual(p.getNewSymlink(), 'the-destination');
      assert.strictEqual(p.getStatus(), 'deleted');

      assert.strictEqual(buffer.getText(), 'line-0\nline-1');
      assertInPatch(p, buffer).hunks({
        startRow: 0,
        endRow: 1,
        header: '@@ -0,0 +0,2 @@',
        regions: [
          {kind: 'addition', string: '+line-0\n+line-1', range: [[0, 0], [1, 6]]},
        ],
      });
    });

    it('identifies a symlink that was deleted and replaced by a file', function() {
      const multiFilePatch = buildFilePatch([
        {
          oldPath: 'the-path',
          oldMode: '120000',
          newPath: 'the-path',
          newMode: '000000',
          status: 'deleted',
          hunks: [
            {
              oldStartLine: 0,
              newStartLine: 0,
              oldLineCount: 0,
              newLineCount: 0,
              lines: [' the-destination'],
            },
          ],
        },
        {
          oldPath: 'the-path',
          oldMode: '000000',
          newPath: 'the-path',
          newMode: '100644',
          status: 'added',
          hunks: [
            {
              oldStartLine: 0,
              newStartLine: 0,
              oldLineCount: 2,
              newLineCount: 0,
              lines: ['-line-0', '-line-1'],
            },
          ],
        },
      ]);

      assert.lengthOf(multiFilePatch.getFilePatches(), 1);
      const [p] = multiFilePatch.getFilePatches();
      const buffer = multiFilePatch.getBuffer();

      assert.strictEqual(p.getOldPath(), 'the-path');
      assert.strictEqual(p.getOldMode(), '120000');
      assert.strictEqual(p.getOldSymlink(), 'the-destination');
      assert.strictEqual(p.getNewPath(), 'the-path');
      assert.strictEqual(p.getNewMode(), '100644');
      assert.isNull(p.getNewSymlink());
      assert.strictEqual(p.getStatus(), 'added');

      assert.strictEqual(buffer.getText(), 'line-0\nline-1');
      assertInPatch(p, buffer).hunks({
        startRow: 0,
        endRow: 1,
        header: '@@ -0,2 +0,0 @@',
        regions: [
          {kind: 'deletion', string: '-line-0\n-line-1', range: [[0, 0], [1, 6]]},
        ],
      });
    });

    it('is indifferent to the order of the diffs', function() {
      const multiFilePatch = buildFilePatch([
        {
          oldMode: '100644',
          newPath: 'the-path',
          newMode: '000000',
          status: 'deleted',
          hunks: [
            {
              oldStartLine: 0,
              newStartLine: 0,
              oldLineCount: 0,
              newLineCount: 2,
              lines: ['+line-0', '+line-1'],
            },
          ],
        },
        {
          oldPath: 'the-path',
          oldMode: '000000',
          newPath: 'the-path',
          newMode: '120000',
          status: 'added',
          hunks: [
            {
              oldStartLine: 0,
              newStartLine: 0,
              oldLineCount: 0,
              newLineCount: 0,
              lines: [' the-destination'],
            },
          ],
        },
      ]);

      assert.lengthOf(multiFilePatch.getFilePatches(), 1);
      const [p] = multiFilePatch.getFilePatches();
      const buffer = multiFilePatch.getBuffer();

      assert.strictEqual(p.getOldPath(), 'the-path');
      assert.strictEqual(p.getOldMode(), '100644');
      assert.isNull(p.getOldSymlink());
      assert.strictEqual(p.getNewPath(), 'the-path');
      assert.strictEqual(p.getNewMode(), '120000');
      assert.strictEqual(p.getNewSymlink(), 'the-destination');
      assert.strictEqual(p.getStatus(), 'deleted');

      assert.strictEqual(buffer.getText(), 'line-0\nline-1');
      assertInPatch(p, buffer).hunks({
        startRow: 0,
        endRow: 1,
        header: '@@ -0,0 +0,2 @@',
        regions: [
          {kind: 'addition', string: '+line-0\n+line-1', range: [[0, 0], [1, 6]]},
        ],
      });
    });

    it('throws an error on an invalid mode diff status', function() {
      assert.throws(() => {
        buildFilePatch([
          {
            oldMode: '100644',
            newPath: 'the-path',
            newMode: '000000',
            status: 'deleted',
            hunks: [
              {oldStartLine: 0, newStartLine: 0, oldLineCount: 0, newLineCount: 2, lines: ['+line-0', '+line-1']},
            ],
          },
          {
            oldPath: 'the-path',
            oldMode: '000000',
            newMode: '120000',
            status: 'modified',
            hunks: [
              {oldStartLine: 0, newStartLine: 0, oldLineCount: 0, newLineCount: 0, lines: [' the-destination']},
            ],
          },
        ]);
      }, /mode change diff status: modified/);
    });
  });

  describe('with multiple diffs', function() {
    it('creates a MultiFilePatch containing each', function() {
      const mp = buildMultiFilePatch([
        {
          oldPath: 'first', oldMode: '100644', newPath: 'first', newMode: '100755', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 2, newStartLine: 1, newLineCount: 4,
              lines: [
                ' line-0',
                '+line-1',
                '+line-2',
                ' line-3',
              ],
            },
            {
              oldStartLine: 10, oldLineCount: 3, newStartLine: 12, newLineCount: 2,
              lines: [
                ' line-4',
                '-line-5',
                ' line-6',
              ],
            },
          ],
        },
        {
          oldPath: 'second', oldMode: '100644', newPath: 'second', newMode: '100644', status: 'modified',
          hunks: [
            {
              oldStartLine: 5, oldLineCount: 3, newStartLine: 5, newLineCount: 3,
              lines: [
                ' line-5',
                '+line-6',
                '-line-7',
                ' line-8',
              ],
            },
          ],
        },
        {
          oldPath: 'third', oldMode: '100755', newPath: 'third', newMode: '100755', status: 'added',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 0, newStartLine: 1, newLineCount: 3,
              lines: [
                '+line-0',
                '+line-1',
                '+line-2',
              ],
            },
          ],
        },
      ]);

      const buffer = mp.getBuffer();

      assert.lengthOf(mp.getFilePatches(), 3);

      assert.strictEqual(
        mp.getBuffer().getText(),
        'line-0\nline-1\nline-2\nline-3\nline-4\nline-5\nline-6\n' +
        'line-5\nline-6\nline-7\nline-8\n' +
        'line-0\nline-1\nline-2',
      );

      assert.strictEqual(mp.getFilePatches()[0].getOldPath(), 'first');
      assert.deepEqual(mp.getFilePatches()[0].getMarker().getRange().serialize(), [[0, 0], [6, 6]]);
      assertInFilePatch(mp.getFilePatches()[0], buffer).hunks(
        {
          startRow: 0, endRow: 3, header: '@@ -1,2 +1,4 @@', regions: [
            {kind: 'unchanged', string: ' line-0\n', range: [[0, 0], [0, 6]]},
            {kind: 'addition', string: '+line-1\n+line-2\n', range: [[1, 0], [2, 6]]},
            {kind: 'unchanged', string: ' line-3\n', range: [[3, 0], [3, 6]]},
          ],
        },
        {
          startRow: 4, endRow: 6, header: '@@ -10,3 +12,2 @@', regions: [
            {kind: 'unchanged', string: ' line-4\n', range: [[4, 0], [4, 6]]},
            {kind: 'deletion', string: '-line-5\n', range: [[5, 0], [5, 6]]},
            {kind: 'unchanged', string: ' line-6\n', range: [[6, 0], [6, 6]]},
          ],
        },
      );
      assert.strictEqual(mp.getFilePatches()[1].getOldPath(), 'second');
      assert.deepEqual(mp.getFilePatches()[1].getMarker().getRange().serialize(), [[7, 0], [10, 6]]);
      assertInFilePatch(mp.getFilePatches()[1], buffer).hunks(
        {
          startRow: 7, endRow: 10, header: '@@ -5,3 +5,3 @@', regions: [
            {kind: 'unchanged', string: ' line-5\n', range: [[7, 0], [7, 6]]},
            {kind: 'addition', string: '+line-6\n', range: [[8, 0], [8, 6]]},
            {kind: 'deletion', string: '-line-7\n', range: [[9, 0], [9, 6]]},
            {kind: 'unchanged', string: ' line-8\n', range: [[10, 0], [10, 6]]},
          ],
        },
      );
      assert.strictEqual(mp.getFilePatches()[2].getOldPath(), 'third');
      assert.deepEqual(mp.getFilePatches()[2].getMarker().getRange().serialize(), [[11, 0], [13, 6]]);
      assertInFilePatch(mp.getFilePatches()[2], buffer).hunks(
        {
          startRow: 11, endRow: 13, header: '@@ -1,0 +1,3 @@', regions: [
            {kind: 'addition', string: '+line-0\n+line-1\n+line-2', range: [[11, 0], [13, 6]]},
          ],
        },
      );
    });

    it('identifies mode and content change pairs within the patch list', function() {
      const mp = buildMultiFilePatch([
        {
          oldPath: 'first', oldMode: '100644', newPath: 'first', newMode: '100755', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 2, newStartLine: 1, newLineCount: 3,
              lines: [
                ' line-0',
                '+line-1',
                ' line-2',
              ],
            },
          ],
        },
        {
          oldPath: 'was-non-symlink', oldMode: '100644', newPath: 'was-non-symlink', newMode: '000000', status: 'deleted',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 2, newStartLine: 1, newLineCount: 0,
              lines: ['-line-0', '-line-1'],
            },
          ],
        },
        {
          oldPath: 'was-symlink', oldMode: '000000', newPath: 'was-symlink', newMode: '100755', status: 'added',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 0, newStartLine: 1, newLineCount: 2,
              lines: ['+line-0', '+line-1'],
            },
          ],
        },
        {
          oldMode: '100644', newPath: 'third', newMode: '100644', status: 'deleted',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 3, newStartLine: 1, newLineCount: 0,
              lines: ['-line-0', '-line-1', '-line-2'],
            },
          ],
        },
        {
          oldPath: 'was-symlink', oldMode: '120000', newPath: 'was-non-symlink', newMode: '000000', status: 'deleted',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 0, newStartLine: 0, newLineCount: 0,
              lines: ['-was-symlink-destination'],
            },
          ],
        },
        {
          oldPath: 'was-non-symlink', oldMode: '000000', newPath: 'was-non-symlink', newMode: '120000', status: 'added',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 0, newStartLine: 1, newLineCount: 1,
              lines: ['+was-non-symlink-destination'],
            },
          ],
        },
      ]);

      const buffer = mp.getBuffer();

      assert.lengthOf(mp.getFilePatches(), 4);
      const [fp0, fp1, fp2, fp3] = mp.getFilePatches();

      assert.strictEqual(fp0.getOldPath(), 'first');
      assertInFilePatch(fp0, buffer).hunks({
        startRow: 0, endRow: 2, header: '@@ -1,2 +1,3 @@', regions: [
          {kind: 'unchanged', string: ' line-0\n', range: [[0, 0], [0, 6]]},
          {kind: 'addition', string: '+line-1\n', range: [[1, 0], [1, 6]]},
          {kind: 'unchanged', string: ' line-2\n', range: [[2, 0], [2, 6]]},
        ],
      });

      assert.strictEqual(fp1.getOldPath(), 'was-non-symlink');
      assert.isTrue(fp1.hasTypechange());
      assert.strictEqual(fp1.getNewSymlink(), 'was-non-symlink-destination');
      assertInFilePatch(fp1, buffer).hunks({
        startRow: 3, endRow: 4, header: '@@ -1,2 +1,0 @@', regions: [
          {kind: 'deletion', string: '-line-0\n-line-1\n', range: [[3, 0], [4, 6]]},
        ],
      });

      assert.strictEqual(fp2.getOldPath(), 'was-symlink');
      assert.isTrue(fp2.hasTypechange());
      assert.strictEqual(fp2.getOldSymlink(), 'was-symlink-destination');
      assertInFilePatch(fp2, buffer).hunks({
        startRow: 5, endRow: 6, header: '@@ -1,0 +1,2 @@', regions: [
          {kind: 'addition', string: '+line-0\n+line-1\n', range: [[5, 0], [6, 6]]},
        ],
      });

      assert.strictEqual(fp3.getNewPath(), 'third');
      assertInFilePatch(fp3, buffer).hunks({
        startRow: 7, endRow: 9, header: '@@ -1,3 +1,0 @@', regions: [
          {kind: 'deletion', string: '-line-0\n-line-1\n-line-2', range: [[7, 0], [9, 6]]},
        ],
      });
    });

    it('sets the correct marker range for diffs with no hunks', function() {
      const mp = buildMultiFilePatch([
        {
          oldPath: 'first', oldMode: '100644', newPath: 'first', newMode: '100755', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 2, newStartLine: 1, newLineCount: 4,
              lines: [
                ' line-0',
                '+line-1',
                '+line-2',
                ' line-3',
              ],
            },
            {
              oldStartLine: 10, oldLineCount: 3, newStartLine: 12, newLineCount: 2,
              lines: [
                ' line-4',
                '-line-5',
                ' line-6',
              ],
            },
          ],
        },
        {
          oldPath: 'second', oldMode: '100644', newPath: 'second', newMode: '100755', status: 'modified',
          hunks: [],
        },
        {
          oldPath: 'third', oldMode: '100755', newPath: 'third', newMode: '100755', status: 'added',
          hunks: [
            {
              oldStartLine: 5, oldLineCount: 3, newStartLine: 5, newLineCount: 3,
              lines: [
                ' line-5',
                '+line-6',
                '-line-7',
                ' line-8',
              ],
            },
          ],
        },
      ]);

      assert.strictEqual(mp.getFilePatches()[0].getOldPath(), 'first');
      assert.deepEqual(mp.getFilePatches()[0].getMarker().getRange().serialize(), [[0, 0], [6, 6]]);

      assert.strictEqual(mp.getFilePatches()[1].getOldPath(), 'second');
      assert.deepEqual(mp.getFilePatches()[1].getHunks(), []);
      assert.deepEqual(mp.getFilePatches()[1].getMarker().getRange().serialize(), [[7, 0], [7, 0]]);

      assert.strictEqual(mp.getFilePatches()[2].getOldPath(), 'third');
      assert.deepEqual(mp.getFilePatches()[2].getMarker().getRange().serialize(), [[7, 0], [10, 6]]);
    });
  });

  describe('with a large diff', function() {
    it('creates a HiddenPatch when the diff is "too large"', function() {
      const mfp = buildMultiFilePatch([
        {
          oldPath: 'first', oldMode: '100644', newPath: 'first', newMode: '100755', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 3, newStartLine: 1, newLineCount: 3,
              lines: [' line-0', '+line-1', '-line-2', ' line-3'],
            },
          ],
        },
        {
          oldPath: 'second', oldMode: '100644', newPath: 'second', newMode: '100755', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 1, newStartLine: 1, newLineCount: 2,
              lines: [' line-4', '+line-5'],
            },
          ],
        },
      ], {largeDiffThreshold: 3});

      assert.lengthOf(mfp.getFilePatches(), 2);
      const [fp0, fp1] = mfp.getFilePatches();

      assert.strictEqual(fp0.getRenderStatus(), DEFERRED);
      assert.strictEqual(fp0.getOldPath(), 'first');
      assert.strictEqual(fp0.getNewPath(), 'first');
      assert.deepEqual(fp0.getStartRange().serialize(), [[0, 0], [0, 0]]);
      assertInFilePatch(fp0).hunks();

      assert.strictEqual(fp1.getRenderStatus(), EXPANDED);
      assert.strictEqual(fp1.getOldPath(), 'second');
      assert.strictEqual(fp1.getNewPath(), 'second');
      assert.deepEqual(fp1.getMarker().getRange().serialize(), [[0, 0], [1, 6]]);
      assertInFilePatch(fp1, mfp.getBuffer()).hunks(
        {
          startRow: 0, endRow: 1, header: '@@ -1,1 +1,2 @@', regions: [
            {kind: 'unchanged', string: ' line-4\n', range: [[0, 0], [0, 6]]},
            {kind: 'addition', string: '+line-5', range: [[1, 0], [1, 6]]},
          ],
        },
      );
    });

    it('creates a HiddenPatch from a paired symlink diff', function() {
      const {raw} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.status('deleted');
          fp.setOldFile(f => f.path('big').symlinkTo('/somewhere'));
          fp.nullNewFile();
        })
        .addFilePatch(fp => {
          fp.status('added');
          fp.nullOldFile();
          fp.setNewFile(f => f.path('big'));
          fp.addHunk(h => h.oldRow(1).added('0', '1', '2', '3', '4', '5'));
        })
        .addFilePatch(fp => {
          fp.status('deleted');
          fp.setOldFile(f => f.path('small'));
          fp.nullNewFile();
          fp.addHunk(h => h.oldRow(1).deleted('0', '1'));
        })
        .addFilePatch(fp => {
          fp.status('added');
          fp.nullOldFile();
          fp.setNewFile(f => f.path('small').symlinkTo('/elsewhere'));
        })
        .build();
      const mfp = buildMultiFilePatch(raw, {largeDiffThreshold: 3});

      assert.lengthOf(mfp.getFilePatches(), 2);
      const [fp0, fp1] = mfp.getFilePatches();

      assert.strictEqual(fp0.getRenderStatus(), DEFERRED);
      assert.strictEqual(fp0.getOldPath(), 'big');
      assert.strictEqual(fp0.getNewPath(), 'big');
      assert.deepEqual(fp0.getMarker().getRange().serialize(), [[0, 0], [0, 0]]);
      assertInFilePatch(fp0, mfp.getBuffer()).hunks();

      assert.strictEqual(fp1.getRenderStatus(), EXPANDED);
      assert.strictEqual(fp1.getOldPath(), 'small');
      assert.strictEqual(fp1.getNewPath(), 'small');
      assert.deepEqual(fp1.getMarker().getRange().serialize(), [[0, 0], [1, 1]]);
      assertInFilePatch(fp1, mfp.getBuffer()).hunks(
        {
          startRow: 0, endRow: 1, header: '@@ -1,2 +1,0 @@', regions: [
            {kind: 'deletion', string: '-0\n-1', range: [[0, 0], [1, 1]]},
          ],
        },
      );
    });

    it('re-parses a HiddenPatch as a Patch', function() {
      const mfp = buildMultiFilePatch([
        {
          oldPath: 'first', oldMode: '100644', newPath: 'first', newMode: '100644', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 3, newStartLine: 1, newLineCount: 3,
              lines: [' line-0', '+line-1', '-line-2', ' line-3'],
            },
          ],
        },
      ], {largeDiffThreshold: 3});

      assert.lengthOf(mfp.getFilePatches(), 1);
      const [fp] = mfp.getFilePatches();

      assert.strictEqual(fp.getRenderStatus(), DEFERRED);
      assert.strictEqual(fp.getOldPath(), 'first');
      assert.strictEqual(fp.getNewPath(), 'first');
      assert.deepEqual(fp.getStartRange().serialize(), [[0, 0], [0, 0]]);
      assertInFilePatch(fp).hunks();

      mfp.expandFilePatch(fp);

      assert.strictEqual(fp.getRenderStatus(), EXPANDED);
      assert.deepEqual(fp.getMarker().getRange().serialize(), [[0, 0], [3, 6]]);
      assertInFilePatch(fp, mfp.getBuffer()).hunks(
        {
          startRow: 0, endRow: 3, header: '@@ -1,3 +1,3 @@', regions: [
            {kind: 'unchanged', string: ' line-0\n', range: [[0, 0], [0, 6]]},
            {kind: 'addition', string: '+line-1\n', range: [[1, 0], [1, 6]]},
            {kind: 'deletion', string: '-line-2\n', range: [[2, 0], [2, 6]]},
            {kind: 'unchanged', string: ' line-3', range: [[3, 0], [3, 6]]},
          ],
        },
      );
    });

    it('re-parses a HiddenPatch from a paired symlink diff as a Patch', function() {
      const {raw} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.status('deleted');
          fp.setOldFile(f => f.path('big').symlinkTo('/somewhere'));
          fp.nullNewFile();
        })
        .addFilePatch(fp => {
          fp.status('added');
          fp.nullOldFile();
          fp.setNewFile(f => f.path('big'));
          fp.addHunk(h => h.oldRow(1).added('0', '1', '2', '3', '4', '5'));
        })
        .build();
      const mfp = buildMultiFilePatch(raw, {largeDiffThreshold: 3});

      assert.lengthOf(mfp.getFilePatches(), 1);
      const [fp] = mfp.getFilePatches();

      assert.strictEqual(fp.getRenderStatus(), DEFERRED);
      assert.strictEqual(fp.getOldPath(), 'big');
      assert.strictEqual(fp.getNewPath(), 'big');
      assert.deepEqual(fp.getStartRange().serialize(), [[0, 0], [0, 0]]);
      assertInFilePatch(fp).hunks();

      mfp.expandFilePatch(fp);

      assert.strictEqual(fp.getRenderStatus(), EXPANDED);
      assert.deepEqual(fp.getMarker().getRange().serialize(), [[0, 0], [5, 1]]);
      assertInFilePatch(fp, mfp.getBuffer()).hunks(
        {
          startRow: 0, endRow: 5, header: '@@ -1,0 +1,6 @@', regions: [
            {kind: 'addition', string: '+0\n+1\n+2\n+3\n+4\n+5', range: [[0, 0], [5, 1]]},
          ],
        },
      );
    });

    it('does not interfere with markers from surrounding visible patches when expanded', function() {
      const mfp = buildMultiFilePatch([
        {
          oldPath: 'first', oldMode: '100644', newPath: 'first', newMode: '100644', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 3, newStartLine: 1, newLineCount: 3,
              lines: [' line-0', '+line-1', '-line-2', ' line-3'],
            },
          ],
        },
        {
          oldPath: 'big', oldMode: '100644', newPath: 'big', newMode: '100644', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 3, newStartLine: 1, newLineCount: 4,
              lines: [' line-0', '+line-1', '+line-2', '-line-3', ' line-4'],
            },
          ],
        },
        {
          oldPath: 'last', oldMode: '100644', newPath: 'last', newMode: '100644', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 3, newStartLine: 1, newLineCount: 3,
              lines: [' line-0', '+line-1', '-line-2', ' line-3'],
            },
          ],
        },
      ], {largeDiffThreshold: 4});

      assert.lengthOf(mfp.getFilePatches(), 3);
      const [fp0, fp1, fp2] = mfp.getFilePatches();
      assert.strictEqual(fp0.getRenderStatus(), EXPANDED);
      assertInFilePatch(fp0, mfp.getBuffer()).hunks(
        {
          startRow: 0, endRow: 3, header: '@@ -1,3 +1,3 @@', regions: [
            {kind: 'unchanged', string: ' line-0\n', range: [[0, 0], [0, 6]]},
            {kind: 'addition', string: '+line-1\n', range: [[1, 0], [1, 6]]},
            {kind: 'deletion', string: '-line-2\n', range: [[2, 0], [2, 6]]},
            {kind: 'unchanged', string: ' line-3\n', range: [[3, 0], [3, 6]]},
          ],
        },
      );

      assert.strictEqual(fp1.getRenderStatus(), DEFERRED);
      assert.deepEqual(fp1.getPatch().getMarker().getRange().serialize(), [[4, 0], [4, 0]]);
      assertInFilePatch(fp1, mfp.getBuffer()).hunks();

      assert.strictEqual(fp2.getRenderStatus(), EXPANDED);
      assertInFilePatch(fp2, mfp.getBuffer()).hunks(
        {
          startRow: 4, endRow: 7, header: '@@ -1,3 +1,3 @@', regions: [
            {kind: 'unchanged', string: ' line-0\n', range: [[4, 0], [4, 6]]},
            {kind: 'addition', string: '+line-1\n', range: [[5, 0], [5, 6]]},
            {kind: 'deletion', string: '-line-2\n', range: [[6, 0], [6, 6]]},
            {kind: 'unchanged', string: ' line-3', range: [[7, 0], [7, 6]]},
          ],
        },
      );

      mfp.expandFilePatch(fp1);

      assert.strictEqual(fp0.getRenderStatus(), EXPANDED);
      assertInFilePatch(fp0, mfp.getBuffer()).hunks(
        {
          startRow: 0, endRow: 3, header: '@@ -1,3 +1,3 @@', regions: [
            {kind: 'unchanged', string: ' line-0\n', range: [[0, 0], [0, 6]]},
            {kind: 'addition', string: '+line-1\n', range: [[1, 0], [1, 6]]},
            {kind: 'deletion', string: '-line-2\n', range: [[2, 0], [2, 6]]},
            {kind: 'unchanged', string: ' line-3\n', range: [[3, 0], [3, 6]]},
          ],
        },
      );

      assert.strictEqual(fp1.getRenderStatus(), EXPANDED);
      assertInFilePatch(fp1, mfp.getBuffer()).hunks(
        {
          startRow: 4, endRow: 8, header: '@@ -1,3 +1,4 @@', regions: [
            {kind: 'unchanged', string: ' line-0\n', range: [[4, 0], [4, 6]]},
            {kind: 'addition', string: '+line-1\n+line-2\n', range: [[5, 0], [6, 6]]},
            {kind: 'deletion', string: '-line-3\n', range: [[7, 0], [7, 6]]},
            {kind: 'unchanged', string: ' line-4\n', range: [[8, 0], [8, 6]]},
          ],
        },
      );

      assert.strictEqual(fp2.getRenderStatus(), EXPANDED);
      assertInFilePatch(fp2, mfp.getBuffer()).hunks(
        {
          startRow: 9, endRow: 12, header: '@@ -1,3 +1,3 @@', regions: [
            {kind: 'unchanged', string: ' line-0\n', range: [[9, 0], [9, 6]]},
            {kind: 'addition', string: '+line-1\n', range: [[10, 0], [10, 6]]},
            {kind: 'deletion', string: '-line-2\n', range: [[11, 0], [11, 6]]},
            {kind: 'unchanged', string: ' line-3', range: [[12, 0], [12, 6]]},
          ],
        },
      );
    });

    it('does not interfere with markers from surrounding non-visible patches when expanded', function() {
      const mfp = buildMultiFilePatch([
        {
          oldPath: 'first', oldMode: '100644', newPath: 'first', newMode: '100644', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 3, newStartLine: 1, newLineCount: 3,
              lines: [' line-0', '+line-1', '-line-2', ' line-3'],
            },
          ],
        },
        {
          oldPath: 'second', oldMode: '100644', newPath: 'second', newMode: '100644', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 3, newStartLine: 1, newLineCount: 3,
              lines: [' line-0', '+line-1', '-line-2', ' line-3'],
            },
          ],
        },
        {
          oldPath: 'third', oldMode: '100644', newPath: 'third', newMode: '100644', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 3, newStartLine: 1, newLineCount: 3,
              lines: [' line-0', '+line-1', '-line-2', ' line-3'],
            },
          ],
        },
      ], {largeDiffThreshold: 3});

      assert.lengthOf(mfp.getFilePatches(), 3);
      const [fp0, fp1, fp2] = mfp.getFilePatches();
      assert.deepEqual(fp0.getMarker().getRange().serialize(), [[0, 0], [0, 0]]);
      assert.deepEqual(fp1.getMarker().getRange().serialize(), [[0, 0], [0, 0]]);
      assert.deepEqual(fp2.getMarker().getRange().serialize(), [[0, 0], [0, 0]]);

      mfp.expandFilePatch(fp1);

      assert.deepEqual(fp0.getMarker().getRange().serialize(), [[0, 0], [0, 0]]);
      assert.deepEqual(fp1.getMarker().getRange().serialize(), [[0, 0], [3, 6]]);
      assert.deepEqual(fp2.getMarker().getRange().serialize(), [[3, 6], [3, 6]]);
    });

    it('does not create a HiddenPatch when the patch has been explicitly expanded', function() {
      const mfp = buildMultiFilePatch([
        {
          oldPath: 'big/file.txt', oldMode: '100644', newPath: 'big/file.txt', newMode: '100755', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 3, newStartLine: 1, newLineCount: 3,
              lines: [' line-0', '+line-1', '-line-2', ' line-3'],
            },
          ],
        },
      ], {largeDiffThreshold: 3, renderStatusOverrides: {'big/file.txt': EXPANDED}});

      assert.lengthOf(mfp.getFilePatches(), 1);
      const [fp] = mfp.getFilePatches();

      assert.strictEqual(fp.getRenderStatus(), EXPANDED);
      assert.strictEqual(fp.getOldPath(), 'big/file.txt');
      assert.strictEqual(fp.getNewPath(), 'big/file.txt');
      assert.deepEqual(fp.getMarker().getRange().serialize(), [[0, 0], [3, 6]]);
      assertInFilePatch(fp, mfp.getBuffer()).hunks(
        {
          startRow: 0, endRow: 3, header: '@@ -1,3 +1,3 @@', regions: [
            {kind: 'unchanged', string: ' line-0\n', range: [[0, 0], [0, 6]]},
            {kind: 'addition', string: '+line-1\n', range: [[1, 0], [1, 6]]},
            {kind: 'deletion', string: '-line-2\n', range: [[2, 0], [2, 6]]},
            {kind: 'unchanged', string: ' line-3', range: [[3, 0], [3, 6]]},
          ],
        },
      );
    });
  });

  describe('with a removed diff', function() {
    it('creates a HiddenPatch when the diff has been removed', function() {
      const mfp = buildMultiFilePatch([
        {
          oldPath: 'only', oldMode: '100644', newPath: 'only', newMode: '100755', status: 'modified',
          hunks: [
            {
              oldStartLine: 1, oldLineCount: 1, newStartLine: 1, newLineCount: 2,
              lines: [' line-4', '+line-5'],
            },
          ],
        },
      ], {removed: new Set(['removed'])});

      assert.lengthOf(mfp.getFilePatches(), 2);
      const [fp0, fp1] = mfp.getFilePatches();

      assert.strictEqual(fp0.getRenderStatus(), EXPANDED);
      assert.strictEqual(fp0.getOldPath(), 'only');
      assert.strictEqual(fp0.getNewPath(), 'only');
      assert.deepEqual(fp0.getMarker().getRange().serialize(), [[0, 0], [1, 6]]);
      assertInFilePatch(fp0, mfp.getBuffer()).hunks(
        {
          startRow: 0, endRow: 1, header: '@@ -1,1 +1,2 @@', regions: [
            {kind: 'unchanged', string: ' line-4\n', range: [[0, 0], [0, 6]]},
            {kind: 'addition', string: '+line-5', range: [[1, 0], [1, 6]]},
          ],
        },
      );

      assert.strictEqual(fp1.getRenderStatus(), REMOVED);
      assert.strictEqual(fp1.getOldPath(), 'removed');
      assert.strictEqual(fp1.getNewPath(), 'removed');
      assert.deepEqual(fp1.getMarker().getRange().serialize(), [[1, 6], [1, 6]]);
      assertInFilePatch(fp1, mfp.getBuffer()).hunks();
    });
  });

  it('throws an error with an unexpected number of diffs', function() {
    assert.throws(() => buildFilePatch([1, 2, 3]), /Unexpected number of diffs: 3/);
  });
});
