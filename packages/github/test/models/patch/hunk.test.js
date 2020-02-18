import {TextBuffer} from 'atom';

import Hunk from '../../../lib/models/patch/hunk';
import {Unchanged, Addition, Deletion, NoNewline} from '../../../lib/models/patch/region';

describe('Hunk', function() {
  const buffer = new TextBuffer({
    text:
      '0000\n0001\n0002\n0003\n0004\n0005\n0006\n0007\n0008\n0009\n' +
      '0010\n0011\n0012\n0013\n0014\n0015\n0016\n0017\n0018\n0019\n',
  });

  const attrs = {
    oldStartRow: 0,
    newStartRow: 0,
    oldRowCount: 0,
    newRowCount: 0,
    sectionHeading: 'sectionHeading',
    marker: buffer.markRange([[1, 0], [10, 4]]),
    regions: [
      new Addition(buffer.markRange([[1, 0], [2, 4]])),
      new Deletion(buffer.markRange([[3, 0], [4, 4]])),
      new Deletion(buffer.markRange([[5, 0], [6, 4]])),
      new Unchanged(buffer.markRange([[7, 0], [10, 4]])),
    ],
  };

  it('has some basic accessors', function() {
    const h = new Hunk({
      oldStartRow: 0,
      newStartRow: 1,
      oldRowCount: 2,
      newRowCount: 3,
      sectionHeading: 'sectionHeading',
      marker: buffer.markRange([[0, 0], [10, 4]]),
      regions: [
        new Addition(buffer.markRange([[1, 0], [2, 4]])),
        new Deletion(buffer.markRange([[3, 0], [4, 4]])),
        new Deletion(buffer.markRange([[5, 0], [6, 4]])),
        new Unchanged(buffer.markRange([[7, 0], [10, 4]])),
      ],
    });

    assert.strictEqual(h.getOldStartRow(), 0);
    assert.strictEqual(h.getNewStartRow(), 1);
    assert.strictEqual(h.getOldRowCount(), 2);
    assert.strictEqual(h.getNewRowCount(), 3);
    assert.strictEqual(h.getSectionHeading(), 'sectionHeading');
    assert.deepEqual(h.getRange().serialize(), [[0, 0], [10, 4]]);
    assert.strictEqual(h.bufferRowCount(), 11);
    assert.lengthOf(h.getChanges(), 3);
    assert.lengthOf(h.getRegions(), 4);
  });

  it('generates a patch section header', function() {
    const h = new Hunk({
      ...attrs,
      oldStartRow: 0,
      newStartRow: 1,
      oldRowCount: 2,
      newRowCount: 3,
    });

    assert.strictEqual(h.getHeader(), '@@ -0,2 +1,3 @@');
  });

  it('returns a set of covered buffer rows', function() {
    const h = new Hunk({
      ...attrs,
      marker: buffer.markRange([[6, 0], [10, 60]]),
    });
    assert.sameMembers(Array.from(h.getBufferRows()), [6, 7, 8, 9, 10]);
  });

  it('determines if a buffer row is part of this hunk', function() {
    const h = new Hunk({
      ...attrs,
      marker: buffer.markRange([[3, 0], [5, 4]]),
    });

    assert.isFalse(h.includesBufferRow(2));
    assert.isTrue(h.includesBufferRow(3));
    assert.isTrue(h.includesBufferRow(4));
    assert.isTrue(h.includesBufferRow(5));
    assert.isFalse(h.includesBufferRow(6));
  });

  it('computes the old file row for a buffer row', function() {
    const h = new Hunk({
      ...attrs,
      oldStartRow: 10,
      oldRowCount: 6,
      newStartRow: 20,
      newRowCount: 7,
      marker: buffer.markRange([[2, 0], [12, 4]]),
      regions: [
        new Unchanged(buffer.markRange([[2, 0], [2, 4]])),
        new Addition(buffer.markRange([[3, 0], [5, 4]])),
        new Unchanged(buffer.markRange([[6, 0], [6, 4]])),
        new Deletion(buffer.markRange([[7, 0], [9, 4]])),
        new Unchanged(buffer.markRange([[10, 0], [10, 4]])),
        new Addition(buffer.markRange([[11, 0], [11, 4]])),
        new NoNewline(buffer.markRange([[12, 0], [12, 4]])),
      ],
    });

    assert.strictEqual(h.getOldRowAt(2), 10);
    assert.isNull(h.getOldRowAt(3));
    assert.isNull(h.getOldRowAt(4));
    assert.isNull(h.getOldRowAt(5));
    assert.strictEqual(h.getOldRowAt(6), 11);
    assert.strictEqual(h.getOldRowAt(7), 12);
    assert.strictEqual(h.getOldRowAt(8), 13);
    assert.strictEqual(h.getOldRowAt(9), 14);
    assert.strictEqual(h.getOldRowAt(10), 15);
    assert.isNull(h.getOldRowAt(11));
    assert.isNull(h.getOldRowAt(12));
    assert.isNull(h.getOldRowAt(13));
  });

  it('computes the new file row for a buffer row', function() {
    const h = new Hunk({
      ...attrs,
      oldStartRow: 10,
      oldRowCount: 6,
      newStartRow: 20,
      newRowCount: 7,
      marker: buffer.markRange([[2, 0], [12, 4]]),
      regions: [
        new Unchanged(buffer.markRange([[2, 0], [2, 4]])),
        new Addition(buffer.markRange([[3, 0], [5, 4]])),
        new Unchanged(buffer.markRange([[6, 0], [6, 4]])),
        new Deletion(buffer.markRange([[7, 0], [9, 4]])),
        new Unchanged(buffer.markRange([[10, 0], [10, 4]])),
        new Addition(buffer.markRange([[11, 0], [11, 4]])),
        new NoNewline(buffer.markRange([[12, 0], [12, 4]])),
      ],
    });

    assert.strictEqual(h.getNewRowAt(2), 20);
    assert.strictEqual(h.getNewRowAt(3), 21);
    assert.strictEqual(h.getNewRowAt(4), 22);
    assert.strictEqual(h.getNewRowAt(5), 23);
    assert.strictEqual(h.getNewRowAt(6), 24);
    assert.isNull(h.getNewRowAt(7));
    assert.isNull(h.getNewRowAt(8));
    assert.isNull(h.getNewRowAt(9));
    assert.strictEqual(h.getNewRowAt(10), 25);
    assert.strictEqual(h.getNewRowAt(11), 26);
    assert.isNull(h.getNewRowAt(12));
    assert.isNull(h.getNewRowAt(13));
  });

  it('computes the total number of changed lines', function() {
    const h0 = new Hunk({
      ...attrs,
      regions: [
        new Unchanged(buffer.markRange([[1, 0], [1, 4]])),
        new Addition(buffer.markRange([[2, 0], [4, 4]])),
        new Unchanged(buffer.markRange([[5, 0], [5, 4]])),
        new Addition(buffer.markRange([[6, 0], [6, 4]])),
        new Deletion(buffer.markRange([[7, 0], [10, 4]])),
        new Unchanged(buffer.markRange([[11, 0], [11, 4]])),
        new NoNewline(buffer.markRange([[12, 0], [12, 4]])),
      ],
    });
    assert.strictEqual(h0.changedLineCount(), 8);

    const h1 = new Hunk({
      ...attrs,
      regions: [],
    });
    assert.strictEqual(h1.changedLineCount(), 0);
  });

  it('determines the maximum number of digits necessary to represent a diff line number', function() {
    const h0 = new Hunk({
      ...attrs,
      oldStartRow: 200,
      oldRowCount: 10,
      newStartRow: 999,
      newRowCount: 1,
    });
    assert.strictEqual(h0.getMaxLineNumberWidth(), 4);

    const h1 = new Hunk({
      ...attrs,
      oldStartRow: 5000,
      oldRowCount: 10,
      newStartRow: 20000,
      newRowCount: 20,
    });
    assert.strictEqual(h1.getMaxLineNumberWidth(), 5);
  });

  it('updates markers from a marker map', function() {
    const oMarker = buffer.markRange([[0, 0], [10, 4]]);

    const h = new Hunk({
      oldStartRow: 0,
      newStartRow: 1,
      oldRowCount: 2,
      newRowCount: 3,
      sectionHeading: 'sectionHeading',
      marker: oMarker,
      regions: [
        new Addition(buffer.markRange([[1, 0], [2, 4]])),
        new Deletion(buffer.markRange([[3, 0], [4, 4]])),
        new Deletion(buffer.markRange([[5, 0], [6, 4]])),
        new Unchanged(buffer.markRange([[7, 0], [10, 4]])),
      ],
    });

    h.updateMarkers(new Map());
    assert.strictEqual(h.getMarker(), oMarker);

    const regionUpdateMaps = h.getRegions().map(r => sinon.spy(r, 'updateMarkers'));

    const layer = buffer.addMarkerLayer();
    const nMarker = layer.markRange([[0, 0], [10, 4]]);
    const map = new Map([[oMarker, nMarker]]);

    h.updateMarkers(map);

    assert.strictEqual(h.getMarker(), nMarker);
    assert.isTrue(regionUpdateMaps.every(spy => spy.calledWith(map)));
  });

  it('destroys all of its markers', function() {
    const h = new Hunk({
      oldStartRow: 0,
      newStartRow: 1,
      oldRowCount: 2,
      newRowCount: 3,
      sectionHeading: 'sectionHeading',
      marker: buffer.markRange([[0, 0], [10, 4]]),
      regions: [
        new Addition(buffer.markRange([[1, 0], [2, 4]])),
        new Deletion(buffer.markRange([[3, 0], [4, 4]])),
        new Deletion(buffer.markRange([[5, 0], [6, 4]])),
        new Unchanged(buffer.markRange([[7, 0], [10, 4]])),
      ],
    });

    const allMarkers = [h.getMarker(), ...h.getRegions().map(r => r.getMarker())];
    assert.isFalse(allMarkers.some(m => m.isDestroyed()));

    h.destroyMarkers();

    assert.isTrue(allMarkers.every(m => m.isDestroyed()));
  });

  describe('toStringIn()', function() {
    it('prints its header', function() {
      const h = new Hunk({
        ...attrs,
        oldStartRow: 0,
        newStartRow: 1,
        oldRowCount: 2,
        newRowCount: 3,
        changes: [],
      });

      assert.match(h.toStringIn(new TextBuffer()), /^@@ -0,2 \+1,3 @@/);
    });

    it('renders changed and unchanged lines with the appropriate origin characters', function() {
      const nBuffer = new TextBuffer({
        text:
          '0000\n0111\n0222\n0333\n0444\n0555\n0666\n0777\n0888\n0999\n' +
          '1000\n1111\n1222\n' +
          ' No newline at end of file\n',
      });

      const h = new Hunk({
        ...attrs,
        oldStartRow: 1,
        newStartRow: 1,
        oldRowCount: 6,
        newRowCount: 6,
        marker: nBuffer.markRange([[1, 0], [13, 26]]),
        regions: [
          new Unchanged(nBuffer.markRange([[1, 0], [1, 4]])),
          new Addition(nBuffer.markRange([[2, 0], [3, 4]])),
          new Unchanged(nBuffer.markRange([[4, 0], [4, 4]])),
          new Deletion(nBuffer.markRange([[5, 0], [5, 4]])),
          new Unchanged(nBuffer.markRange([[6, 0], [6, 4]])),
          new Addition(nBuffer.markRange([[7, 0], [7, 4]])),
          new Deletion(nBuffer.markRange([[8, 0], [9, 4]])),
          new Addition(nBuffer.markRange([[10, 0], [10, 4]])),
          new Unchanged(nBuffer.markRange([[11, 0], [12, 4]])),
          new NoNewline(nBuffer.markRange([[13, 0], [13, 26]])),
        ],
      });

      assert.strictEqual(h.toStringIn(nBuffer), [
        '@@ -1,6 +1,6 @@\n',
        ' 0111\n',
        '+0222\n',
        '+0333\n',
        ' 0444\n',
        '-0555\n',
        ' 0666\n',
        '+0777\n',
        '-0888\n',
        '-0999\n',
        '+1000\n',
        ' 1111\n',
        ' 1222\n',
        '\\ No newline at end of file\n',
      ].join(''));
    });

    it('renders a hunk without a nonewline', function() {
      const nBuffer = new TextBuffer({text: '0000\n1111\n2222\n3333\n4444\n'});

      const h = new Hunk({
        ...attrs,
        oldStartRow: 1,
        newStartRow: 1,
        oldRowCount: 1,
        newRowCount: 1,
        marker: nBuffer.markRange([[0, 0], [3, 4]]),
        regions: [
          new Unchanged(nBuffer.markRange([[0, 0], [0, 4]])),
          new Addition(nBuffer.markRange([[1, 0], [1, 4]])),
          new Deletion(nBuffer.markRange([[2, 0], [2, 4]])),
          new Unchanged(nBuffer.markRange([[3, 0], [3, 4]])),
        ],
      });

      assert.strictEqual(h.toStringIn(nBuffer), [
        '@@ -1,1 +1,1 @@\n',
        ' 0000\n',
        '+1111\n',
        '-2222\n',
        ' 3333\n',
      ].join(''));
    });
  });
});
