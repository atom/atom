import ListSelection from './list-selection';

const COPY = Symbol('COPY');

export default class CompositeListSelection {
  constructor(options) {
    if (options._copy !== COPY) {
      this.keysBySelection = new Map();
      this.selections = [];
      this.idForItem = options.idForItem || (item => item);
      this.resolveNextUpdatePromise = () => {};
      this.activeSelectionIndex = null;

      for (const [key, items] of options.listsByKey) {
        const selection = new ListSelection({items});
        this.keysBySelection.set(selection, key);
        this.selections.push(selection);

        if (this.activeSelectionIndex === null && selection.getItems().length) {
          this.activeSelectionIndex = this.selections.length - 1;
        }
      }

      if (this.activeSelectionIndex === null) {
        this.activeSelectionIndex = 0;
      }
    } else {
      this.keysBySelection = options.keysBySelection;
      this.selections = options.selections;
      this.idForItem = options.idForItem;
      this.activeSelectionIndex = options.activeSelectionIndex;
      this.resolveNextUpdatePromise = options.resolveNextUpdatePromise;
    }
  }

  copy(options = {}) {
    let selections = [];
    let keysBySelection = new Map();

    if (options.keysBySelection || options.selections) {
      if (!options.keysBySelection || !options.selections) {
        throw new Error('keysBySelection and selection must always be updated simultaneously');
      }

      selections = options.selections;
      keysBySelection = options.keysBySelection;
    } else {
      selections = this.selections;
      keysBySelection = this.keysBySelection;
    }

    return new CompositeListSelection({
      keysBySelection,
      selections,
      activeSelectionIndex: options.activeSelectionIndex !== undefined
        ? options.activeSelectionIndex
        : this.activeSelectionIndex,
      idForItem: options.idForItem || this.idForItem,
      resolveNextUpdatePromise: options.resolveNextUpdatePromise || this.resolveNextUpdatePromise,
      _copy: COPY,
    });
  }

  updateLists(listsByKey) {
    let isDifferent = false;

    if (listsByKey.length === 0) {
      return this;
    }

    const newKeysBySelection = new Map();
    const newSelections = [];

    for (let i = 0; i < listsByKey.length; i++) {
      const [key, newItems] = listsByKey[i];
      let selection = this.selections[i];

      const oldItems = selection.getItems();
      if (!isDifferent) {
        isDifferent = oldItems.length !== newItems.length || oldItems.some((oldItem, j) => oldItem === newItems[j]);
      }

      const oldHeadItem = selection.getHeadItem();
      selection = selection.setItems(newItems);
      let newHeadItem = null;
      if (oldHeadItem) {
        newHeadItem = newItems.find(item => this.idForItem(item) === this.idForItem(oldHeadItem));
      }
      if (newHeadItem) {
        selection = selection.selectItem(newHeadItem);
      }

      newKeysBySelection.set(selection, key);
      newSelections.push(selection);
    }

    let updated = this.copy({
      keysBySelection: newKeysBySelection,
      selections: newSelections,
    });

    if (updated.getActiveSelection().getItems().length === 0) {
      const next = updated.activateNextSelection();
      updated = next !== updated ? next : updated.activatePreviousSelection();
    }

    updated.resolveNextUpdatePromise();
    return updated;
  }

  updateActiveSelection(fn) {
    const oldSelection = this.getActiveSelection();
    const newSelection = fn(oldSelection);
    if (oldSelection === newSelection) {
      return this;
    }

    const key = this.keysBySelection.get(oldSelection);

    const newKeysBySelection = new Map(this.keysBySelection);
    newKeysBySelection.delete(oldSelection);
    newKeysBySelection.set(newSelection, key);

    const newSelections = this.selections.slice();
    newSelections[this.activeSelectionIndex] = newSelection;

    return this.copy({
      keysBySelection: newKeysBySelection,
      selections: newSelections,
    });
  }

  getNextUpdatePromise() {
    return new Promise((resolve, reject) => {
      this.resolveNextUpdatePromise = resolve;
    });
  }

  selectFirstNonEmptyList() {
    return this.copy({
      activeSelectionIndex: this.selections.findIndex(selection => selection.getItems().length > 0),
    });
  }

