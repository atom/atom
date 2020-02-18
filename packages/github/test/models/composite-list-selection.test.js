import CompositeListSelection from '../../lib/models/composite-list-selection';
import {assertEqualSets} from '../helpers';

describe('CompositeListSelection', function() {
  describe('selection', function() {
    it('allows specific items to be selected, but does not select across lists', function() {
      let selection = new CompositeListSelection({
        listsByKey: [
          ['unstaged', ['a', 'b']],
          ['conflicts', ['c']],
          ['staged', ['d', 'e', 'f']],
        ],
      });

      selection = selection.selectItem('e');
      assert.strictEqual(selection.getActiveListKey(), 'staged');
      assertEqualSets(selection.getSelectedItems(), new Set(['e']));
      selection = selection.selectItem('f', true);
      assert.strictEqual(selection.getActiveListKey(), 'staged');
      assertEqualSets(selection.getSelectedItems(), new Set(['e', 'f']));
      selection = selection.selectItem('d', true);

      assert.strictEqual(selection.getActiveListKey(), 'staged');
      assertEqualSets(selection.getSelectedItems(), new Set(['d', 'e']));
      selection = selection.selectItem('c', true);
      assert.strictEqual(selection.getActiveListKey(), 'staged');
      assertEqualSets(selection.getSelectedItems(), new Set(['d', 'e']));
    });

    it('allows the next and previous item to be selected', function() {
      let selection = new CompositeListSelection({
        listsByKey: [
          ['unstaged', ['a', 'b']],
          ['conflicts', ['c']],
          ['staged', ['d', 'e']],
        ],
      });

      assert.strictEqual(selection.getActiveListKey(), 'unstaged');
      assertEqualSets(selection.getSelectedItems(), new Set(['a']));

      selection = selection.selectNextItem();
      assert.strictEqual(selection.getActiveListKey(), 'unstaged');
      assertEqualSets(selection.getSelectedItems(), new Set(['b']));

      selection = selection.selectNextItem();
      assert.strictEqual(selection.getActiveListKey(), 'conflicts');
      assertEqualSets(selection.getSelectedItems(), new Set(['c']));

      selection = selection.selectNextItem();
      assert.strictEqual(selection.getActiveListKey(), 'staged');
      assertEqualSets(selection.getSelectedItems(), new Set(['d']));

      selection = selection.selectNextItem();
      assert.strictEqual(selection.getActiveListKey(), 'staged');
      assertEqualSets(selection.getSelectedItems(), new Set(['e']));

      selection = selection.selectNextItem();
      assert.strictEqual(selection.getActiveListKey(), 'staged');
      assertEqualSets(selection.getSelectedItems(), new Set(['e']));

      selection = selection.selectPreviousItem();
      assert.strictEqual(selection.getActiveListKey(), 'staged');
      assertEqualSets(selection.getSelectedItems(), new Set(['d']));

      selection = selection.selectPreviousItem();
      assert.strictEqual(selection.getActiveListKey(), 'conflicts');
      assertEqualSets(selection.getSelectedItems(), new Set(['c']));

      selection = selection.selectPreviousItem();
      assert.strictEqual(selection.getActiveListKey(), 'unstaged');
      assertEqualSets(selection.getSelectedItems(), new Set(['b']));

      selection = selection.selectPreviousItem();
      assert.strictEqual(selection.getActiveListKey(), 'unstaged');
      assertEqualSets(selection.getSelectedItems(), new Set(['a']));

      selection = selection.selectPreviousItem();
      assert.strictEqual(selection.getActiveListKey(), 'unstaged');
      assertEqualSets(selection.getSelectedItems(), new Set(['a']));
    });

    it('allows the selection to be expanded to the next or previous item', function() {
      let selection = new CompositeListSelection({
        listsByKey: [
          ['unstaged', ['a', 'b']],
          ['conflicts', ['c']],
          ['staged', ['d', 'e']],
        ],
      });

      assert.strictEqual(selection.getActiveListKey(), 'unstaged');
      assertEqualSets(selection.getSelectedItems(), new Set(['a']));

      selection = selection.selectNextItem(true);
      assert.strictEqual(selection.getActiveListKey(), 'unstaged');
      assertEqualSets(selection.getSelectedItems(), new Set(['a', 'b']));

      // Does not expand selections across lists
      selection = selection.selectNextItem(true);
      assert.strictEqual(selection.getActiveListKey(), 'unstaged');
      assertEqualSets(selection.getSelectedItems(), new Set(['a', 'b']));

      selection = selection.selectItem('e');
      selection = selection.selectPreviousItem(true);
      selection = selection.selectPreviousItem(true);
      assert.strictEqual(selection.getActiveListKey(), 'staged');
      assertEqualSets(selection.getSelectedItems(), new Set(['d', 'e']));
    });

    it('skips empty lists when selecting the next or previous item', function() {
      let selection = new CompositeListSelection({
        listsByKey: [
          ['unstaged', ['a', 'b']],
          ['conflicts', []],
          ['staged', ['d', 'e']],
        ],
      });

      selection = selection.selectNextItem();
      selection = selection.selectNextItem();
      assert.strictEqual(selection.getActiveListKey(), 'staged');
      assertEqualSets(selection.getSelectedItems(), new Set(['d']));
      selection = selection.selectPreviousItem();
      assert.strictEqual(selection.getActiveListKey(), 'unstaged');
      assertEqualSets(selection.getSelectedItems(), new Set(['b']));
    });

    it('collapses the selection when moving down with the next list empty or up with the previous list empty', function() {
      let selection = new CompositeListSelection({
        listsByKey: [
          ['unstaged', ['a', 'b']],
          ['conflicts', []],
          ['staged', []],
        ],
      });

      selection = selection.selectNextItem(true);
      assertEqualSets(selection.getSelectedItems(), new Set(['a', 'b']));
      selection = selection.selectNextItem();
      assertEqualSets(selection.getSelectedItems(), new Set(['b']));

      selection.updateLists([
        ['unstaged', []],
        ['conflicts', []],
        ['staged', ['a', 'b']],
      ]);

      selection = selection.selectNextItem();
      selection = selection.selectPreviousItem(true);
      assertEqualSets(selection.getSelectedItems(), new Set(['a', 'b']));
      selection = selection.selectPreviousItem();
      assertEqualSets(selection.getSelectedItems(), new Set(['a']));
    });

    it('allows selections to be added in the current active list, but updates the existing selection when activating a different list', function() {
      let selection = new CompositeListSelection({
        listsByKey: [
          ['unstaged', ['a', 'b', 'c']],
          ['conflicts', []],
          ['staged', ['e', 'f', 'g']],
        ],
      });

      selection = selection.addOrSubtractSelection('c');
      assertEqualSets(selection.getSelectedItems(), new Set(['a', 'c']));

      selection = selection.addOrSubtractSelection('g');
      assertEqualSets(selection.getSelectedItems(), new Set(['g']));
    });

    it('allows all items in the active list to be selected', function() {
      let selection = new CompositeListSelection({
        listsByKey: [
          ['unstaged', ['a', 'b', 'c']],
          ['conflicts', []],
          ['staged', ['e', 'f', 'g']],
        ],
      });

      selection = selection.selectAllItems();
      assertEqualSets(selection.getSelectedItems(), new Set(['a', 'b', 'c']));

      selection = selection.activateNextSelection();
      selection = selection.selectAllItems();
      assertEqualSets(selection.getSelectedItems(), new Set(['e', 'f', 'g']));
    });

    it('allows the first or last item in the active list to be selected', function() {
      let selection = new CompositeListSelection({
        listsByKey: [
          ['unstaged', ['a', 'b', 'c']],
          ['conflicts', []],
          ['staged', ['e', 'f', 'g']],
        ],
      });

      selection = selection.activateNextSelection();
      selection = selection.selectLastItem();
      assertEqualSets(selection.getSelectedItems(), new Set(['g']));
      selection = selection.selectFirstItem();
      assertEqualSets(selection.getSelectedItems(), new Set(['e']));
      selection = selection.selectLastItem(true);
      assertEqualSets(selection.getSelectedItems(), new Set(['e', 'f', 'g']));
      selection = selection.selectNextItem();
      assertEqualSets(selection.getSelectedItems(), new Set(['g']));
      selection = selection.selectFirstItem(true);
      assertEqualSets(selection.getSelectedItems(), new Set(['e', 'f', 'g']));
    });

    it('allows the last non-empty selection to be chosen', function() {
      let selection = new CompositeListSelection({
        listsByKey: [
          ['unstaged', ['a', 'b', 'c']],
          ['conflicts', ['e', 'f']],
          ['staged', []],
        ],
      });

      selection = selection.activateLastSelection();
      assertEqualSets(selection.getSelectedItems(), new Set(['e']));
    });
  });

  describe('updateLists(listsByKey)', function() {
    it('keeps the selection head of each list pointed to an item with the same id', function() {
      let listsByKey = [
        ['unstaged', [{filePath: 'a'}, {filePath: 'b'}]],
        ['conflicts', [{filePath: 'c'}]],
        ['staged', [{filePath: 'd'}, {filePath: 'e'}, {filePath: 'f'}]],
      ];
      let selection = new CompositeListSelection({
        listsByKey, idForItem: item => item.filePath,
      });

      selection = selection.selectItem(listsByKey[0][1][1]);
      selection = selection.selectItem(listsByKey[2][1][1]);
      selection = selection.selectItem(listsByKey[2][1][2], true);

      listsByKey = [
        ['unstaged', [{filePath: 'a'}, {filePath: 'q'}, {filePath: 'b'}, {filePath: 'r'}]],
        ['conflicts', [{filePath: 's'}, {filePath: 'c'}]],
        ['staged', [{filePath: 'd'}, {filePath: 't'}, {filePath: 'e'}, {filePath: 'f'}]],
      ];

      selection = selection.updateLists(listsByKey);

      assert.strictEqual(selection.getActiveListKey(), 'staged');
      assertEqualSets(selection.getSelectedItems(), new Set([listsByKey[2][1][3]]));

      selection = selection.activatePreviousSelection();
      assert.strictEqual(selection.getActiveListKey(), 'conflicts');
      assertEqualSets(selection.getSelectedItems(), new Set([listsByKey[1][1][1]]));

      selection = selection.activatePreviousSelection();
      assert.strictEqual(selection.getActiveListKey(), 'unstaged');
      assertEqualSets(selection.getSelectedItems(), new Set([listsByKey[0][1][2]]));
    });

    it('collapses to the start of the previous selection if the old head item is removed', function() {
      let listsByKey = [
        ['unstaged', [{filePath: 'a'}, {filePath: 'b'}, {filePath: 'c'}]],
        ['conflicts', []],
        ['staged', [{filePath: 'd'}, {filePath: 'e'}, {filePath: 'f'}]],
      ];
      let selection = new CompositeListSelection({
        listsByKey, idForItem: item => item.filePath,
      });

      selection = selection.selectItem(listsByKey[0][1][1]);
      selection = selection.selectItem(listsByKey[0][1][2], true);
      selection = selection.selectItem(listsByKey[2][1][1]);

      listsByKey = [
        ['unstaged', [{filePath: 'a'}]],
        ['conflicts', []],
        ['staged', [{filePath: 'd'}, {filePath: 'f'}]],
      ];
      selection = selection.updateLists(listsByKey);

      assert.strictEqual(selection.getActiveListKey(), 'staged');
      assertEqualSets(selection.getSelectedItems(), new Set([listsByKey[2][1][1]]));

      selection = selection.activatePreviousSelection();
      assert.strictEqual(selection.getActiveListKey(), 'unstaged');
      assertEqualSets(selection.getSelectedItems(), new Set([listsByKey[0][1][0]]));
    });

    it('activates the first non-empty list following or preceding the current active list if one exists', function() {
      let selection = new CompositeListSelection({
        listsByKey: [
          ['unstaged', ['a', 'b']],
          ['conflicts', []],
          ['staged', []],
        ],
      });

      selection = selection.updateLists([
        ['unstaged', []],
        ['conflicts', []],
        ['staged', ['a', 'b']],
      ]);
      assert.strictEqual(selection.getActiveListKey(), 'staged');

      selection = selection.updateLists([
        ['unstaged', ['a', 'b']],
        ['conflicts', []],
        ['staged', []],
      ]);
      assert.strictEqual(selection.getActiveListKey(), 'unstaged');
    });
  });
});
