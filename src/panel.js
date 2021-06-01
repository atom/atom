const { Emitter } = require('event-kit');

// Extended: A container representing a panel on the edges of the editor window.
// You should not create a `Panel` directly, instead use {Workspace::addTopPanel}
// and friends to add panels.
//
// Examples: [status-bar](https://github.com/atom/status-bar)
// and [find-and-replace](https://github.com/atom/find-and-replace) both use
// panels.
module.exports = class Panel {
  /*
  Section: Construction and Destruction
  */

  constructor({ item, autoFocus, visible, priority, className }, viewRegistry) {
    this.destroyed = false;
    this.item = item;
    this.autoFocus = autoFocus == null ? false : autoFocus;
    this.visible = visible == null ? true : visible;
    this.priority = priority == null ? 100 : priority;
    this.className = className;
    this.viewRegistry = viewRegistry;
    this.emitter = new Emitter();
  }

  // Public: Destroy and remove this panel from the UI.
  destroy() {
    if (this.destroyed) return;
    this.destroyed = true;
    this.hide();
    if (this.element) this.element.remove();
    this.emitter.emit('did-destroy', this);
    return this.emitter.dispose();
  }

  getElement() {
    if (!this.element) {
      this.element = document.createElement('atom-panel');
      if (!this.visible) this.element.style.display = 'none';
      if (this.className)
        this.element.classList.add(...this.className.split(' '));
      this.element.appendChild(this.viewRegistry.getView(this.item));
    }
    return this.element;
  }

  /*
  Section: Event Subscription
  */

  // Public: Invoke the given callback when the pane hidden or shown.
  //
  // * `callback` {Function} to be called when the pane is destroyed.
  //   * `visible` {Boolean} true when the panel has been shown
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeVisible(callback) {
    return this.emitter.on('did-change-visible', callback);
  }

  // Public: Invoke the given callback when the pane is destroyed.
  //
  // * `callback` {Function} to be called when the pane is destroyed.
  //   * `panel` {Panel} this panel
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy(callback) {
    return this.emitter.once('did-destroy', callback);
  }

  /*
  Section: Panel Details
  */

  // Public: Returns the panel's item.
  getItem() {
    return this.item;
  }

  // Public: Returns a {Number} indicating this panel's priority.
  getPriority() {
    return this.priority;
  }

  getClassName() {
    return this.className;
  }

  // Public: Returns a {Boolean} true when the panel is visible.
  isVisible() {
    return this.visible;
  }

  // Public: Hide this panel
  hide() {
    let wasVisible = this.visible;
    this.visible = false;
    if (this.element) this.element.style.display = 'none';
    if (wasVisible) this.emitter.emit('did-change-visible', this.visible);
  }

  // Public: Show this panel
  show() {
    let wasVisible = this.visible;
    this.visible = true;
    if (this.element) this.element.style.display = null;
    if (!wasVisible) this.emitter.emit('did-change-visible', this.visible);
  }
};
