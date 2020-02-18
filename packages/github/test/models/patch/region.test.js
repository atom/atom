import {TextBuffer} from 'atom';
import {Addition, Deletion, NoNewline, Unchanged} from '../../../lib/models/patch/region';

describe('Region', function() {
  let buffer, marker;

  beforeEach(function() {
    buffer = new TextBuffer({text: '0000\n1111\n2222\n3333\n4444\n5555\n6666\n7777\n8888\n9999\n'});
    marker = buffer.markRange([[1, 0], [3, 4]]);
  });

  describe('Addition', function() {
    let addition;

    beforeEach(function() {
      addition = new Addition(marker);
    });

    it('has marker and range accessors', function() {
      assert.strictEqual(addition.getMarker(), marker);
      assert.deepEqual(addition.getRange().serialize(), [[1, 0], [3, 4]]);
      assert.strictEqual(addition.getStartBufferRow(), 1);
      assert.strictEqual(addition.getEndBufferRow(), 3);
    });

    it('delegates some methods to its row range', function() {
      assert.sameMembers(Array.from(addition.getBufferRows()), [1, 2, 3]);
      assert.strictEqual(addition.bufferRowCount(), 3);
      assert.isTrue(addition.includesBufferRow(2));
    });

    it('can be recognized by the isAddition predicate', function() {
      assert.isTrue(addition.isAddition());
      assert.isFalse(addition.isDeletion());
      assert.isFalse(addition.isUnchanged());
      assert.isFalse(addition.isNoNewline());

      assert.isTrue(addition.isChange());
    });

    it('executes the "addition" branch of a when() call', function() {
      const result = addition.when({
        addition: () => 'correct',
        deletion: () => 'wrong: deletion',
        unchanged: () => 'wrong: unchanged',
        nonewline: () => 'wrong: nonewline',
        default: () => 'wrong: default',
      });
      assert.strictEqual(result, 'correct');
    });

    it('executes the "default" branch of a when() call when no "addition" is provided', function() {
      const result = addition.when({
        deletion: () => 'wrong: deletion',
        unchanged: () => 'wrong: unchanged',
        nonewline: () => 'wrong: nonewline',
        default: () => 'correct',
      });
      assert.strictEqual(result, 'correct');
    });

    it('returns undefined from when() if neither "addition" nor "default" are provided', function() {
      const result = addition.when({
        deletion: () => 'wrong: deletion',
        unchanged: () => 'wrong: unchanged',
        nonewline: () => 'wrong: nonewline',
      });
      assert.isUndefined(result);
    });

    it('uses "+" as a prefix for toStringIn()', function() {
      assert.strictEqual(addition.toStringIn(buffer), '+1111\n+2222\n+3333\n');
    });

    it('inverts to a deletion', function() {
      const inverted = addition.invertIn(buffer);
      assert.isTrue(inverted.isDeletion());
      assert.deepEqual(inverted.getRange().serialize(), addition.getRange().serialize());
    });
  });

  describe('Deletion', function() {
    let deletion;

    beforeEach(function() {
      deletion = new Deletion(marker);
    });

    it('can be recognized by the isDeletion predicate', function() {
      assert.isFalse(deletion.isAddition());
      assert.isTrue(deletion.isDeletion());
      assert.isFalse(deletion.isUnchanged());
      assert.isFalse(deletion.isNoNewline());

      assert.isTrue(deletion.isChange());
    });

    it('executes the "deletion" branch of a when() call', function() {
      const result = deletion.when({
        addition: () => 'wrong: addition',
        deletion: () => 'correct',
        unchanged: () => 'wrong: unchanged',
        nonewline: () => 'wrong: nonewline',
        default: () => 'wrong: default',
      });
      assert.strictEqual(result, 'correct');
    });

    it('executes the "default" branch of a when() call when no "deletion" is provided', function() {
      const result = deletion.when({
        addition: () => 'wrong: addition',
        unchanged: () => 'wrong: unchanged',
        nonewline: () => 'wrong: nonewline',
        default: () => 'correct',
      });
      assert.strictEqual(result, 'correct');
    });

    it('returns undefined from when() if neither "deletion" nor "default" are provided', function() {
      const result = deletion.when({
        addition: () => 'wrong: addition',
        unchanged: () => 'wrong: unchanged',
        nonewline: () => 'wrong: nonewline',
      });
      assert.isUndefined(result);
    });

    it('uses "-" as a prefix for toStringIn()', function() {
      assert.strictEqual(deletion.toStringIn(buffer), '-1111\n-2222\n-3333\n');
    });

    it('inverts to an addition', function() {
      const inverted = deletion.invertIn(buffer);
      assert.isTrue(inverted.isAddition());
      assert.deepEqual(inverted.getRange().serialize(), deletion.getRange().serialize());
    });
  });

  describe('Unchanged', function() {
    let unchanged;

    beforeEach(function() {
      unchanged = new Unchanged(marker);
    });

    it('can be recognized by the isUnchanged predicate', function() {
      assert.isFalse(unchanged.isAddition());
      assert.isFalse(unchanged.isDeletion());
      assert.isTrue(unchanged.isUnchanged());
      assert.isFalse(unchanged.isNoNewline());

      assert.isFalse(unchanged.isChange());
    });

    it('executes the "unchanged" branch of a when() call', function() {
      const result = unchanged.when({
        addition: () => 'wrong: addition',
        deletion: () => 'wrong: deletion',
        unchanged: () => 'correct',
        nonewline: () => 'wrong: nonewline',
        default: () => 'wrong: default',
      });
      assert.strictEqual(result, 'correct');
    });

    it('executes the "default" branch of a when() call when no "unchanged" is provided', function() {
      const result = unchanged.when({
        addition: () => 'wrong: addition',
        deletion: () => 'wrong: deletion',
        nonewline: () => 'wrong: nonewline',
        default: () => 'correct',
      });
      assert.strictEqual(result, 'correct');
    });

    it('returns undefined from when() if neither "unchanged" nor "default" are provided', function() {
      const result = unchanged.when({
        addition: () => 'wrong: addition',
        deletion: () => 'wrong: deletion',
        nonewline: () => 'wrong: nonewline',
      });
      assert.isUndefined(result);
    });

    it('uses " " as a prefix for toStringIn()', function() {
      assert.strictEqual(unchanged.toStringIn(buffer), ' 1111\n 2222\n 3333\n');
    });

    it('inverts as itself', function() {
      const inverted = unchanged.invertIn(buffer);
      assert.isTrue(inverted.isUnchanged());
      assert.deepEqual(inverted.getRange().serialize(), unchanged.getRange().serialize());
    });
  });

  describe('NoNewline', function() {
    let noNewline;

    beforeEach(function() {
      noNewline = new NoNewline(marker);
    });

    it('can be recognized by the isNoNewline predicate', function() {
      assert.isFalse(noNewline.isAddition());
      assert.isFalse(noNewline.isDeletion());
      assert.isFalse(noNewline.isUnchanged());
      assert.isTrue(noNewline.isNoNewline());

      assert.isFalse(noNewline.isChange());
    });

    it('executes the "nonewline" branch of a when() call', function() {
      const result = noNewline.when({
        addition: () => 'wrong: addition',
        deletion: () => 'wrong: deletion',
        unchanged: () => 'wrong: unchanged',
        nonewline: () => 'correct',
        default: () => 'wrong: default',
      });
      assert.strictEqual(result, 'correct');
    });

    it('executes the "default" branch of a when() call when no "nonewline" is provided', function() {
      const result = noNewline.when({
        addition: () => 'wrong: addition',
        deletion: () => 'wrong: deletion',
        unchanged: () => 'wrong: unchanged',
        default: () => 'correct',
      });
      assert.strictEqual(result, 'correct');
    });

    it('returns undefined from when() if neither "nonewline" nor "default" are provided', function() {
      const result = noNewline.when({
        addition: () => 'wrong: addition',
        deletion: () => 'wrong: deletion',
        unchanged: () => 'wrong: unchanged',
      });
      assert.isUndefined(result);
    });

    it('uses "\\" as a prefix for toStringIn()', function() {
      assert.strictEqual(noNewline.toStringIn(buffer), '\\1111\n\\2222\n\\3333\n');
    });

    it('inverts as another nonewline change', function() {
      const inverted = noNewline.invertIn(buffer);
      assert.isTrue(inverted.isNoNewline());
      assert.deepEqual(inverted.getRange().serialize(), noNewline.getRange().serialize());
    });
  });

  describe('intersectRows()', function() {
    function assertIntersections(actual, expected) {
      const serialized = actual.map(({intersection, gap}) => ({intersection: intersection.serialize(), gap}));
      assert.deepEqual(serialized, expected);
    }

    it('returns an array containing all gaps with no intersection rows', function() {
      const region = new Addition(buffer.markRange([[1, 0], [3, Infinity]]));

      assertIntersections(region.intersectRows(new Set([0, 5, 6]), false), []);
      assertIntersections(region.intersectRows(new Set([0, 5, 6]), true), [
        {intersection: [[1, 0], [3, Infinity]], gap: true},
      ]);
    });

    it('detects an intersection at the beginning of the range', function() {
      const region = new Deletion(buffer.markRange([[2, 0], [6, Infinity]]));
      const rowSet = new Set([0, 1, 2, 3]);

      assertIntersections(region.intersectRows(rowSet, false), [
        {intersection: [[2, 0], [3, Infinity]], gap: false},
      ]);
      assertIntersections(region.intersectRows(rowSet, true), [
        {intersection: [[2, 0], [3, Infinity]], gap: false},
        {intersection: [[4, 0], [6, Infinity]], gap: true},
      ]);
    });

    it('detects an intersection in the middle of the range', function() {
      const region = new Unchanged(buffer.markRange([[2, 0], [6, Infinity]]));
      const rowSet = new Set([0, 3, 4, 8, 9]);

      assertIntersections(region.intersectRows(rowSet, false), [
        {intersection: [[3, 0], [4, Infinity]], gap: false},
      ]);
      assertIntersections(region.intersectRows(rowSet, true), [
        {intersection: [[2, 0], [2, Infinity]], gap: true},
        {intersection: [[3, 0], [4, Infinity]], gap: false},
        {intersection: [[5, 0], [6, Infinity]], gap: true},
      ]);
    });

    it('detects an intersection at the end of the range', function() {
      const region = new Addition(buffer.markRange([[2, 0], [6, Infinity]]));
      const rowSet = new Set([4, 5, 6, 7, 10, 11]);

      assertIntersections(region.intersectRows(rowSet, false), [
        {intersection: [[4, 0], [6, Infinity]], gap: false},
      ]);
      assertIntersections(region.intersectRows(rowSet, true), [
        {intersection: [[2, 0], [3, Infinity]], gap: true},
        {intersection: [[4, 0], [6, Infinity]], gap: false},
      ]);
    });

    it('detects multiple intersections', function() {
      const region = new Deletion(buffer.markRange([[2, 0], [8, Infinity]]));
      const rowSet = new Set([0, 3, 4, 6, 7, 10]);

      assertIntersections(region.intersectRows(rowSet, false), [
        {intersection: [[3, 0], [4, Infinity]], gap: false},
        {intersection: [[6, 0], [7, Infinity]], gap: false},
      ]);
      assertIntersections(region.intersectRows(rowSet, true), [
        {intersection: [[2, 0], [2, Infinity]], gap: true},
        {intersection: [[3, 0], [4, Infinity]], gap: false},
        {intersection: [[5, 0], [5, Infinity]], gap: true},
        {intersection: [[6, 0], [7, Infinity]], gap: false},
        {intersection: [[8, 0], [8, Infinity]], gap: true},
      ]);
    });
  });

  it('correctly prefixes empty lines in its range', function() {
    //                               0      1 2     3 4 5     6 7      8
    const b = new TextBuffer({text: 'before\n\n0001\n\n\n0002\n\nafter\n'});
    const region = new Addition(b.markRange([[1, 0], [6, 0]]));

    assert.strictEqual(region.toStringIn(b), '+\n+0001\n+\n+\n+0002\n+\n');
  });
});
