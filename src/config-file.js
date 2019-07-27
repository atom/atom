const _ = require('underscore-plus');
const fs = require('fs-plus');
const dedent = require('dedent');
const { Disposable, Emitter } = require('event-kit');
const { watchPath } = require('./path-watcher');
const CSON = require('season');
const Path = require('path');
const async = require('async');

const EVENT_TYPES = new Set(['created', 'modified', 'renamed']);

module.exports = class ConfigFile {
  static at(path) {
    if (!this._known) {
      this._known = new Map();
    }

    const existing = this._known.get(path);
    if (existing) {
      return existing;
    }

    const created = new ConfigFile(path);
    this._known.set(path, created);
    return created;
  }

  constructor(path) {
    this.path = path;
    this.emitter = new Emitter();
    this.value = {};
    this.reloadCallbacks = [];

    // Use a queue to prevent multiple concurrent write to the same file.
    const writeQueue = async.queue((data, callback) =>
      CSON.writeFile(this.path, data, error => {
        if (error) {
          this.emitter.emit(
            'did-error',
            dedent`
            Failed to write \`${Path.basename(this.path)}\`.

            ${error.message}
          `
          );
        }
        callback();
      })
    );

    this.requestLoad = _.debounce(() => this.reload(), 200);
    this.requestSave = _.debounce(data => writeQueue.push(data), 200);
  }

  get() {
    return this.value;
  }

  update(value) {
    return new Promise(resolve => {
      this.requestSave(value);
      this.reloadCallbacks.push(resolve);
    });
  }

  async watch(callback) {
    if (!fs.existsSync(this.path)) {
      fs.makeTreeSync(Path.dirname(this.path));
      CSON.writeFileSync(this.path, {}, { flag: 'wx' });
    }

    await this.reload();

    try {
      return await watchPath(this.path, {}, events => {
        if (events.some(event => EVENT_TYPES.has(event.action)))
          this.requestLoad();
      });
    } catch (error) {
      this.emitter.emit(
        'did-error',
        dedent`
        Unable to watch path: \`${Path.basename(this.path)}\`.

        Make sure you have permissions to \`${this.path}\`.
        On linux there are currently problems with watch sizes.
        See [this document][watches] for more info.

        [watches]:https://github.com/atom/atom/blob/master/docs/build-instructions/linux.md#typeerror-unable-to-watch-path\
      `
      );
      return new Disposable();
    }
  }

  onDidChange(callback) {
    return this.emitter.on('did-change', callback);
  }

  onDidError(callback) {
    return this.emitter.on('did-error', callback);
  }

  reload() {
    return new Promise(resolve => {
      CSON.readFile(this.path, (error, data) => {
        if (error) {
          this.emitter.emit(
            'did-error',
            `Failed to load \`${Path.basename(this.path)}\` - ${error.message}`
          );
        } else {
          this.value = data || {};
          this.emitter.emit('did-change', this.value);

          for (const callback of this.reloadCallbacks) callback();
          this.reloadCallbacks.length = 0;
        }
        resolve();
      });
    });
  }
};