  getActiveListKey() {
    return this.keysBySelection.get(this.getActiveSelection());
  }

  getSelectedItems() {
    return this.getActiveSelection().getSelectedItems();
  }

  getHeadItem() {
    return this.getActiveSelection().getHeadItem();
  }

  getActiveSelection() {
    return this.selections[this.activeSelectionIndex];
  }

  activateSelection(selection) {
    const index = this.selections.indexOf(selection);
    if (index === -1) { throw new Error('Selection not found'); }
    return this.copy({activeSelectionIndex: index});
  }

  activateNextSelection() {
    for (let i = this.activeSelectionIndex + 1; i < this.selections.length; i++) {
      if (this.selections[i].getItems().length > 0) {
        return this.copy({activeSelectionIndex: i});
      }
    }
    return this;
  }

  activatePreviousSelection() {
    for (let i = this.activeSelectionIndex - 1; i >= 0; i--) {
      if (this.selections[i].getItems().length > 0) {
        return this.copy({activeSelectionIndex: i});
      }
    }
    return this;
  }

  activateLastSelection() {
    for (let i = this.selections.length - 1; i >= 0; i--) {
      if (this.selections[i].getItems().length > 0) {
        return this.copy({activeSelectionIndex: i});
      }
    }
    return this;
  }

  selectItem(item, preserveTail = false) {
    const selection = this.selectionForItem(item);
    if (!selection) {
      throw new Error(`No item found: ${item}`);
    }

    let next = this;
    if (!preserveTail) {
      next = next.activateSelection(selection);
    }
    if (selection === next.getActiveSelection()) {
      next = next.updateActiveSelection(s => s.selectItem(item, preserveTail));
    }
    return next;
  }

  addOrSubtractSelection(item) {
    const selection = this.selectionForItem(item);
    if (!selection) {
      throw new Error(`No item found: ${item}`);
    }

    if (selection === this.getActiveSelection()) {
      return this.updateActiveSelection(s => s.addOrSubtractSelection(item));
    } else {
      return this.activateSelection(selection).updateActiveSelection(s => s.selectItem(item));
    }
  }

  selectAllItems() {
    return this.updateActiveSelection(s => s.selectAllItems());
  }

  selectFirstItem(preserveTail) {
    return this.updateActiveSelection(s => s.selectFirstItem(preserveTail));
  }

  selectLastItem(preserveTail) {
    return this.updateActiveSelection(s => s.selectLastItem(preserveTail));
  }

  coalesce() {
    return this.updateActiveSelection(s => s.coalesce());
  }

  selectionForItem(item) {
    return this.selections.find(selection => selection.getItems().includes(item));
  }

  listKeyForItem(item) {
    return this.keysBySelection.get(this.selectionForItem(item));
  }

  selectNextItem(preserveTail = false) {
    let next = this;
    if (!preserveTail && next.getActiveSelection().getHeadItem() === next.getActiveSelection().getLastItem()) {
      next = next.activateNextSelection();
      if (next !== this) {
        return next.updateActiveSelection(s => s.selectFirstItem());
      } else {
        return next.updateActiveSelection(s => s.selectLastItem());
      }
    } else {
      return next.updateActiveSelection(s => s.selectNextItem(preserveTail));
    }
  }

  selectPreviousItem(preserveTail = false) {
    let next = this;
    if (!preserveTail && next.getActiveSelection().getHeadItem() === next.getActiveSelection().getItems()[0]) {
      next = next.activatePreviousSelection();
      if (next !== this) {
        return next.updateActiveSelection(s => s.selectLastItem());
      } else {
        return next.updateActiveSelection(s => s.selectFirstItem());
      }
    } else {
      return next.updateActiveSelection(s => s.selectPreviousItem(preserveTail));
    }
  }

  findItem(predicate) {
    for (let i = 0; i < this.selections.length; i++) {
      const selection = this.selections[i];
      const key = this.keysBySelection.get(selection);
      const found = selection.getItems().find(item => predicate(item, key));
      if (found !== undefined) {
        return found;
      }
    }
    return null;
  }
}
