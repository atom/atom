import {TextBuffer} from 'atom';

import FilePatch from '../../../lib/models/patch/file-patch';
import File, {nullFile} from '../../../lib/models/patch/file';
import Patch, {DEFERRED, COLLAPSED, EXPANDED} from '../../../lib/models/patch/patch';
import PatchBuffer from '../../../lib/models/patch/patch-buffer';
import Hunk from '../../../lib/models/patch/hunk';
import {Unchanged, Addition, Deletion, NoNewline} from '../../../lib/models/patch/region';
import {assertInFilePatch} from '../../helpers';
import {multiFilePatchBuilder} from '../../builder/patch';

describe('FilePatch', function() {
  it('delegates methods to its files and patch', function() {
    const buffer = new TextBuffer({text: '0000\n0001\n0002\n'});
    const layers = buildLayers(buffer);
    const hunks = [
      new Hunk({
        oldStartRow: 2, oldRowCount: 1, newStartRow: 2, newRowCount: 3,
        marker: markRange(layers.hunk, 0, 2),
        regions: [
          new Unchanged(markRange(layers.unchanged, 0)),
          new Addition(markRange(layers.addition, 1, 2)),
        ],
      }),
    ];
    const marker = markRange(layers.patch, 0, 2);
    const patch = new Patch({status: 'modified', hunks, marker});
    const oldFile = new File({path: 'a.txt', mode: '120000', symlink: 'dest.txt'});
    const newFile = new File({path: 'b.txt', mode: '100755'});

    const filePatch = new FilePatch(oldFile, newFile, patch);

    assert.isTrue(filePatch.isPresent());

    assert.strictEqual(filePatch.getOldPath(), 'a.txt');
    assert.strictEqual(filePatch.getOldMode(), '120000');
    assert.strictEqual(filePatch.getOldSymlink(), 'dest.txt');

    assert.strictEqual(filePatch.getNewPath(), 'b.txt');
    assert.strictEqual(filePatch.getNewMode(), '100755');
    assert.isUndefined(filePatch.getNewSymlink());

    assert.strictEqual(filePatch.getMarker(), marker);
    assert.strictEqual(filePatch.getMaxLineNumberWidth(), 1);

    assert.deepEqual(filePatch.getFirstChangeRange().serialize(), [[1, 0], [1, Infinity]]);
    assert.isTrue(filePatch.containsRow(0));
    assert.isFalse(filePatch.containsRow(3));

    const nMarker = markRange(layers.patch, 0, 2);
    filePatch.updateMarkers(new Map([[marker, nMarker]]));
    assert.strictEqual(filePatch.getMarker(), nMarker);
  });

  it('accesses a file path from either side of the patch', function() {
    const oldFile = new File({path: 'old-file.txt', mode: '100644'});
    const newFile = new File({path: 'new-file.txt', mode: '100644'});
    const buffer = new TextBuffer();
    const layers = buildLayers(buffer);
    const patch = new Patch({status: 'modified', hunks: [], buffer, layers});

    assert.strictEqual(new FilePatch(oldFile, newFile, patch).getPath(), 'old-file.txt');
    assert.strictEqual(new FilePatch(oldFile, nullFile, patch).getPath(), 'old-file.txt');
    assert.strictEqual(new FilePatch(nullFile, newFile, patch).getPath(), 'new-file.txt');
    assert.isNull(new FilePatch(nullFile, nullFile, patch).getPath());
  });

  it('returns the starting range of the patch', function() {
    const buffer = new TextBuffer({text: '0000\n0001\n0002\n0003\n'});
    const layers = buildLayers(buffer);
    const hunks = [
      new Hunk({
        oldStartRow: 2, oldRowCount: 1, newStartRow: 2, newRowCount: 3,
        marker: markRange(layers.hunk, 1, 3),
        regions: [
          new Unchanged(markRange(layers.unchanged, 1)),
          new Addition(markRange(layers.addition, 2, 3)),
        ],
      }),
    ];
    const marker = markRange(layers.patch, 1, 3);
    const patch = new Patch({status: 'modified', hunks, buffer, layers, marker});
    const oldFile = new File({path: 'a.txt', mode: '100644'});
    const newFile = new File({path: 'a.txt', mode: '100644'});

    const filePatch = new FilePatch(oldFile, newFile, patch);

    assert.deepEqual(filePatch.getStartRange().serialize(), [[1, 0], [1, 0]]);
  });

  describe('file-level change detection', function() {
    let emptyPatch;

    beforeEach(function() {
      const buffer = new TextBuffer();
      const layers = buildLayers(buffer);
      emptyPatch = new Patch({status: 'modified', hunks: [], buffer, layers});
    });

    it('detects changes in executable mode', function() {
      const executableFile = new File({path: 'file.txt', mode: '100755'});
      const nonExecutableFile = new File({path: 'file.txt', mode: '100644'});

      assert.isTrue(new FilePatch(nonExecutableFile, executableFile, emptyPatch).didChangeExecutableMode());
      assert.isTrue(new FilePatch(executableFile, nonExecutableFile, emptyPatch).didChangeExecutableMode());
      assert.isFalse(new FilePatch(nonExecutableFile, nonExecutableFile, emptyPatch).didChangeExecutableMode());
      assert.isFalse(new FilePatch(executableFile, executableFile, emptyPatch).didChangeExecutableMode());
      assert.isFalse(new FilePatch(nullFile, nonExecutableFile).didChangeExecutableMode());
      assert.isFalse(new FilePatch(nullFile, executableFile).didChangeExecutableMode());
      assert.isFalse(new FilePatch(nonExecutableFile, nullFile).didChangeExecutableMode());
      assert.isFalse(new FilePatch(executableFile, nullFile).didChangeExecutableMode());
    });

    it('detects changes in symlink mode', function() {
      const symlinkFile = new File({path: 'file.txt', mode: '120000', symlink: 'dest.txt'});
      const nonSymlinkFile = new File({path: 'file.txt', mode: '100644'});

      assert.isTrue(new FilePatch(nonSymlinkFile, symlinkFile, emptyPatch).hasTypechange());
      assert.isTrue(new FilePatch(symlinkFile, nonSymlinkFile, emptyPatch).hasTypechange());
      assert.isFalse(new FilePatch(nonSymlinkFile, nonSymlinkFile, emptyPatch).hasTypechange());
      assert.isFalse(new FilePatch(symlinkFile, symlinkFile, emptyPatch).hasTypechange());
      assert.isFalse(new FilePatch(nullFile, nonSymlinkFile).hasTypechange());
      assert.isFalse(new FilePatch(nullFile, symlinkFile).hasTypechange());
      assert.isFalse(new FilePatch(nonSymlinkFile, nullFile).hasTypechange());
      assert.isFalse(new FilePatch(symlinkFile, nullFile).hasTypechange());
    });

    it('detects when either file has a symlink destination', function() {
      const symlinkFile = new File({path: 'file.txt', mode: '120000', symlink: 'dest.txt'});
      const nonSymlinkFile = new File({path: 'file.txt', mode: '100644'});

      assert.isTrue(new FilePatch(nonSymlinkFile, symlinkFile, emptyPatch).hasSymlink());
      assert.isTrue(new FilePatch(symlinkFile, nonSymlinkFile, emptyPatch).hasSymlink());
      assert.isFalse(new FilePatch(nonSymlinkFile, nonSymlinkFile, emptyPatch).hasSymlink());
      assert.isTrue(new FilePatch(symlinkFile, symlinkFile, emptyPatch).hasSymlink());
      assert.isFalse(new FilePatch(nullFile, nonSymlinkFile).hasSymlink());
      assert.isTrue(new FilePatch(nullFile, symlinkFile).hasSymlink());
      assert.isFalse(new FilePatch(nonSymlinkFile, nullFile).hasSymlink());
      assert.isTrue(new FilePatch(symlinkFile, nullFile).hasSymlink());
    });
  });

  it('clones itself and overrides select properties', function() {
    const file00 = new File({path: 'file-00.txt', mode: '100644'});
    const file01 = new File({path: 'file-01.txt', mode: '100644'});
    const file10 = new File({path: 'file-10.txt', mode: '100644'});
    const file11 = new File({path: 'file-11.txt', mode: '100644'});
    const buffer0 = new TextBuffer({text: '0'});
    const layers0 = buildLayers(buffer0);
    const patch0 = new Patch({status: 'modified', hunks: [], buffer: buffer0, layers: layers0});
    const buffer1 = new TextBuffer({text: '1'});
    const layers1 = buildLayers(buffer1);
    const patch1 = new Patch({status: 'modified', hunks: [], buffer: buffer1, layers: layers1});

    const original = new FilePatch(file00, file01, patch0);

    const clone0 = original.clone();
    assert.notStrictEqual(clone0, original);
    assert.strictEqual(clone0.getOldFile(), file00);
    assert.strictEqual(clone0.getNewFile(), file01);
    assert.strictEqual(clone0.getPatch(), patch0);

    const clone1 = original.clone({oldFile: file10});
    assert.notStrictEqual(clone1, original);
    assert.strictEqual(clone1.getOldFile(), file10);
    assert.strictEqual(clone1.getNewFile(), file01);
    assert.strictEqual(clone1.getPatch(), patch0);

    const clone2 = original.clone({newFile: file11});
    assert.notStrictEqual(clone2, original);
    assert.strictEqual(clone2.getOldFile(), file00);
    assert.strictEqual(clone2.getNewFile(), file11);
    assert.strictEqual(clone2.getPatch(), patch0);

    const clone3 = original.clone({patch: patch1});
    assert.notStrictEqual(clone3, original);
    assert.strictEqual(clone3.getOldFile(), file00);
    assert.strictEqual(clone3.getNewFile(), file01);
    assert.strictEqual(clone3.getPatch(), patch1);
  });

  describe('buildStagePatchForLines()', function() {
    let stagedPatchBuffer;

    beforeEach(function() {
      stagedPatchBuffer = new PatchBuffer();
    });

    it('returns a new FilePatch that applies only the selected lines', function() {
      const buffer = new TextBuffer({text: '0000\n0001\n0002\n0003\n0004\n'});
      const layers = buildLayers(buffer);
      const hunks = [
        new Hunk({
          oldStartRow: 5, oldRowCount: 3, newStartRow: 5, newRowCount: 4,
          marker: markRange(layers.hunk, 0, 4),
          regions: [
            new Unchanged(markRange(layers.unchanged, 0)),
            new Addition(markRange(layers.addition, 1, 2)),
            new Deletion(markRange(layers.deletion, 3)),
            new Unchanged(markRange(layers.unchanged, 4)),
          ],
        }),
      ];
      const marker = markRange(layers.patch, 0, 4);
      const patch = new Patch({status: 'modified', hunks, marker});
      const oldFile = new File({path: 'file.txt', mode: '100644'});
      const newFile = new File({path: 'file.txt', mode: '100644'});
      const filePatch = new FilePatch(oldFile, newFile, patch);

      const stagedPatch = filePatch.buildStagePatchForLines(buffer, stagedPatchBuffer, new Set([1, 3]));
      assert.strictEqual(stagedPatch.getStatus(), 'modified');
      assert.strictEqual(stagedPatch.getOldFile(), oldFile);
      assert.strictEqual(stagedPatch.getNewFile(), newFile);
      assert.strictEqual(stagedPatchBuffer.buffer.getText(), '0000\n0001\n0003\n0004\n');
      assertInFilePatch(stagedPatch, stagedPatchBuffer.buffer).hunks(
        {
          startRow: 0,
          endRow: 3,
          header: '@@ -5,3 +5,3 @@',
          regions: [
            {kind: 'unchanged', string: ' 0000\n', range: [[0, 0], [0, 4]]},
            {kind: 'addition', string: '+0001\n', range: [[1, 0], [1, 4]]},
            {kind: 'deletion', string: '-0003\n', range: [[2, 0], [2, 4]]},
            {kind: 'unchanged', string: ' 0004\n', range: [[3, 0], [3, 4]]},
          ],
        },
      );
    });

    describe('staging lines from deleted files', function() {
      let buffer;
      let oldFile, deletionPatch;

      beforeEach(function() {
        buffer = new TextBuffer({text: '0000\n0001\n0002\n'});
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
        oldFile = new File({path: 'file.txt', mode: '100644'});
        deletionPatch = new FilePatch(oldFile, nullFile, patch);
      });

      it('handles staging part of the file', function() {
        const stagedPatch = deletionPatch.buildStagePatchForLines(buffer, stagedPatchBuffer, new Set([1, 2]));

        assert.strictEqual(stagedPatch.getStatus(), 'modified');
        assert.strictEqual(stagedPatch.getOldFile(), oldFile);
        assert.strictEqual(stagedPatch.getNewFile(), oldFile);
        assert.strictEqual(stagedPatchBuffer.buffer.getText(), '0000\n0001\n0002\n');
        assertInFilePatch(stagedPatch, stagedPatchBuffer.buffer).hunks(
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

      it('handles staging all lines, leaving nothing unstaged', function() {
        const stagedPatch = deletionPatch.buildStagePatchForLines(buffer, stagedPatchBuffer, new Set([0, 1, 2]));
        assert.strictEqual(stagedPatch.getStatus(), 'deleted');
        assert.strictEqual(stagedPatch.getOldFile(), oldFile);
        assert.isFalse(stagedPatch.getNewFile().isPresent());
        assert.strictEqual(stagedPatchBuffer.buffer.getText(), '0000\n0001\n0002\n');
        assertInFilePatch(stagedPatch, stagedPatchBuffer.buffer).hunks(
          {
            startRow: 0,
            endRow: 2,
            header: '@@ -1,3 +1,0 @@',
            regions: [
              {kind: 'deletion', string: '-0000\n-0001\n-0002\n', range: [[0, 0], [2, 4]]},
            ],
          },
        );
      });

      it('unsets the newFile when a symlink is created where a file was deleted', function() {
        const nBuffer = new TextBuffer({text: '0000\n0001\n0002\n'});
        const layers = buildLayers(nBuffer);
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
        oldFile = new File({path: 'file.txt', mode: '100644'});
        const newFile = new File({path: 'file.txt', mode: '120000'});
        const replacePatch = new FilePatch(oldFile, newFile, patch);

        const stagedPatch = replacePatch.buildStagePatchForLines(nBuffer, stagedPatchBuffer, new Set([0, 1, 2]));
        assert.strictEqual(stagedPatch.getOldFile(), oldFile);
        assert.isFalse(stagedPatch.getNewFile().isPresent());
      });
    });
  });

  describe('getUnstagePatchForLines()', function() {
    let unstagePatchBuffer;

    beforeEach(function() {
      unstagePatchBuffer = new PatchBuffer();
    });

    it('returns a new FilePatch that unstages only the specified lines', function() {
      const buffer = new TextBuffer({text: '0000\n0001\n0002\n0003\n0004\n'});
      const layers = buildLayers(buffer);
      const hunks = [
        new Hunk({
          oldStartRow: 5, oldRowCount: 3, newStartRow: 5, newRowCount: 4,
          marker: markRange(layers.hunk, 0, 4),
          regions: [
            new Unchanged(markRange(layers.unchanged, 0)),
            new Addition(markRange(layers.addition, 1, 2)),
            new Deletion(markRange(layers.deletion, 3)),
            new Unchanged(markRange(layers.unchanged, 4)),
          ],
        }),
      ];
      const marker = markRange(layers.patch, 0, 4);
      const patch = new Patch({status: 'modified', hunks, marker});
      const oldFile = new File({path: 'file.txt', mode: '100644'});
      const newFile = new File({path: 'file.txt', mode: '100644'});
      const filePatch = new FilePatch(oldFile, newFile, patch);

      const unstagedPatch = filePatch.buildUnstagePatchForLines(buffer, unstagePatchBuffer, new Set([1, 3]));
      assert.strictEqual(unstagedPatch.getStatus(), 'modified');
      assert.strictEqual(unstagedPatch.getOldFile(), newFile);
      assert.strictEqual(unstagedPatch.getNewFile(), newFile);
      assert.strictEqual(unstagePatchBuffer.buffer.getText(), '0000\n0001\n0002\n0003\n0004\n');
      assertInFilePatch(unstagedPatch, unstagePatchBuffer.buffer).hunks(
        {
          startRow: 0,
          endRow: 4,
          header: '@@ -5,4 +5,4 @@',
          regions: [
            {kind: 'unchanged', string: ' 0000\n', range: [[0, 0], [0, 4]]},
            {kind: 'deletion', string: '-0001\n', range: [[1, 0], [1, 4]]},
            {kind: 'unchanged', string: ' 0002\n', range: [[2, 0], [2, 4]]},
            {kind: 'addition', string: '+0003\n', range: [[3, 0], [3, 4]]},
            {kind: 'unchanged', string: ' 0004\n', range: [[4, 0], [4, 4]]},
          ],
        },
      );
    });

    describe('unstaging lines from an added file', function() {
      let buffer;
      let newFile, addedPatch, addedFilePatch;

      beforeEach(function() {
        buffer = new TextBuffer({text: '0000\n0001\n0002\n'});
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
        newFile = new File({path: 'file.txt', mode: '100644'});
        addedPatch = new Patch({status: 'added', hunks, marker});
        addedFilePatch = new FilePatch(nullFile, newFile, addedPatch);
      });

      it('handles unstaging part of the file', function() {
        const unstagePatch = addedFilePatch.buildUnstagePatchForLines(buffer, unstagePatchBuffer, new Set([2]));
        assert.strictEqual(unstagePatch.getStatus(), 'modified');
        assert.strictEqual(unstagePatch.getOldFile(), newFile);
        assert.strictEqual(unstagePatch.getNewFile(), newFile);
        assertInFilePatch(unstagePatch, unstagePatchBuffer.buffer).hunks(
          {
            startRow: 0,
            endRow: 2,
            header: '@@ -1,3 +1,2 @@',
            regions: [
              {kind: 'unchanged', string: ' 0000\n 0001\n', range: [[0, 0], [1, 4]]},
              {kind: 'deletion', string: '-0002\n', range: [[2, 0], [2, 4]]},
            ],
          },
        );
      });

      it('handles unstaging all lines, leaving nothing staged', function() {
        const unstagePatch = addedFilePatch.buildUnstagePatchForLines(buffer, unstagePatchBuffer, new Set([0, 1, 2]));
        assert.strictEqual(unstagePatch.getStatus(), 'deleted');
        assert.strictEqual(unstagePatch.getOldFile(), newFile);
        assert.isFalse(unstagePatch.getNewFile().isPresent());
        assertInFilePatch(unstagePatch, unstagePatchBuffer.buffer).hunks(
          {
            startRow: 0,
            endRow: 2,
            header: '@@ -1,3 +1,0 @@',
            regions: [
              {kind: 'deletion', string: '-0000\n-0001\n-0002\n', range: [[0, 0], [2, 4]]},
            ],
          },
        );
      });

      it('unsets the newFile when a symlink is deleted and a file is created in its place', function() {
        const oldSymlink = new File({path: 'file.txt', mode: '120000', symlink: 'wat.txt'});
        const patch = new FilePatch(oldSymlink, newFile, addedPatch);
        const unstagePatch = patch.buildUnstagePatchForLines(buffer, unstagePatchBuffer, new Set([0, 1, 2]));
        assert.strictEqual(unstagePatch.getOldFile(), newFile);
        assert.isFalse(unstagePatch.getNewFile().isPresent());
        assertInFilePatch(unstagePatch, unstagePatchBuffer.buffer).hunks(
          {
            startRow: 0,
            endRow: 2,
            header: '@@ -1,3 +1,0 @@',
            regions: [
              {kind: 'deletion', string: '-0000\n-0001\n-0002\n', range: [[0, 0], [2, 4]]},
            ],
          },
        );
      });
    });

    describe('unstaging lines from a removed file', function() {
      let oldFile, removedFilePatch, buffer;

      beforeEach(function() {
        buffer = new TextBuffer({text: '0000\n0001\n0002\n'});
        const layers = buildLayers(buffer);
        const hunks = [
          new Hunk({
            oldStartRow: 1, oldRowCount: 0, newStartRow: 1, newRowCount: 3,
            marker: markRange(layers.hunk, 0, 2),
            regions: [
              new Deletion(markRange(layers.deletion, 0, 2)),
            ],
          }),
        ];
        oldFile = new File({path: 'file.txt', mode: '100644'});
        const marker = markRange(layers.patch, 0, 2);
        const removedPatch = new Patch({status: 'deleted', hunks, marker});
        removedFilePatch = new FilePatch(oldFile, nullFile, removedPatch);
      });

      it('handles unstaging part of the file', function() {
        const discardPatch = removedFilePatch.buildUnstagePatchForLines(buffer, unstagePatchBuffer, new Set([1]));
        assert.strictEqual(discardPatch.getStatus(), 'added');
        assert.strictEqual(discardPatch.getOldFile(), nullFile);
        assert.strictEqual(discardPatch.getNewFile(), oldFile);
        assertInFilePatch(discardPatch, unstagePatchBuffer.buffer).hunks(
          {
            startRow: 0,
            endRow: 0,
            header: '@@ -1,0 +1,1 @@',
            regions: [
              {kind: 'addition', string: '+0001\n', range: [[0, 0], [0, 4]]},
            ],
          },
        );
      });

      it('handles unstaging the entire file', function() {
        const discardPatch = removedFilePatch.buildUnstagePatchForLines(
          buffer,
          unstagePatchBuffer,
          new Set([0, 1, 2]),
        );
        assert.strictEqual(discardPatch.getStatus(), 'added');
        assert.strictEqual(discardPatch.getOldFile(), nullFile);
        assert.strictEqual(discardPatch.getNewFile(), oldFile);
        assertInFilePatch(discardPatch, unstagePatchBuffer.buffer).hunks(
          {
            startRow: 0,
            endRow: 2,
            header: '@@ -1,0 +1,3 @@',
            regions: [
              {kind: 'addition', string: '+0000\n+0001\n+0002\n', range: [[0, 0], [2, 4]]},
            ],
          },
        );
      });
    });
  });

  describe('toStringIn()', function() {
    it('converts the patch to the standard textual format', function() {
      const buffer = new TextBuffer({text: '0000\n0001\n0002\n0003\n0004\n0005\n0006\n0007\n'});
      const layers = buildLayers(buffer);
      const hunks = [
        new Hunk({
          oldStartRow: 10, oldRowCount: 4, newStartRow: 10, newRowCount: 3,
          marker: markRange(layers.hunk, 0, 4),
          regions: [
            new Unchanged(markRange(layers.unchanged, 0)),
            new Addition(markRange(layers.addition, 1)),
            new Deletion(markRange(layers.deletion, 2, 3)),
            new Unchanged(markRange(layers.unchanged, 4)),
          ],
        }),
        new Hunk({
          oldStartRow: 20, oldRowCount: 2, newStartRow: 20, newRowCount: 3,
          marker: markRange(layers.hunk, 5, 7),
          regions: [
            new Unchanged(markRange(layers.unchanged, 5)),
            new Addition(markRange(layers.addition, 6)),
            new Unchanged(markRange(layers.unchanged, 7)),
          ],
        }),
      ];
      const marker = markRange(layers.patch, 0, 7);
      const patch = new Patch({status: 'modified', hunks, marker});
      const oldFile = new File({path: 'a.txt', mode: '100644'});
      const newFile = new File({path: 'b.txt', mode: '100755'});
      const filePatch = new FilePatch(oldFile, newFile, patch);

      const expectedString =
        'diff --git a/a.txt b/b.txt\n' +
        '--- a/a.txt\n' +
        '+++ b/b.txt\n' +
        '@@ -10,4 +10,3 @@\n' +
        ' 0000\n' +
        '+0001\n' +
        '-0002\n' +
        '-0003\n' +
        ' 0004\n' +
        '@@ -20,2 +20,3 @@\n' +
        ' 0005\n' +
        '+0006\n' +
        ' 0007\n';
      assert.strictEqual(filePatch.toStringIn(buffer), expectedString);
    });

    it('correctly formats a file with no newline at the end', function() {
      const buffer = new TextBuffer({text: '0000\n0001\n No newline at end of file\n'});
      const layers = buildLayers(buffer);
      const hunks = [
        new Hunk({
          oldStartRow: 1, oldRowCount: 1, newStartRow: 1, newRowCount: 2,
          marker: markRange(layers.hunk, 0, 2),
          regions: [
            new Unchanged(markRange(layers.unchanged, 0)),
            new Addition(markRange(layers.addition, 1)),
            new NoNewline(markRange(layers.noNewline, 2)),
          ],
        }),
      ];
      const marker = markRange(layers.patch, 0, 2);
      const patch = new Patch({status: 'modified', hunks, marker});
      const oldFile = new File({path: 'a.txt', mode: '100644'});
      const newFile = new File({path: 'b.txt', mode: '100755'});
      const filePatch = new FilePatch(oldFile, newFile, patch);

      const expectedString =
        'diff --git a/a.txt b/b.txt\n' +
        '--- a/a.txt\n' +
        '+++ b/b.txt\n' +
        '@@ -1,1 +1,2 @@\n' +
        ' 0000\n' +
        '+0001\n' +
        '\\ No newline at end of file\n';
      assert.strictEqual(filePatch.toStringIn(buffer), expectedString);
    });

    describe('typechange file patches', function() {
      it('handles typechange patches for a symlink replaced with a file', function() {
        const buffer = new TextBuffer({text: '0000\n0001\n'});
        const layers = buildLayers(buffer);
        const hunks = [
          new Hunk({
            oldStartRow: 1, oldRowCount: 0, newStartRow: 1, newRowCount: 2,
            marker: markRange(layers.hunk, 0, 1),
            regions: [
              new Addition(markRange(layers.addition, 0, 1)),
            ],
          }),
        ];
        const marker = markRange(layers.patch, 0, 1);
        const patch = new Patch({status: 'added', hunks, marker});
        const oldFile = new File({path: 'a.txt', mode: '120000', symlink: 'dest.txt'});
        const newFile = new File({path: 'a.txt', mode: '100644'});
        const filePatch = new FilePatch(oldFile, newFile, patch);

        const expectedString =
          'diff --git a/a.txt b/a.txt\n' +
          'deleted file mode 120000\n' +
          '--- a/a.txt\n' +
          '+++ /dev/null\n' +
          '@@ -1 +0,0 @@\n' +
          '-dest.txt\n' +
          '\\ No newline at end of file\n' +
          'diff --git a/a.txt b/a.txt\n' +
          'new file mode 100644\n' +
          '--- /dev/null\n' +
          '+++ b/a.txt\n' +
          '@@ -1,0 +1,2 @@\n' +
          '+0000\n' +
          '+0001\n';
        assert.strictEqual(filePatch.toStringIn(buffer), expectedString);
      });

      it('handles typechange patches for a file replaced with a symlink', function() {
        const buffer = new TextBuffer({text: '0000\n0001\n'});
        const layers = buildLayers(buffer);
        const hunks = [
          new Hunk({
            oldStartRow: 1, oldRowCount: 2, newStartRow: 1, newRowCount: 0,
            markers: markRange(layers.hunk, 0, 1),
            regions: [
              new Deletion(markRange(layers.deletion, 0, 1)),
            ],
          }),
        ];
        const marker = markRange(layers.patch, 0, 1);
        const patch = new Patch({status: 'deleted', hunks, marker});
        const oldFile = new File({path: 'a.txt', mode: '100644'});
        const newFile = new File({path: 'a.txt', mode: '120000', symlink: 'dest.txt'});
        const filePatch = new FilePatch(oldFile, newFile, patch);

        const expectedString =
          'diff --git a/a.txt b/a.txt\n' +
          'deleted file mode 100644\n' +
          '--- a/a.txt\n' +
          '+++ /dev/null\n' +
          '@@ -1,2 +1,0 @@\n' +
          '-0000\n' +
          '-0001\n' +
          'diff --git a/a.txt b/a.txt\n' +
          'new file mode 120000\n' +
          '--- /dev/null\n' +
          '+++ b/a.txt\n' +
          '@@ -0,0 +1 @@\n' +
          '+dest.txt\n' +
          '\\ No newline at end of file\n';
        assert.strictEqual(filePatch.toStringIn(buffer), expectedString);
      });
    });
  });

  it('has a nullFilePatch that stubs all FilePatch methods', function() {
    const nullFilePatch = FilePatch.createNull();

    assert.isFalse(nullFilePatch.isPresent());
    assert.isFalse(nullFilePatch.getOldFile().isPresent());
    assert.isFalse(nullFilePatch.getNewFile().isPresent());
    assert.isFalse(nullFilePatch.getPatch().isPresent());
    assert.isNull(nullFilePatch.getOldPath());
    assert.isNull(nullFilePatch.getNewPath());
    assert.isNull(nullFilePatch.getOldMode());
    assert.isNull(nullFilePatch.getNewMode());
    assert.isNull(nullFilePatch.getOldSymlink());
    assert.isNull(nullFilePatch.getNewSymlink());
    assert.isFalse(nullFilePatch.didChangeExecutableMode());
    assert.isFalse(nullFilePatch.hasSymlink());
    assert.isFalse(nullFilePatch.hasTypechange());
    assert.isNull(nullFilePatch.getPath());
    assert.isNull(nullFilePatch.getStatus());
    assert.lengthOf(nullFilePatch.getHunks(), 0);
    assert.isFalse(nullFilePatch.buildStagePatchForLines(new Set([0])).isPresent());
    assert.isFalse(nullFilePatch.buildUnstagePatchForLines(new Set([0])).isPresent());
    assert.strictEqual(nullFilePatch.toStringIn(new TextBuffer()), '');
  });

  describe('render status changes', function() {
    let sub;

    afterEach(function() {
      sub && sub.dispose();
    });

    it('announces the collapse of an expanded patch', function() {
      const {multiFilePatch} = multiFilePatchBuilder().addFilePatch().build();
      const filePatch = multiFilePatch.getFilePatches()[0];
      const callback = sinon.spy();
      sub = filePatch.onDidChangeRenderStatus(callback);

      assert.strictEqual(EXPANDED, filePatch.getRenderStatus());

      multiFilePatch.collapseFilePatch(filePatch);

      assert.strictEqual(COLLAPSED, filePatch.getRenderStatus());
      assert.isTrue(callback.calledWith(filePatch));
    });

    it('triggerCollapseIn returns false if patch is not visible', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.renderStatus(DEFERRED);
        }).build();
      const filePatch = multiFilePatch.getFilePatches()[0];
      assert.isFalse(filePatch.triggerCollapseIn(new PatchBuffer(), {before: [], after: []}));
    });

    it('triggerCollapseIn does not delete the trailing line if the collapsed patch has no content', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('0.txt'));
          fp.addHunk(h => h.added('0'));
        })
        .addFilePatch(fp => {
          fp.setOldFile(f => f.path('1.txt'));
          fp.setNewFile(f => f.path('1.txt').executable());
          fp.empty();
        })
        .build();

      assert.strictEqual(multiFilePatch.getBuffer().getText(), '0');

      multiFilePatch.collapseFilePatch(multiFilePatch.getFilePatches()[1]);

      assert.strictEqual(multiFilePatch.getBuffer().getText(), '0');
    });

    it('announces the expansion of a collapsed patch', function() {
      const {multiFilePatch} = multiFilePatchBuilder()
        .addFilePatch(fp => {
          fp.renderStatus(COLLAPSED);
        }).build();
      const filePatch = multiFilePatch.getFilePatches()[0];

      const callback = sinon.spy();
      sub = filePatch.onDidChangeRenderStatus(callback);

      assert.deepEqual(COLLAPSED, filePatch.getRenderStatus());
      multiFilePatch.expandFilePatch(filePatch);

      assert.deepEqual(EXPANDED, filePatch.getRenderStatus());
      assert.isTrue(callback.calledWith(filePatch));
    });

    it('does not announce non-changes', function() {
      const {multiFilePatch} = multiFilePatchBuilder().addFilePatch().build();
      const filePatch = multiFilePatch.getFilePatches()[0];

      const callback = sinon.spy();
      sub = filePatch.onDidChangeRenderStatus(callback);

      assert.deepEqual(EXPANDED, filePatch.getRenderStatus());

      multiFilePatch.expandFilePatch(filePatch);
      assert.isFalse(callback.called);
    });
  });
});

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
