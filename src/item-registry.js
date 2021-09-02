module.exports = class ItemRegistry {
  constructor() {
    this.items = new WeakSet();
  }

  addItem(item) {
    if (this.hasItem(item)) {
      throw new Error(
        `The workspace can only contain one instance of item ${item}`
      );
    }
    return this.items.add(item);
  }

  removeItem(item) {
    return this.items.delete(item);
  }

  hasItem(item) {
    return this.items.has(item);
  }
};
