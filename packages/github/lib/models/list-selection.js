import {autobind} from '../helpers';

const COPY = Symbol('copy');

export default class ListSelection {
  constructor(options = {}) {
    autobind(this, 'isItemSelectable');

    if (options._copy !== COPY) {
      this.options = {
        isItemSelectable: options.isItemSelectable || (item => !!item),
      };

      this.items = options.items || [];
      this.selections = this.items.length > 0 ? [{head: 0, tail: 0}] : [];
    } else {
      this.options = {
        isItemSelectable: options.isItemSelectable,
      };
      this.items = options.items;
      this.selections = options.selections;
    }
  }

  copy(options = {}) {
    return new ListSelection({
      _copy: COPY,
      isItemSelectable: options.isItemSelectable || this.options.isItemSelectable,
      items: options.items || this.items,
      selections: options.selections || this.selections,
    });
  }

  isItemSelectable(item) {
    return this.options.isItemSelectable(item);
  }

  setItems(items) {
    let newSelectionIndex;
    if (this.selections.length > 0) {
      const [{head, tail}] = this.selections;
      newSelectionIndex = Math.min(head, tail, items.length - 1);
    } else {
      newSelectionIndex = 0;
    }

    const newSelections = items.length > 0 ? [{head: newSelectionIndex, tail: newSelectionIndex}] : [];
    return this.copy({items, selections: newSelections});
  }

  getItems() {
    return this.items;
  }

  getLastItem() {
    return this.items[this.items.length - 1];
  }

  selectFirstItem(preserveTail) {
    for (let i = 0; i < this.items.length; i++) {
      const item = this.items[i];
      if (this.isItemSelectable(item)) {
        return this.selectItem(item, preserveTail);
      }
    }
    return this;
  }

  selectLastItem(preserveTail) {
    for (let i = this.items.length - 1; i > 0; i--) {
      const item = this.items[i];
      if (this.isItemSelectable(item)) {
        return this.selectItem(item, preserveTail);
      }
    }
    return this;
  }

  selectAllItems() {
    return this.selectFirstItem().selectLastItem(true);
  }

  selectNextItem(preserveTail) {
    if (this.selections.length === 0) {
      return this.selectFirstItem();
    }

    let itemIndex = this.selections[0].head;
    let nextItemIndex = itemIndex;
    while (itemIndex < this.items.length - 1) {
      itemIndex++;
      if (this.isItemSelectable(this.items[itemIndex])) {
        nextItemIndex = itemIndex;
        break;
      }
    }

    return this.selectItem(this.items[nextItemIndex], preserveTail);
  }

  selectPreviousItem(preserveTail) {
    if (this.selections.length === 0) {
      return this.selectLastItem();
    }

    let itemIndex = this.selections[0].head;
    let previousItemIndex = itemIndex;

    while (itemIndex > 0) {
      itemIndex--;
      if (this.isItemSelectable(this.items[itemIndex])) {
        previousItemIndex = itemIndex;
        break;
      }
    }

    return this.selectItem(this.items[previousItemIndex], preserveTail);
  }

  selectItem(item, preserveTail, addOrSubtract) {
    if (addOrSubtract && preserveTail) {
      throw new Error('addOrSubtract and preserveTail cannot both be true at the same time');
    }

    const itemIndex = this.items.indexOf(item);
    if (preserveTail && this.selections[0]) {
      const newSelections = [
        {head: itemIndex, tail: this.selections[0].tail, negate: this.selections[0].negate},
        ...this.selections.slice(1),
      ];
      return this.copy({selections: newSelections});
    } else {
      const selection = {head: itemIndex, tail: itemIndex};
      if (addOrSubtract) {
        if (this.getSelectedItems().has(item)) { selection.negate = true; }
        return this.copy({selections: [selection, ...this.selections]});
      } else {
        return this.copy({selections: [selection]});
      }
    }
  }

  addOrSubtractSelection(item) {
    return this.selectItem(item, false, true);
  }

  coalesce() {
    if (this.selections.length === 0) { return this; }

    const mostRecent = this.selections[0];
    let mostRecentStart = Math.min(mostRecent.head, mostRecent.tail);
    let mostRecentEnd = Math.max(mostRecent.head, mostRecent.tail);
    while (mostRecentStart > 0 && !this.isItemSelectable(this.items[mostRecentStart - 1])) {
      mostRecentStart--;
    }
    while (mostRecentEnd < (this.items.length - 1) && !this.isItemSelectable(this.items[mostRecentEnd + 1])) {
      mostRecentEnd++;
    }

    let changed = false;
    const newSelections = [mostRecent];
    for (let i = 1; i < this.selections.length;) {
      const current = this.selections[i];
      const currentStart = Math.min(current.head, current.tail);
      const currentEnd = Math.max(current.head, current.tail);
      if (mostRecentStart <= currentEnd + 1 && currentStart - 1 <= mostRecentEnd) {
        if (mostRecent.negate) {
          if (current.head > current.tail) {
            if (currentEnd > mostRecentEnd) { // suffix
              newSelections.push({tail: mostRecentEnd + 1, head: currentEnd});
            }
            if (currentStart < mostRecentStart) { // prefix
              newSelections.push({tail: currentStart, head: mostRecentStart - 1});
            }
          } else {
            if (currentStart < mostRecentStart) { // prefix
              newSelections.push({head: currentStart, tail: mostRecentStart - 1});
            }
            if (currentEnd > mostRecentEnd) { // suffix
              newSelections.push({head: mostRecentEnd + 1, tail: currentEnd});
            }
          }
          changed = true;
          i++;
        } else {
          mostRecentStart = Math.min(mostRecentStart, currentStart);
          mostRecentEnd = Math.max(mostRecentEnd, currentEnd);
          if (mostRecent.head >= mostRecent.tail) {
            mostRecent.head = mostRecentEnd;
            mostRecent.tail = mostRecentStart;
          } else {
            mostRecent.head = mostRecentStart;
            mostRecent.tail = mostRecentEnd;
          }
          changed = true;
          i++;
        }
      } else {
        newSelections.push(current);
        i++;
      }
    }

    if (mostRecent.negate) {
      changed = true;
      newSelections.shift();
    }

    return changed ? this.copy({selections: newSelections}) : this;
  }

  getSelectedItems() {
    const selectedItems = new Set();
    for (const {head, tail, negate} of this.selections.slice().reverse()) {
      const start = Math.min(head, tail);
      const end = Math.max(head, tail);
      for (let i = start; i <= end; i++) {
        const item = this.items[i];
        if (this.isItemSelectable(item)) {
          if (negate) {
            selectedItems.delete(item);
          } else {
            selectedItems.add(item);
          }
        }
      }
    }
    return selectedItems;
  }

  getHeadItem() {
    return this.selections.length > 0 ? this.items[this.selections[0].head] : null;
  }

  getMostRecentSelectionStartIndex() {
    const selection = this.selections[0];
    return Math.min(selection.head, selection.tail);
  }

  getTailIndex() {
    return this.selections[0] ? this.selections[0].tail : null;
  }
}
