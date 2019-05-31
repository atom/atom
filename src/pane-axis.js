const { Emitter, CompositeDisposable } = require('event-kit');
const { flatten } = require('underscore-plus');
const Model = require('./model');
const PaneAxisElement = require('./pane-axis-element');

class PaneAxis extends Model {
  static deserialize(state, { deserializers, views }) {
    state.children = state.children.map(childState =>
      deserializers.deserialize(childState)
    );
    return new PaneAxis(state, views);
  }

  constructor({ orientation, children, flexScale }, viewRegistry) {
    super();
    this.parent = null;
    this.container = null;
    this.orientation = orientation;
    this.viewRegistry = viewRegistry;
    this.emitter = new Emitter();
    this.subscriptionsByChild = new WeakMap();
    this.subscriptions = new CompositeDisposable();
    this.flexScale = flexScale != null ? flexScale : 1;
    this.children = [];
    if (children) {
      for (let child of children) {
        this.addChild(child);
      }
    }
  }

  serialize() {
    return {
      deserializer: 'PaneAxis',
      children: this.children.map(child => child.serialize()),
      orientation: this.orientation,
      flexScale: this.flexScale
    };
  }

  getElement() {
    if (!this.element) {
      this.element = new PaneAxisElement().initialize(this, this.viewRegistry);
    }
    return this.element;
  }

  getFlexScale() {
    return this.flexScale;
  }

  setFlexScale(flexScale) {
    this.flexScale = flexScale;
    this.emitter.emit('did-change-flex-scale', this.flexScale);
    return this.flexScale;
  }

  getParent() {
    return this.parent;
  }

  setParent(parent) {
    this.parent = parent;
    return this.parent;
  }

  getContainer() {
    return this.container;
  }

  setContainer(container) {
    if (container && container !== this.container) {
      this.container = container;
      this.children.forEach(child => child.setContainer(container));
    }
  }

  getOrientation() {
    return this.orientation;
  }

  getChildren() {
    return this.children.slice();
  }

  getPanes() {
    return flatten(this.children.map(child => child.getPanes()));
  }

  getItems() {
    return flatten(this.children.map(child => child.getItems()));
  }

  onDidAddChild(fn) {
    return this.emitter.on('did-add-child', fn);
  }

  onDidRemoveChild(fn) {
    return this.emitter.on('did-remove-child', fn);
  }

  onDidReplaceChild(fn) {
    return this.emitter.on('did-replace-child', fn);
  }

  onDidDestroy(fn) {
    return this.emitter.once('did-destroy', fn);
  }

  onDidChangeFlexScale(fn) {
    return this.emitter.on('did-change-flex-scale', fn);
  }

  observeFlexScale(fn) {
    fn(this.flexScale);
    return this.onDidChangeFlexScale(fn);
  }

  addChild(child, index = this.children.length) {
    this.children.splice(index, 0, child);
    child.setParent(this);
    child.setContainer(this.container);
    this.subscribeToChild(child);
    return this.emitter.emit('did-add-child', { child, index });
  }

  adjustFlexScale() {
    // get current total flex scale of children
    let total = 0;
    for (var child of this.children) {
      total += child.getFlexScale();
    }

    const needTotal = this.children.length;
    // set every child's flex scale by the ratio
    for (child of this.children) {
      child.setFlexScale((needTotal * child.getFlexScale()) / total);
    }
  }

  removeChild(child, replacing = false) {
    const index = this.children.indexOf(child);
    if (index === -1) {
      throw new Error('Removing non-existent child');
    }

    this.unsubscribeFromChild(child);

    this.children.splice(index, 1);
    this.adjustFlexScale();
    this.emitter.emit('did-remove-child', { child, index });
    if (!replacing && this.children.length < 2) {
      this.reparentLastChild();
    }
  }

  replaceChild(oldChild, newChild) {
    this.unsubscribeFromChild(oldChild);
    this.subscribeToChild(newChild);

    newChild.setParent(this);
    newChild.setContainer(this.container);

    const index = this.children.indexOf(oldChild);
    this.children.splice(index, 1, newChild);
    this.emitter.emit('did-replace-child', { oldChild, newChild, index });
  }

  insertChildBefore(currentChild, newChild) {
    const index = this.children.indexOf(currentChild);
    return this.addChild(newChild, index);
  }

  insertChildAfter(currentChild, newChild) {
    const index = this.children.indexOf(currentChild);
    return this.addChild(newChild, index + 1);
  }

  reparentLastChild() {
    const lastChild = this.children[0];
    lastChild.setFlexScale(this.flexScale);
    this.parent.replaceChild(this, lastChild);
    this.destroy();
  }

  subscribeToChild(child) {
    const subscription = child.onDidDestroy(() => this.removeChild(child));
    this.subscriptionsByChild.set(child, subscription);
    this.subscriptions.add(subscription);
  }

  unsubscribeFromChild(child) {
    const subscription = this.subscriptionsByChild.get(child);
    this.subscriptions.remove(subscription);
    subscription.dispose();
  }

  destroyed() {
    this.subscriptions.dispose();
    this.emitter.emit('did-destroy');
    this.emitter.dispose();
  }
}

module.exports = PaneAxis;
