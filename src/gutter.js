const { Emitter } = require('event-kit');

const DefaultPriority = -100;

// Extended: Represents a gutter within a {TextEditor}.
//
// See {TextEditor::addGutter} for information on creating a gutter.
module.exports = class Gutter {
  constructor(gutterContainer, options) {
    this.gutterContainer = gutterContainer;
    this.name = options && options.name;
    this.priority =
      options && options.priority != null ? options.priority : DefaultPriority;
    this.visible = options && options.visible != null ? options.visible : true;
    this.type = options && options.type != null ? options.type : 'decorated';
    this.labelFn = options && options.labelFn;
    this.className = options && options.class;

    this.onMouseDown = options && options.onMouseDown;
    this.onMouseMove = options && options.onMouseMove;

    this.emitter = new Emitter();
  }

  /*
  Section: Gutter Destruction
  */

  // Essential: Destroys the gutter.
  destroy() {
    if (this.name === 'line-number') {
      throw new Error('The line-number gutter cannot be destroyed.');
    } else {
      this.gutterContainer.removeGutter(this);
      this.emitter.emit('did-destroy');
      this.emitter.dispose();
    }
  }

  /*
  Section: Event Subscription
  */

  // Essential: Calls your `callback` when the gutter's visibility changes.
  //
  // * `callback` {Function}
  //  * `gutter` The gutter whose visibility changed.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeVisible(callback) {
    return this.emitter.on('did-change-visible', callback);
  }

  // Essential: Calls your `callback` when the gutter is destroyed.
  //
  // * `callback` {Function}
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy(callback) {
    return this.emitter.once('did-destroy', callback);
  }

  /*
  Section: Visibility
  */

  // Essential: Hide the gutter.
  hide() {
    if (this.visible) {
      this.visible = false;
      this.gutterContainer.scheduleComponentUpdate();
      this.emitter.emit('did-change-visible', this);
    }
  }

  // Essential: Show the gutter.
  show() {
    if (!this.visible) {
      this.visible = true;
      this.gutterContainer.scheduleComponentUpdate();
      this.emitter.emit('did-change-visible', this);
    }
  }

  // Essential: Determine whether the gutter is visible.
  //
  // Returns a {Boolean}.
  isVisible() {
    return this.visible;
  }

  // Essential: Add a decoration that tracks a {DisplayMarker}. When the marker moves,
  // is invalidated, or is destroyed, the decoration will be updated to reflect
  // the marker's state.
  //
  // ## Arguments
  //
  // * `marker` A {DisplayMarker} you want this decoration to follow.
  // * `decorationParams` An {Object} representing the decoration. It is passed
  //   to {TextEditor::decorateMarker} as its `decorationParams` and so supports
  //   all options documented there.
  //   * `type` __Caveat__: set to `'line-number'` if this is the line-number
  //     gutter, `'gutter'` otherwise. This cannot be overridden.
  //
  // Returns a {Decoration} object
  decorateMarker(marker, options) {
    return this.gutterContainer.addGutterDecoration(this, marker, options);
  }

  getElement() {
    if (this.element == null) this.element = document.createElement('div');
    return this.element;
  }
};
