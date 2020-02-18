import ListSelection from '../../lib/models/list-selection';
import {assertEqualSets} from '../helpers';

// This class is mostly tested via CompositeListSelection and FilePatchSelection. This file contains unit tests that are
// more convenient to write directly against this class.
describe('ListSelection', function() {
  describe('coalesce', function() {
    it('correctly handles adding and subtracting a single item (regression)', function() {
      let selection = new ListSelection({items: ['a', 'b', 'c']});
      selection = selection.selectLastItem(true);
      selection = selection.coalesce();
      assertEqualSets(selection.getSelectedItems(), new Set(['a', 'b', 'c']));
      selection = selection.addOrSubtractSelection('b');
      selection = selection.coalesce();
      assertEqualSets(selection.getSelectedItems(), new Set(['a', 'c']));
      selection = selection.addOrSubtractSelection('b');
      selection = selection.coalesce();
      assertEqualSets(selection.getSelectedItems(), new Set(['a', 'b', 'c']));
    });
  });

  describe('selectItem', () => {
    // https://github.com/atom/github/issues/467
    it('selects an item when there are no selections', () => {
      let selection = new ListSelection({items: ['a', 'b', 'c']});
      selection = selection.addOrSubtractSelection('a');
      selection = selection.coalesce();
      assert.strictEqual(selection.getSelectedItems().size, 0);
      selection = selection.selectItem('a', true);
      assert.strictEqual(selection.getSelectedItems().size, 1);
    });
  });
});
