const { Emitter } = require('event-kit');
const Gutter = require('./gutter');

module.exports = class GutterContainer {
  constructor(textEditor) {
    this.gutters = [];
    this.textEditor = textEditor;
    this.emitter = new Emitter();
  }

  scheduleComponentUpdate() {
    this.textEditor.scheduleComponentUpdate();
  }

  destroy() {
    // Create a copy, because `Gutter::destroy` removes the gutter from
    // GutterContainer's @gutters.
    const guttersToDestroy = this.gutters.slice(0);
    for (let gutter of guttersToDestroy) {
      if (gutter.name !== 'line-number') {
        gutter.destroy();
      }
    }
    this.gutters = [];
    this.emitter.dispose();
  }

  addGutter(options) {
    options = options || {};
    const gutterName = options.name;
    if (gutterName === null) {
      throw new Error('A name is required to create a gutter.');
    }
    if (this.gutterWithName(gutterName)) {
      throw new Error(
        'Tried to create a gutter with a name that is already in use.'
      );
    }
    const newGutter = new Gutter(this, options);

    let inserted = false;
    // Insert the gutter into the gutters array, sorted in ascending order by 'priority'.
    // This could be optimized, but there are unlikely to be many gutters.
    for (let i = 0; i < this.gutters.length; i++) {
      if (this.gutters[i].priority >= newGutter.priority) {
        this.gutters.splice(i, 0, newGutter);
        inserted = true;
        break;
      }
    }
    if (!inserted) {
      this.gutters.push(newGutter);
    }
    this.scheduleComponentUpdate();
    this.emitter.emit('did-add-gutter', newGutter);
    return newGutter;
  }

  getGutters() {
    return this.gutters.slice();
  }

  gutterWithName(name) {
    for (let gutter of this.gutters) {
      if (gutter.name === name) {
        return gutter;
      }
    }
    return null;
  }

  observeGutters(callback) {
    for (let gutter of this.getGutters()) {
      callback(gutter);
    }
    return this.onDidAddGutter(callback);
  }

  onDidAddGutter(callback) {
    return this.emitter.on('did-add-gutter', callback);
  }

  onDidRemoveGutter(callback) {
    return this.emitter.on('did-remove-gutter', callback);
  }

  /*
  Section: Private Methods
  */

  // Processes the destruction of the gutter. Throws an error if this gutter is
  // not within this gutterContainer.
  removeGutter(gutter) {
    const index = this.gutters.indexOf(gutter);
    if (index > -1) {
      this.gutters.splice(index, 1);
      this.scheduleComponentUpdate();
      this.emitter.emit('did-remove-gutter', gutter.name);
    } else {
      throw new Error(
        'The given gutter cannot be removed because it is not ' +
          'within this GutterContainer.'
      );
    }
  }

  // The public interface is Gutter::decorateMarker or TextEditor::decorateMarker.
  addGutterDecoration(gutter, marker, options) {
    if (gutter.type === 'line-number') {
      options.type = 'line-number';
    } else {
      options.type = 'gutter';
    }
    options.gutterName = gutter.name;
    return this.textEditor.decorateMarker(marker, options);
  }
};
