// We won't have access to es_natives.js here, so this means we have to provide
// them ourselves. The best way we can overcome this is to avoid using such
// functions wherever possible.
//Object.prototype.toString = function() {
//  return "[object " + typeof this + "]";
//};

var snapshotGlobal = {};
var cachedFunctions = {
  "./view-registry": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var Disposable, Grim, ViewRegistry, find, _,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  find = require('underscore-plus').find;

  Grim = require('grim');

  Disposable = require('event-kit').Disposable;

  _ = require('underscore-plus');

  module.exports = ViewRegistry = (function() {
    ViewRegistry.prototype.documentUpdateRequested = false;

    ViewRegistry.prototype.documentReadInProgress = false;

    ViewRegistry.prototype.performDocumentPollAfterUpdate = false;

    ViewRegistry.prototype.debouncedPerformDocumentPoll = null;

    ViewRegistry.prototype.minimumPollInterval = 200;

    function ViewRegistry(atomEnvironment) {
      this.atomEnvironment = atomEnvironment;
      this.requestDocumentPoll = __bind(this.requestDocumentPoll, this);
      this.performDocumentUpdate = __bind(this.performDocumentUpdate, this);
      this.observer = new MutationObserver(this.requestDocumentPoll);
      this.clear();
    }

    ViewRegistry.prototype.clear = function() {
      this.views = new WeakMap;
      this.providers = [];
      this.debouncedPerformDocumentPoll = _.throttle(this.performDocumentPoll, this.minimumPollInterval).bind(this);
      return this.clearDocumentRequests();
    };

    ViewRegistry.prototype.addViewProvider = function(modelConstructor, createView) {
      var provider;
      if (arguments.length === 1) {
        Grim.deprecate("atom.views.addViewProvider now takes 2 arguments: a model constructor and a createView function. See docs for details.");
        provider = modelConstructor;
      } else {
        provider = {
          modelConstructor: modelConstructor,
          createView: createView
        };
      }
      this.providers.push(provider);
      return new Disposable((function(_this) {
        return function() {
          return _this.providers = _this.providers.filter(function(p) {
            return p !== provider;
          });
        };
      })(this));
    };

    ViewRegistry.prototype.getView = function(object) {
      var view;
      if (object == null) {
        return;
      }
      if (view = this.views.get(object)) {
        return view;
      } else {
        view = this.createView(object);
        this.views.set(object, view);
        return view;
      }
    };

    ViewRegistry.prototype.createView = function(object) {
      var element, provider, view, viewConstructor, _ref;
      if (object instanceof HTMLElement) {
        return object;
      } else if ((object != null ? object.element : void 0) instanceof HTMLElement) {
        return object.element;
      } else if (object != null ? object.jquery : void 0) {
        return object[0];
      } else if (provider = this.findProvider(object)) {
        element = typeof provider.createView === "function" ? provider.createView(object, this.atomEnvironment) : void 0;
        if (element == null) {
          element = new provider.viewConstructor;
                    if ((_ref = typeof element.initialize === "function" ? element.initialize(object) : void 0) != null) {
            _ref;
          } else {
            if (typeof element.setModel === "function") {
              element.setModel(object);
            }
          };
        }
        return element;
      } else if (viewConstructor = object != null ? typeof object.getViewClass === "function" ? object.getViewClass() : void 0 : void 0) {
        view = new viewConstructor(object);
        return view[0];
      } else {
        throw new Error("Can't create a view for " + object.constructor.name + " instance. Please register a view provider.");
      }
    };

    ViewRegistry.prototype.findProvider = function(object) {
      return find(this.providers, function(_arg) {
        var modelConstructor;
        modelConstructor = _arg.modelConstructor;
        return object instanceof modelConstructor;
      });
    };

    ViewRegistry.prototype.updateDocument = function(fn) {
      this.documentWriters.push(fn);
      if (!this.documentReadInProgress) {
        this.requestDocumentUpdate();
      }
      return new Disposable((function(_this) {
        return function() {
          return _this.documentWriters = _this.documentWriters.filter(function(writer) {
            return writer !== fn;
          });
        };
      })(this));
    };

    ViewRegistry.prototype.readDocument = function(fn) {
      this.documentReaders.push(fn);
      this.requestDocumentUpdate();
      return new Disposable((function(_this) {
        return function() {
          return _this.documentReaders = _this.documentReaders.filter(function(reader) {
            return reader !== fn;
          });
        };
      })(this));
    };

    ViewRegistry.prototype.pollDocument = function(fn) {
      if (this.documentPollers.length === 0) {
        this.startPollingDocument();
      }
      this.documentPollers.push(fn);
      return new Disposable((function(_this) {
        return function() {
          _this.documentPollers = _this.documentPollers.filter(function(poller) {
            return poller !== fn;
          });
          if (_this.documentPollers.length === 0) {
            return _this.stopPollingDocument();
          }
        };
      })(this));
    };

    ViewRegistry.prototype.pollAfterNextUpdate = function() {
      return this.performDocumentPollAfterUpdate = true;
    };

    ViewRegistry.prototype.clearDocumentRequests = function() {
      this.documentReaders = [];
      this.documentWriters = [];
      this.documentPollers = [];
      this.documentUpdateRequested = false;
      return this.stopPollingDocument();
    };

    ViewRegistry.prototype.requestDocumentUpdate = function() {
      if (!this.documentUpdateRequested) {
        this.documentUpdateRequested = true;
        return requestAnimationFrame(this.performDocumentUpdate);
      }
    };

    ViewRegistry.prototype.performDocumentUpdate = function() {
      var reader, writer, _results;
      this.documentUpdateRequested = false;
      while (writer = this.documentWriters.shift()) {
        writer();
      }
      this.documentReadInProgress = true;
      while (reader = this.documentReaders.shift()) {
        reader();
      }
      if (this.performDocumentPollAfterUpdate) {
        this.performDocumentPoll();
      }
      this.performDocumentPollAfterUpdate = false;
      this.documentReadInProgress = false;
      _results = [];
      while (writer = this.documentWriters.shift()) {
        _results.push(writer());
      }
      return _results;
    };

    ViewRegistry.prototype.startPollingDocument = function() {
      window.addEventListener('resize', this.requestDocumentPoll);
      return this.observer.observe(document, {
        subtree: true,
        childList: true,
        attributes: true
      });
    };

    ViewRegistry.prototype.stopPollingDocument = function() {
      window.removeEventListener('resize', this.requestDocumentPoll);
      return this.observer.disconnect();
    };

    ViewRegistry.prototype.requestDocumentPoll = function() {
      if (this.documentUpdateRequested) {
        return this.performDocumentPollAfterUpdate = true;
      } else {
        return this.debouncedPerformDocumentPoll();
      }
    };

    ViewRegistry.prototype.performDocumentPoll = function() {
      var poller, _i, _len, _ref;
      _ref = this.documentPollers;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        poller = _ref[_i];
        poller();
      }
    };

    return ViewRegistry;

  })();

}).call(this);

}),
  "./storage-folder": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var StorageFolder, fs, path;

  path = null;

  fs = null;

  module.exports = StorageFolder = (function() {
    function StorageFolder(containingPath) {
      if (path == null) {
        path = require("path");
      }
      if (fs == null) {
        fs = require("fs-plus");
      }
      if (containingPath != null) {
        this.path = path.join(containingPath, "storage");
      }
    }

    StorageFolder.prototype.store = function(name, object) {
      if (this.path == null) {
        return;
      }
      return fs.writeFileSync(this.pathForKey(name), JSON.stringify(object), 'utf8');
    };

    StorageFolder.prototype.load = function(name) {
      var error, statePath, stateString;
      if (this.path == null) {
        return;
      }
      statePath = this.pathForKey(name);
      try {
        stateString = fs.readFileSync(statePath, 'utf8');
      } catch (_error) {
        error = _error;
        if (error.code !== 'ENOENT') {
          console.warn("Error reading state file: " + statePath, error.stack, error);
        }
        return void 0;
      }
      try {
        return JSON.parse(stateString);
      } catch (_error) {
        error = _error;
        return console.warn("Error parsing state file: " + statePath, error.stack, error);
      }
    };

    StorageFolder.prototype.pathForKey = function(name) {
      return path.join(this.getPath(), name);
    };

    StorageFolder.prototype.getPath = function() {
      return this.path;
    };

    return StorageFolder;

  })();

}).call(this);

}),
  "text-buffer": (function (exports, require, module, __filename, __dirname, process, global) {
    (function() {
  var CompositeDisposable, Emitter, File, Grim, History, MarkerStore, MatchIterator, Patch, Point, Range, SearchCallbackArgument, Serializable, SpanSkipList, TextBuffer, TransactionAbortedError, diff, fs, newlineRegex, path, spliceArray, _, _ref, _ref1,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  Grim = require('grim');

  Serializable = require('serializable');

  _ref = require('event-kit'), Emitter = _ref.Emitter, CompositeDisposable = _ref.CompositeDisposable;

  File = null;

  fs = null;

  path = null;

  SpanSkipList = require('span-skip-list');

  diff = require('atom-diff');

  _ = require('underscore-plus');

  Point = require('./point');

  Range = require('./range');

  History = require('./history');

  MarkerStore = require('./marker-store');

  Patch = require('./patch');

  MatchIterator = require('./match-iterator');

  _ref1 = require('./helpers'), spliceArray = _ref1.spliceArray, newlineRegex = _ref1.newlineRegex;

  SearchCallbackArgument = (function() {
    Object.defineProperty(SearchCallbackArgument.prototype, "range", {
      get: function() {
        var endPosition, matchEndIndex, matchStartIndex, startPosition;
        if (this.computedRange != null) {
          return this.computedRange;
        }
        matchStartIndex = this.match.index;
        matchEndIndex = matchStartIndex + this.matchText.length;
        startPosition = this.buffer.positionForCharacterIndex(matchStartIndex + this.lengthDelta);
        endPosition = this.buffer.positionForCharacterIndex(matchEndIndex + this.lengthDelta);
        return this.computedRange = new Range(startPosition, endPosition);
      },
      set: function(range) {
        return this.computedRange = range;
      }
    });

    function SearchCallbackArgument(buffer, match, lengthDelta) {
      this.buffer = buffer;
      this.match = match;
      this.lengthDelta = lengthDelta;
      this.stop = __bind(this.stop, this);
      this.replace = __bind(this.replace, this);
      this.stopped = false;
      this.replacementText = null;
      this.matchText = this.match[0];
    }

    SearchCallbackArgument.prototype.getReplacementDelta = function() {
      if (this.replacementText == null) {
        return 0;
      }
      return this.replacementText.length - this.matchText.length;
    };

    SearchCallbackArgument.prototype.replace = function(text) {
      this.replacementText = text;
      return this.buffer.setTextInRange(this.range, this.replacementText);
    };

    SearchCallbackArgument.prototype.stop = function() {
      return this.stopped = true;
    };

    SearchCallbackArgument.prototype.keepLooping = function() {
      return this.stopped === false;
    };

    return SearchCallbackArgument;

  })();

  TransactionAbortedError = (function(_super) {
    __extends(TransactionAbortedError, _super);

    function TransactionAbortedError() {
      TransactionAbortedError.__super__.constructor.apply(this, arguments);
    }

    return TransactionAbortedError;

  })(Error);

  module.exports = TextBuffer = (function() {
    TextBuffer.version = 2;

    TextBuffer.Point = Point;

    TextBuffer.Range = Range;

    TextBuffer.Patch = Patch;

    TextBuffer.newlineRegex = newlineRegex;

    Serializable.includeInto(TextBuffer);

    TextBuffer.prototype.cachedText = null;

    TextBuffer.prototype.encoding = null;

    TextBuffer.prototype.stoppedChangingDelay = 300;

    TextBuffer.prototype.stoppedChangingTimeout = null;

    TextBuffer.prototype.cachedDiskContents = null;

    TextBuffer.prototype.conflict = false;

    TextBuffer.prototype.file = null;

    TextBuffer.prototype.refcount = 0;

    TextBuffer.prototype.fileSubscriptions = null;

    TextBuffer.prototype.backwardsScanChunkSize = 8000;

    TextBuffer.prototype.defaultMaxUndoEntries = 10000;

    TextBuffer.prototype.changeCount = 0;


    /*
    Section: Construction
     */

    function TextBuffer(params) {
      var maxUndoEntries, text, _ref2, _ref3, _ref4, _ref5, _ref6;
      if (File == null) {
        File = (require('pathwatcher')).File;
      }
      if (fs == null) {
        fs = require('fs-plus');
      }
      if (path == null) {
        path = require('path');
      }
      if (typeof params === 'string') {
        text = params;
      }
      this.emitter = new Emitter;
      this.lines = [''];
      this.lineEndings = [''];
      this.offsetIndex = new SpanSkipList('rows', 'characters');
      this.setTextInRange([[0, 0], [0, 0]], (_ref2 = text != null ? text : params != null ? params.text : void 0) != null ? _ref2 : '', {
        normalizeLineEndings: false
      });
      maxUndoEntries = (_ref3 = params != null ? params.maxUndoEntries : void 0) != null ? _ref3 : this.defaultMaxUndoEntries;
      this.history = (_ref4 = params != null ? params.history : void 0) != null ? _ref4 : new History(this, maxUndoEntries);
      this.markerStore = (_ref5 = params != null ? params.markerStore : void 0) != null ? _ref5 : new MarkerStore(this);
      this.setEncoding(params != null ? params.encoding : void 0);
      this.setPreferredLineEnding(params != null ? params.preferredLineEnding : void 0);
      this.loaded = false;
      this.transactCallDepth = 0;
      this.digestWhenLastPersisted = (_ref6 = params != null ? params.digestWhenLastPersisted : void 0) != null ? _ref6 : false;
      if (params != null ? params.filePath : void 0) {
        this.setPath(params.filePath);
      }
      if (params != null ? params.load : void 0) {
        this.load();
      }
    }

    TextBuffer.prototype.deserializeParams = function(params) {
      params.markerStore = MarkerStore.deserialize(this, params.markerStore);
      params.history = History.deserialize(this, params.history);
      if (params.filePath) {
        params.load = true;
      }
      return params;
    };

    TextBuffer.prototype.serializeParams = function() {
      var _ref2;
      return {
        text: this.getText(),
        markerStore: this.markerStore.serialize(),
        history: this.history.serialize(),
        encoding: this.getEncoding(),
        filePath: this.getPath(),
        digestWhenLastPersisted: (_ref2 = this.file) != null ? _ref2.getDigestSync() : void 0,
        preferredLineEnding: this.preferredLineEnding
      };
    };


    /*
    Section: Event Subscription
     */

    TextBuffer.prototype.onWillChange = function(callback) {
      return this.emitter.on('will-change', callback);
    };

    TextBuffer.prototype.onDidChange = function(callback) {
      return this.emitter.on('did-change', callback);
    };

    TextBuffer.prototype.preemptDidChange = function(callback) {
      return this.emitter.preempt('did-change', callback);
    };

    TextBuffer.prototype.onDidStopChanging = function(callback) {
      return this.emitter.on('did-stop-changing', callback);
    };

    TextBuffer.prototype.onDidConflict = function(callback) {
      return this.emitter.on('did-conflict', callback);
    };

    TextBuffer.prototype.onDidChangeModified = function(callback) {
      return this.emitter.on('did-change-modified', callback);
    };

    TextBuffer.prototype.onDidUpdateMarkers = function(callback) {
      return this.emitter.on('did-update-markers', callback);
    };

    TextBuffer.prototype.onDidCreateMarker = function(callback) {
      return this.emitter.on('did-create-marker', callback);
    };

    TextBuffer.prototype.onDidChangePath = function(callback) {
      return this.emitter.on('did-change-path', callback);
    };

    TextBuffer.prototype.onDidChangeEncoding = function(callback) {
      return this.emitter.on('did-change-encoding', callback);
    };

    TextBuffer.prototype.onWillSave = function(callback) {
      return this.emitter.on('will-save', callback);
    };

    TextBuffer.prototype.onDidSave = function(callback) {
      return this.emitter.on('did-save', callback);
    };

    TextBuffer.prototype.onDidDelete = function(callback) {
      return this.emitter.on('did-delete', callback);
    };

    TextBuffer.prototype.onWillReload = function(callback) {
      return this.emitter.on('will-reload', callback);
    };

    TextBuffer.prototype.onDidReload = function(callback) {
      return this.emitter.on('did-reload', callback);
    };

    TextBuffer.prototype.onDidDestroy = function(callback) {
      return this.emitter.on('did-destroy', callback);
    };

    TextBuffer.prototype.onWillThrowWatchError = function(callback) {
      return this.emitter.on('will-throw-watch-error', callback);
    };

    TextBuffer.prototype.getStoppedChangingDelay = function() {
      return this.stoppedChangingDelay;
    };


    /*
    Section: File Details
     */

    TextBuffer.prototype.isModified = function() {
      var _ref2;
      if (!this.loaded) {
        return false;
      }
      if (this.file) {
        if (this.file.existsSync()) {
          return this.getText() !== this.cachedDiskContents;
        } else {
          return (_ref2 = this.wasModifiedBeforeRemove) != null ? _ref2 : !this.isEmpty();
        }
      } else {
        return !this.isEmpty();
      }
    };

    TextBuffer.prototype.isInConflict = function() {
      return this.conflict;
    };

    TextBuffer.prototype.getPath = function() {
      var _ref2;
      return (_ref2 = this.file) != null ? _ref2.getPath() : void 0;
    };

    TextBuffer.prototype.setPath = function(filePath) {
      if (filePath === this.getPath()) {
        return;
      }
      if (filePath) {
        this.file = new File(filePath);
        this.file.setEncoding(this.getEncoding());
        this.subscribeToFile();
      } else {
        this.file = null;
      }
      this.emitter.emit('did-change-path', this.getPath());
    };

    TextBuffer.prototype.setEncoding = function(encoding) {
      if (encoding == null) {
        encoding = 'utf8';
      }
      if (encoding === this.getEncoding()) {
        return;
      }
      this.encoding = encoding;
      if (this.file != null) {
        this.file.setEncoding(encoding);
        this.emitter.emit('did-change-encoding', encoding);
        if (!this.isModified()) {
          this.updateCachedDiskContents(true, (function(_this) {
            return function() {
              _this.reload();
              return _this.clearUndoStack();
            };
          })(this));
        }
      } else {
        this.emitter.emit('did-change-encoding', encoding);
      }
    };

    TextBuffer.prototype.getEncoding = function() {
      var _ref2, _ref3;
      return (_ref2 = this.encoding) != null ? _ref2 : (_ref3 = this.file) != null ? _ref3.getEncoding() : void 0;
    };

    TextBuffer.prototype.setPreferredLineEnding = function(preferredLineEnding) {
      if (preferredLineEnding == null) {
        preferredLineEnding = null;
      }
      return this.preferredLineEnding = preferredLineEnding;
    };

    TextBuffer.prototype.getPreferredLineEnding = function() {
      return this.preferredLineEnding;
    };

    TextBuffer.prototype.getUri = function() {
      return this.getPath();
    };

    TextBuffer.prototype.getBaseName = function() {
      var _ref2;
      return (_ref2 = this.file) != null ? _ref2.getBaseName() : void 0;
    };


    /*
    Section: Reading Text
     */

    TextBuffer.prototype.isEmpty = function() {
      return this.getLastRow() === 0 && this.lineLengthForRow(0) === 0;
    };

    TextBuffer.prototype.getText = function() {
      var row, text, _i, _ref2;
      if (this.cachedText != null) {
        return this.cachedText;
      } else {
        text = '';
        for (row = _i = 0, _ref2 = this.getLastRow(); 0 <= _ref2 ? _i <= _ref2 : _i >= _ref2; row = 0 <= _ref2 ? ++_i : --_i) {
          text += this.lineForRow(row) + this.lineEndingForRow(row);
        }
        return this.cachedText = text;
      }
    };

    TextBuffer.prototype.getTextInRange = function(range) {
      var endRow, line, row, startRow, text, _i;
      range = this.clipRange(Range.fromObject(range));
      startRow = range.start.row;
      endRow = range.end.row;
      if (startRow === endRow) {
        return this.lineForRow(startRow).slice(range.start.column, range.end.column);
      } else {
        text = '';
        for (row = _i = startRow; startRow <= endRow ? _i <= endRow : _i >= endRow; row = startRow <= endRow ? ++_i : --_i) {
          line = this.lineForRow(row);
          if (row === startRow) {
            text += line.slice(range.start.column);
          } else if (row === endRow) {
            text += line.slice(0, range.end.column);
            continue;
          } else {
            text += line;
          }
          text += this.lineEndingForRow(row);
        }
        return text;
      }
    };

    TextBuffer.prototype.getLines = function() {
      return this.lines.slice();
    };

    TextBuffer.prototype.getLastLine = function() {
      return this.lineForRow(this.getLastRow());
    };

    TextBuffer.prototype.lineForRow = function(row) {
      return this.lines[row];
    };

    TextBuffer.prototype.lineEndingForRow = function(row) {
      return this.lineEndings[row];
    };

    TextBuffer.prototype.lineLengthForRow = function(row) {
      return this.lines[row].length;
    };

    TextBuffer.prototype.isRowBlank = function(row) {
      return !/\S/.test(this.lineForRow(row));
    };

    TextBuffer.prototype.previousNonBlankRow = function(startRow) {
      var row, _i, _ref2;
      if (startRow === 0) {
        return null;
      }
      startRow = Math.min(startRow, this.getLastRow());
      for (row = _i = _ref2 = startRow - 1; _ref2 <= 0 ? _i <= 0 : _i >= 0; row = _ref2 <= 0 ? ++_i : --_i) {
        if (!this.isRowBlank(row)) {
          return row;
        }
      }
      return null;
    };

    TextBuffer.prototype.nextNonBlankRow = function(startRow) {
      var lastRow, row, _i, _ref2;
      lastRow = this.getLastRow();
      if (startRow < lastRow) {
        for (row = _i = _ref2 = startRow + 1; _ref2 <= lastRow ? _i <= lastRow : _i >= lastRow; row = _ref2 <= lastRow ? ++_i : --_i) {
          if (!this.isRowBlank(row)) {
            return row;
          }
        }
      }
      return null;
    };


    /*
    Section: Mutating Text
     */

    TextBuffer.prototype.setText = function(text) {
      return this.setTextInRange(this.getRange(), text, {
        normalizeLineEndings: false
      });
    };

    TextBuffer.prototype.setTextViaDiff = function(text) {
      var computeBufferColumn, currentText, endsWithNewline;
      currentText = this.getText();
      if (currentText === text) {
        return;
      }
      endsWithNewline = function(str) {
        return /[\r\n]+$/g.test(str);
      };
      computeBufferColumn = function(str) {
        var newlineIndex;
        newlineIndex = Math.max(str.lastIndexOf('\n'), str.lastIndexOf('\r'));
        if (endsWithNewline(str)) {
          return 0;
        } else if (newlineIndex === -1) {
          return str.length;
        } else {
          return str.length - newlineIndex - 1;
        }
      };
      return this.transact((function(_this) {
        return function() {
          var change, changeOptions, column, currentPosition, endColumn, endRow, lineCount, lineDiff, row, _i, _len, _ref2, _ref3;
          row = 0;
          column = 0;
          currentPosition = [0, 0];
          lineDiff = diff.diffLines(currentText, text);
          changeOptions = {
            normalizeLineEndings: false
          };
          for (_i = 0, _len = lineDiff.length; _i < _len; _i++) {
            change = lineDiff[_i];
            lineCount = (_ref2 = (_ref3 = change.value.match(newlineRegex)) != null ? _ref3.length : void 0) != null ? _ref2 : 0;
            currentPosition[0] = row;
            currentPosition[1] = column;
            if (change.added) {
              _this.setTextInRange([currentPosition, currentPosition], change.value, changeOptions);
              row += lineCount;
              column = computeBufferColumn(change.value);
            } else if (change.removed) {
              endRow = row + lineCount;
              endColumn = column + computeBufferColumn(change.value);
              _this.setTextInRange([currentPosition, [endRow, endColumn]], '', changeOptions);
            } else {
              row += lineCount;
              column = computeBufferColumn(change.value);
            }
          }
        };
      })(this));
    };

    TextBuffer.prototype.setTextInRange = function(range, newText, options) {
      var newRange, normalizeLineEndings, oldRange, oldText, undo;
      if (this.transactCallDepth === 0) {
        return this.transact((function(_this) {
          return function() {
            return _this.setTextInRange(range, newText, options);
          };
        })(this));
      }
      if (Grim.includeDeprecatedAPIs && typeof options === 'boolean') {
        normalizeLineEndings = options;
        Grim.deprecate("The normalizeLineEndings argument is now an options hash. Use {normalizeLineEndings: " + options + "} instead");
      } else if (options != null) {
        normalizeLineEndings = options.normalizeLineEndings, undo = options.undo;
      }
      if (normalizeLineEndings == null) {
        normalizeLineEndings = true;
      }
      oldRange = this.clipRange(range);
      oldText = this.getTextInRange(oldRange);
      newRange = Range.fromText(oldRange.start, newText);
      this.applyChange({
        oldRange: oldRange,
        newRange: newRange,
        oldText: oldText,
        newText: newText,
        normalizeLineEndings: normalizeLineEndings
      }, undo === 'skip');
      return newRange;
    };

    TextBuffer.prototype.insert = function(position, text, options) {
      return this.setTextInRange(new Range(position, position), text, options);
    };

    TextBuffer.prototype.append = function(text, options) {
      return this.insert(this.getEndPosition(), text, options);
    };

    TextBuffer.prototype.applyChange = function(change, skipUndo) {
      var changeEvent, endRow, ending, lastIndex, lastLine, lastLineEnding, line, lineEndings, lineStartIndex, lines, newExtent, newRange, newText, normalizeLineEndings, normalizedEnding, normalizedNewText, offsets, oldExtent, oldRange, oldText, prefix, result, rowCount, startRow, suffix, _ref2, _ref3, _ref4;
      oldRange = change.oldRange, newRange = change.newRange, oldText = change.oldText, newText = change.newText, normalizeLineEndings = change.normalizeLineEndings;
      oldRange.freeze();
      newRange.freeze();
      this.cachedText = null;
      startRow = oldRange.start.row;
      endRow = oldRange.end.row;
      rowCount = endRow - startRow + 1;
      oldExtent = oldRange.getExtent();
      newExtent = newRange.getExtent();
      if (normalizeLineEndings) {
        normalizedEnding = (_ref2 = this.preferredLineEnding) != null ? _ref2 : this.lineEndingForRow(startRow);
        if (!normalizedEnding) {
          if (startRow > 0) {
            normalizedEnding = this.lineEndingForRow(startRow - 1);
          } else {
            normalizedEnding = null;
          }
        }
      }
      lines = [];
      lineEndings = [];
      lineStartIndex = 0;
      normalizedNewText = "";
      while (result = newlineRegex.exec(newText)) {
        line = newText.slice(lineStartIndex, result.index);
        ending = normalizedEnding != null ? normalizedEnding : result[0];
        lines.push(line);
        lineEndings.push(ending);
        normalizedNewText += line + ending;
        lineStartIndex = newlineRegex.lastIndex;
      }
      lastLine = newText.slice(lineStartIndex);
      lines.push(lastLine);
      lineEndings.push('');
      normalizedNewText += lastLine;
      newText = normalizedNewText;
      changeEvent = Object.freeze({
        oldRange: oldRange,
        newRange: newRange,
        oldText: oldText,
        newText: newText
      });
      this.emitter.emit('will-change', changeEvent);
      prefix = this.lineForRow(startRow).slice(0, oldRange.start.column);
      lines[0] = prefix + lines[0];
      suffix = this.lineForRow(endRow).slice(oldRange.end.column);
      lastIndex = lines.length - 1;
      lines[lastIndex] += suffix;
      lastLineEnding = this.lineEndingForRow(endRow);
      if (lastLineEnding !== '' && (normalizedEnding != null)) {
        lastLineEnding = normalizedEnding;
      }
      lineEndings[lastIndex] = lastLineEnding;
      spliceArray(this.lines, startRow, rowCount, lines);
      spliceArray(this.lineEndings, startRow, rowCount, lineEndings);
      offsets = lines.map(function(line, index) {
        return {
          rows: 1,
          characters: line.length + lineEndings[index].length
        };
      });
      this.offsetIndex.spliceArray('rows', startRow, rowCount, offsets);
      if ((_ref3 = this.markerStore) != null) {
        _ref3.splice(oldRange.start, oldRange.getExtent(), newRange.getExtent());
      }
      if (!skipUndo) {
        if ((_ref4 = this.history) != null) {
          _ref4.pushChange(change);
        }
      }
      if (this.conflict && !this.isModified()) {
        this.conflict = false;
      }
      this.scheduleModifiedEvents();
      this.changeCount++;
      this.emitter.emit('did-change', changeEvent);
    };

    TextBuffer.prototype["delete"] = function(range) {
      return this.setTextInRange(range, '');
    };

    TextBuffer.prototype.deleteRow = function(row) {
      return this.deleteRows(row, row);
    };

    TextBuffer.prototype.deleteRows = function(startRow, endRow) {
      var endPoint, lastRow, startPoint, _ref2;
      lastRow = this.getLastRow();
      if (startRow > endRow) {
        _ref2 = [endRow, startRow], startRow = _ref2[0], endRow = _ref2[1];
      }
      if (endRow < 0) {
        return new Range(this.getFirstPosition(), this.getFirstPosition());
      }
      if (startRow > lastRow) {
        return new Range(this.getEndPosition(), this.getEndPosition());
      }
      startRow = Math.max(0, startRow);
      endRow = Math.min(lastRow, endRow);
      if (endRow < lastRow) {
        startPoint = new Point(startRow, 0);
        endPoint = new Point(endRow + 1, 0);
      } else {
        if (startRow === 0) {
          startPoint = new Point(startRow, 0);
        } else {
          startPoint = new Point(startRow - 1, this.lineLengthForRow(startRow - 1));
        }
        endPoint = new Point(endRow, this.lineLengthForRow(endRow));
      }
      return this["delete"](new Range(startPoint, endPoint));
    };


    /*
    Section: Markers
     */

    TextBuffer.prototype.markRange = function(range, properties) {
      return this.markerStore.markRange(this.clipRange(range), properties);
    };

    TextBuffer.prototype.markPosition = function(position, properties) {
      return this.markerStore.markPosition(this.clipPosition(position), properties);
    };

    TextBuffer.prototype.getMarkers = function() {
      return this.markerStore.getMarkers();
    };

    TextBuffer.prototype.getMarker = function(id) {
      return this.markerStore.getMarker(id);
    };

    TextBuffer.prototype.findMarkers = function(params) {
      return this.markerStore.findMarkers(params);
    };

    TextBuffer.prototype.getMarkerCount = function() {
      return this.markerStore.getMarkerCount();
    };

    TextBuffer.prototype.destroyMarker = function(id) {
      var _ref2;
      return (_ref2 = this.getMarker(id)) != null ? _ref2.destroy() : void 0;
    };


    /*
    Section: History
     */

    TextBuffer.prototype.undo = function() {
      var change, pop, _i, _len, _ref2;
      if (pop = this.history.popUndoStack()) {
        _ref2 = pop.changes;
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          change = _ref2[_i];
          this.applyChange(change, true);
        }
        this.markerStore.restoreFromSnapshot(pop.snapshot);
        return true;
      } else {
        return false;
      }
    };

    TextBuffer.prototype.redo = function() {
      var change, pop, _i, _len, _ref2;
      if (pop = this.history.popRedoStack()) {
        _ref2 = pop.changes;
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          change = _ref2[_i];
          this.applyChange(change, true);
        }
        this.markerStore.restoreFromSnapshot(pop.snapshot);
        return true;
      } else {
        return false;
      }
    };

    TextBuffer.prototype.transact = function(groupingInterval, fn) {
      var checkpointBefore, exception, result;
      if (typeof groupingInterval === 'function') {
        fn = groupingInterval;
        groupingInterval = 0;
      }
      checkpointBefore = this.history.createCheckpoint(this.markerStore.createSnapshot(false), true);
      try {
        this.transactCallDepth++;
        result = fn();
      } catch (_error) {
        exception = _error;
        this.revertToCheckpoint(checkpointBefore, true);
        if (!(exception instanceof TransactionAbortedError)) {
          throw exception;
        }
        return;
      } finally {
        this.transactCallDepth--;
      }
      this.history.groupChangesSinceCheckpoint(checkpointBefore, this.markerStore.createSnapshot(true), true);
      this.history.applyGroupingInterval(groupingInterval);
      return result;
    };

    TextBuffer.prototype.abortTransaction = function() {
      throw new TransactionAbortedError("Transaction aborted.");
    };

    TextBuffer.prototype.clearUndoStack = function() {
      return this.history.clearUndoStack();
    };

    TextBuffer.prototype.createCheckpoint = function() {
      return this.history.createCheckpoint(this.markerStore.createSnapshot(), false);
    };

    TextBuffer.prototype.revertToCheckpoint = function(checkpoint) {
      var change, truncated, _i, _len, _ref2;
      if (truncated = this.history.truncateUndoStack(checkpoint)) {
        _ref2 = truncated.changes;
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          change = _ref2[_i];
          this.applyChange(change, true);
        }
        this.markerStore.restoreFromSnapshot(truncated.snapshot);
        this.emitter.emit('did-update-markers');
        return true;
      } else {
        return false;
      }
    };

    TextBuffer.prototype.groupChangesSinceCheckpoint = function(checkpoint) {
      return this.history.groupChangesSinceCheckpoint(checkpoint, this.markerStore.createSnapshot(false), false);
    };


    /*
    Section: Search And Replace
     */

    TextBuffer.prototype.scan = function(regex, iterator) {
      return this.scanInRange(regex, this.getRange(), (function(_this) {
        return function(result) {
          result.lineText = _this.lineForRow(result.range.start.row);
          result.lineTextOffset = 0;
          return iterator(result);
        };
      })(this));
    };

    TextBuffer.prototype.backwardsScan = function(regex, iterator) {
      return this.backwardsScanInRange(regex, this.getRange(), (function(_this) {
        return function(result) {
          result.lineText = _this.lineForRow(result.range.start.row);
          result.lineTextOffset = 0;
          return iterator(result);
        };
      })(this));
    };

    TextBuffer.prototype.scanInRange = function(regex, range, iterator, reverse) {
      var callbackArgument, endIndex, flags, global, lengthDelta, match, matches, next, startIndex;
      if (reverse == null) {
        reverse = false;
      }
      range = this.clipRange(range);
      global = regex.global;
      flags = "gm";
      if (regex.ignoreCase) {
        flags += "i";
      }
      regex = new RegExp(regex.source, flags);
      startIndex = this.characterIndexForPosition(range.start);
      endIndex = this.characterIndexForPosition(range.end);
      if (reverse) {
        matches = new MatchIterator.Backwards(this.getText(), regex, startIndex, endIndex, this.backwardsScanChunkSize);
      } else {
        matches = new MatchIterator.Forwards(this.getText(), regex, startIndex, endIndex);
      }
      lengthDelta = 0;
      while (!(next = matches.next()).done) {
        match = next.value;
        callbackArgument = new SearchCallbackArgument(this, match, lengthDelta);
        iterator(callbackArgument);
        if (!reverse) {
          lengthDelta += callbackArgument.getReplacementDelta();
        }
        if (!(global && callbackArgument.keepLooping())) {
          break;
        }
      }
    };

    TextBuffer.prototype.backwardsScanInRange = function(regex, range, iterator) {
      return this.scanInRange(regex, range, iterator, true);
    };

    TextBuffer.prototype.replace = function(regex, replacementText) {
      var doSave, replacements;
      doSave = !this.isModified();
      replacements = 0;
      this.transact((function(_this) {
        return function() {
          return _this.scan(regex, function(_arg) {
            var matchText, replace;
            matchText = _arg.matchText, replace = _arg.replace;
            replace(matchText.replace(regex, replacementText));
            return replacements++;
          });
        };
      })(this));
      if (doSave) {
        this.save();
      }
      return replacements;
    };


    /*
    Section: Buffer Range Details
     */

    TextBuffer.prototype.getRange = function() {
      return new Range(this.getFirstPosition(), this.getEndPosition());
    };

    TextBuffer.prototype.getLineCount = function() {
      return this.lines.length;
    };

    TextBuffer.prototype.getLastRow = function() {
      return this.getLineCount() - 1;
    };

    TextBuffer.prototype.getFirstPosition = function() {
      return new Point(0, 0);
    };

    TextBuffer.prototype.getEndPosition = function() {
      var lastRow;
      lastRow = this.getLastRow();
      return new Point(lastRow, this.lineLengthForRow(lastRow));
    };

    TextBuffer.prototype.getMaxCharacterIndex = function() {
      return this.offsetIndex.totalTo(Infinity, 'rows').characters;
    };

    TextBuffer.prototype.rangeForRow = function(row, includeNewline) {
      if (Grim.includeDeprecatedAPIs && typeof includeNewline === 'object') {
        Grim.deprecate("The second param is no longer an object, it's a boolean argument named `includeNewline`.");
        includeNewline = includeNewline.includeNewline;
      }
      row = Math.max(row, 0);
      row = Math.min(row, this.getLastRow());
      if (includeNewline && row < this.getLastRow()) {
        return new Range(new Point(row, 0), new Point(row + 1, 0));
      } else {
        return new Range(new Point(row, 0), new Point(row, this.lineLengthForRow(row)));
      }
    };

    TextBuffer.prototype.characterIndexForPosition = function(position) {
      var characters, column, row, _ref2;
      _ref2 = this.clipPosition(Point.fromObject(position)), row = _ref2.row, column = _ref2.column;
      if (row < 0 || row > this.getLastRow() || column < 0 || column > this.lineLengthForRow(row)) {
        throw new Error("Position " + position + " is invalid");
      }
      characters = this.offsetIndex.totalTo(row, 'rows').characters;
      return characters + column;
    };

    TextBuffer.prototype.positionForCharacterIndex = function(offset) {
      var characters, rows, _ref2;
      offset = Math.max(0, offset);
      offset = Math.min(this.getMaxCharacterIndex(), offset);
      _ref2 = this.offsetIndex.totalTo(offset, 'characters'), rows = _ref2.rows, characters = _ref2.characters;
      if (rows > this.getLastRow()) {
        return this.getEndPosition();
      } else {
        return new Point(rows, offset - characters);
      }
    };

    TextBuffer.prototype.clipRange = function(range) {
      var end, start;
      range = Range.fromObject(range);
      start = this.clipPosition(range.start);
      end = this.clipPosition(range.end);
      if (range.start.isEqual(start) && range.end.isEqual(end)) {
        return range;
      } else {
        return new Range(start, end);
      }
    };

    TextBuffer.prototype.clipPosition = function(position) {
      var column, row;
      position = Point.fromObject(position);
      Point.assertValid(position);
      row = position.row, column = position.column;
      if (row < 0) {
        return this.getFirstPosition();
      } else if (row > this.getLastRow()) {
        return this.getEndPosition();
      } else {
        column = Math.min(Math.max(column, 0), this.lineLengthForRow(row));
        if (column === position.column) {
          return position;
        } else {
          return new Point(row, column);
        }
      }
    };


    /*
    Section: Buffer Operations
     */

    TextBuffer.prototype.save = function(options) {
      return this.saveAs(this.getPath(), options);
    };

    TextBuffer.prototype.saveAs = function(filePath, options) {
      var backupFilePath, error;
      if (!filePath) {
        throw new Error("Can't save buffer with no file path");
      }
      this.emitter.emit('will-save', {
        path: filePath
      });
      this.setPath(filePath);
      if (options != null ? options.backup : void 0) {
        backupFilePath = this.backUpFileContentsBeforeWriting();
      }
      try {
        this.file.writeSync(this.getText());
        if (backupFilePath != null) {
          this.removeBackupFileAfterWriting(backupFilePath);
        }
      } catch (_error) {
        error = _error;
        if (backupFilePath != null) {
          fs.writeFileSync(filePath, fs.readFileSync(backupFilePath));
        }
        throw error;
      }
      this.cachedDiskContents = this.getText();
      this.conflict = false;
      this.emitModifiedStatusChanged(false);
      this.emitter.emit('did-save', {
        path: filePath
      });
    };

    TextBuffer.prototype.reload = function(clearHistory) {
      var _ref2;
      if (clearHistory == null) {
        clearHistory = false;
      }
      this.emitter.emit('will-reload');
      if (clearHistory) {
        this.clearUndoStack();
        this.setTextInRange(this.getRange(), (_ref2 = this.cachedDiskContents) != null ? _ref2 : "", {
          normalizeLineEndings: false,
          undo: 'skip'
        });
      } else {
        this.setTextViaDiff(this.cachedDiskContents);
      }
      this.emitModifiedStatusChanged(false);
      this.emitter.emit('did-reload');
    };

    TextBuffer.prototype.updateCachedDiskContentsSync = function() {
      var _ref2, _ref3;
      return this.cachedDiskContents = (_ref2 = (_ref3 = this.file) != null ? _ref3.readSync() : void 0) != null ? _ref2 : "";
    };

    TextBuffer.prototype.updateCachedDiskContents = function(flushCache, callback) {
      var promise;
      if (flushCache == null) {
        flushCache = false;
      }
      if (this.file != null) {
        promise = this.file.read(flushCache);
      } else {
        promise = Promise.resolve("");
      }
      return promise.then((function(_this) {
        return function(contents) {
          _this.cachedDiskContents = contents;
          return typeof callback === "function" ? callback() : void 0;
        };
      })(this));
    };

    TextBuffer.prototype.backUpFileContentsBeforeWriting = function() {
      var backupDirectoryFD, backupFD, backupFilePath, error, maxTildes;
      if (!this.file.existsSync()) {
        return;
      }
      backupFilePath = this.getPath() + '~';
      maxTildes = 10;
      while (fs.existsSync(backupFilePath)) {
        if (--maxTildes === 0) {
          throw new Error("Can't create a backup file for " + (this.getPath()) + " because files already exist at every candidate path.");
        }
        backupFilePath += '~';
      }
      backupFD = fs.openSync(backupFilePath, 'w');
      fs.writeSync(backupFD, this.file.readSync());
      fs.fdatasyncSync(backupFD);
      fs.closeSync(backupFD);
      if (process.platform !== 'win32') {
        try {
          backupDirectoryFD = fs.openSync(path.dirname(backupFilePath), 'r');
          fs.fdatasyncSync(backupDirectoryFD);
          fs.closeSync(backupDirectoryFD);
        } catch (_error) {
          error = _error;
          console.warn("Non-fatal error syncing parent directory of backup file " + backupFilePath);
        }
      }
      return backupFilePath;
    };

    TextBuffer.prototype.removeBackupFileAfterWriting = function(backupFilePath) {
      var fd;
      fd = fs.openSync(this.getPath(), 'a');
      fs.fdatasyncSync(fd);
      fs.closeSync(fd);
      return fs.removeSync(backupFilePath);
    };


    /*
    Section: Private Utility Methods
     */

    TextBuffer.prototype.loadSync = function() {
      this.updateCachedDiskContentsSync();
      return this.finishLoading();
    };

    TextBuffer.prototype.load = function() {
      return this.updateCachedDiskContents().then((function(_this) {
        return function() {
          return _this.finishLoading();
        };
      })(this));
    };

    TextBuffer.prototype.finishLoading = function() {
      var _ref2;
      if (this.isAlive()) {
        this.loaded = true;
        if (this.digestWhenLastPersisted === ((_ref2 = this.file) != null ? _ref2.getDigestSync() : void 0)) {
          this.emitModifiedStatusChanged(this.isModified());
        } else {
          this.reload(true);
        }
      }
      return this;
    };

    TextBuffer.prototype.destroy = function() {
      var _ref2;
      if (!this.destroyed) {
        this.cancelStoppedChangingTimeout();
        if ((_ref2 = this.fileSubscriptions) != null) {
          _ref2.dispose();
        }
        this.destroyed = true;
        this.emitter.emit('did-destroy');
      }
    };

    TextBuffer.prototype.isAlive = function() {
      return !this.destroyed;
    };

    TextBuffer.prototype.isDestroyed = function() {
      return this.destroyed;
    };

    TextBuffer.prototype.isRetained = function() {
      return this.refcount > 0;
    };

    TextBuffer.prototype.retain = function() {
      this.refcount++;
      return this;
    };

    TextBuffer.prototype.release = function() {
      this.refcount--;
      if (!this.isRetained()) {
        this.destroy();
      }
      return this;
    };

    TextBuffer.prototype.subscribeToFile = function() {
      var _ref2;
      if ((_ref2 = this.fileSubscriptions) != null) {
        _ref2.dispose();
      }
      this.fileSubscriptions = new CompositeDisposable;
      this.fileSubscriptions.add(this.file.onDidChange((function(_this) {
        return function() {
          var previousContents;
          if (_this.isModified()) {
            _this.conflict = true;
          }
          previousContents = _this.cachedDiskContents;
          _this.updateCachedDiskContentsSync();
          if (previousContents === _this.cachedDiskContents) {
            return;
          }
          if (_this.conflict) {
            _this.emitter.emit('did-conflict');
          } else {
            return _this.reload();
          }
        };
      })(this)));
      this.fileSubscriptions.add(this.file.onDidDelete((function(_this) {
        return function() {
          var modified;
          modified = _this.getText() !== _this.cachedDiskContents;
          _this.wasModifiedBeforeRemove = modified;
          _this.emitter.emit('did-delete');
          if (modified) {
            return _this.updateCachedDiskContents();
          } else {
            return _this.destroy();
          }
        };
      })(this)));
      this.fileSubscriptions.add(this.file.onDidRename((function(_this) {
        return function() {
          _this.emitter.emit('did-change-path', _this.getPath());
        };
      })(this)));
      return this.fileSubscriptions.add(this.file.onWillThrowWatchError((function(_this) {
        return function(errorObject) {
          return _this.emitter.emit('will-throw-watch-error', errorObject);
        };
      })(this)));
    };

    TextBuffer.prototype.hasMultipleEditors = function() {
      return this.refcount > 1;
    };

    TextBuffer.prototype.cancelStoppedChangingTimeout = function() {
      if (this.stoppedChangingTimeout) {
        return clearTimeout(this.stoppedChangingTimeout);
      }
    };

    TextBuffer.prototype.scheduleModifiedEvents = function() {
      var stoppedChangingCallback;
      this.cancelStoppedChangingTimeout();
      stoppedChangingCallback = (function(_this) {
        return function() {
          var modifiedStatus;
          _this.stoppedChangingTimeout = null;
          modifiedStatus = _this.isModified();
          _this.emitter.emit('did-stop-changing');
          return _this.emitModifiedStatusChanged(modifiedStatus);
        };
      })(this);
      return this.stoppedChangingTimeout = setTimeout(stoppedChangingCallback, this.stoppedChangingDelay);
    };

    TextBuffer.prototype.emitModifiedStatusChanged = function(modifiedStatus) {
      if (modifiedStatus === this.previousModifiedStatus) {
        return;
      }
      this.previousModifiedStatus = modifiedStatus;
      this.emitter.emit('did-change-modified', modifiedStatus);
    };

    TextBuffer.prototype.logLines = function(start, end) {
      var line, row, _i;
      if (start == null) {
        start = 0;
      }
      if (end == null) {
        end = this.getLastRow();
      }
      for (row = _i = start; start <= end ? _i <= end : _i >= end; row = start <= end ? ++_i : --_i) {
        line = this.lineForRow(row);
        console.log(row, line, line.length);
      }
    };


    /*
    Section: Private History Delegate Methods
     */

    TextBuffer.prototype.invertChange = function(change) {
      return Object.freeze({
        oldRange: change.newRange,
        newRange: change.oldRange,
        oldText: change.newText,
        newText: change.oldText
      });
    };

    TextBuffer.prototype.serializeChange = function(change) {
      return {
        oldRange: change.oldRange.serialize(),
        newRange: change.newRange.serialize(),
        oldText: change.oldText,
        newText: change.newText
      };
    };

    TextBuffer.prototype.deserializeChange = function(change) {
      return {
        oldRange: Range.deserialize(change.oldRange),
        newRange: Range.deserialize(change.newRange),
        oldText: change.oldText,
        newText: change.newText
      };
    };

    TextBuffer.prototype.serializeSnapshot = function(snapshot) {
      return MarkerStore.serializeSnapshot(snapshot);
    };

    TextBuffer.prototype.deserializeSnapshot = function(snapshot) {
      return MarkerStore.deserializeSnapshot(snapshot);
    };


    /*
    Section: Private MarkerStore Delegate Methods
     */

    TextBuffer.prototype.markerCreated = function(marker) {
      this.emitter.emit('did-create-marker', marker);
    };

    TextBuffer.prototype.markersUpdated = function() {
      this.emitter.emit('did-update-markers');
    };

    return TextBuffer;

  })();

}).call(this);

  }),
  "span-skip-list": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var SpanSkipList,
    __slice = [].slice;

  module.exports = SpanSkipList = (function() {
    SpanSkipList.prototype.maxHeight = 8;

    SpanSkipList.prototype.probability = .25;

    function SpanSkipList() {
      var dimensions, index;
      dimensions = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      this.dimensions = dimensions;
      this.head = this.createNode(this.maxHeight, this.buildZeroDistance());
      this.tail = this.createNode(this.maxHeight, this.buildZeroDistance());
      index = 0;
      while (index < this.maxHeight) {
        this.head.next[index] = this.tail;
        this.head.distance[index] = this.buildZeroDistance();
        index++;
      }
    }

    SpanSkipList.prototype.totalTo = function(target, dimension) {
      var index, nextDistanceInTargetDimension, node, totalDistance, _ref;
      totalDistance = this.buildZeroDistance();
      node = this.head;
      index = this.maxHeight - 1;
      while (index >= 0) {
        while (true) {
          if (node.next[index] === this.tail) {
            break;
          }
          nextDistanceInTargetDimension = totalDistance[dimension] + node.distance[index][dimension] + ((_ref = node.next[index].element[dimension]) != null ? _ref : 1);
          if (nextDistanceInTargetDimension > target) {
            break;
          }
          this.incrementDistance(totalDistance, node.distance[index]);
          this.incrementDistance(totalDistance, node.next[index].element);
          node = node.next[index];
        }
        index--;
      }
      return totalDistance;
    };

    SpanSkipList.prototype.splice = function() {
      var count, dimension, elements, index;
      dimension = arguments[0], index = arguments[1], count = arguments[2], elements = 4 <= arguments.length ? __slice.call(arguments, 3) : [];
      return this.spliceArray(dimension, index, count, elements);
    };

    SpanSkipList.prototype.spliceArray = function(dimension, index, count, elements) {
      var i, newNode, nextNode, previous, previousDistances, removedElements;
      previous = this.buildPreviousArray();
      previousDistances = this.buildPreviousDistancesArray();
      nextNode = this.findClosestNode(dimension, index, previous, previousDistances);
      removedElements = [];
      while (count > 0 && nextNode !== this.tail) {
        removedElements.push(nextNode.element);
        nextNode = this.removeNode(nextNode, previous, previousDistances);
        count--;
      }
      i = elements.length - 1;
      while (i >= 0) {
        newNode = this.createNode(this.getRandomNodeHeight(), elements[i]);
        this.insertNode(newNode, previous, previousDistances);
        i--;
      }
      return removedElements;
    };

    SpanSkipList.prototype.getLength = function() {
      return this.getElements().length;
    };

    SpanSkipList.prototype.getElements = function() {
      var elements, node;
      elements = [];
      node = this.head;
      while (node.next[0] !== this.tail) {
        elements.push(node.next[0].element);
        node = node.next[0];
      }
      return elements;
    };

    SpanSkipList.prototype.findClosestNode = function(dimension, index, previous, previousDistances) {
      var i, nextHopDistance, node, totalDistance, _i, _ref, _ref1;
      totalDistance = this.buildZeroDistance();
      node = this.head;
      for (i = _i = _ref = this.maxHeight - 1; _ref <= 0 ? _i <= 0 : _i >= 0; i = _ref <= 0 ? ++_i : --_i) {
        while (true) {
          if (node.next[i] === this.tail) {
            break;
          }
          nextHopDistance = ((_ref1 = node.next[i].element[dimension]) != null ? _ref1 : 1) + node.distance[i][dimension];
          if (totalDistance[dimension] + nextHopDistance > index) {
            break;
          }
          this.incrementDistance(totalDistance, node.distance[i]);
          this.incrementDistance(totalDistance, node.next[i].element);
          this.incrementDistance(previousDistances[i], node.distance[i]);
          this.incrementDistance(previousDistances[i], node.next[i].element);
          node = node.next[i];
        }
        previous[i] = node;
      }
      return node.next[0];
    };

    SpanSkipList.prototype.insertNode = function(node, previous, previousDistances) {
      var coveredDistance, level;
      coveredDistance = this.buildZeroDistance();
      level = 0;
      while (level < node.height) {
        node.next[level] = previous[level].next[level];
        previous[level].next[level] = node;
        node.distance[level] = this.subtractDistances(previous[level].distance[level], coveredDistance);
        previous[level].distance[level] = this.cloneObject(coveredDistance);
        this.incrementDistance(coveredDistance, previousDistances[level]);
        level++;
      }
      level = node.height;
      while (level < this.maxHeight) {
        this.incrementDistance(previous[level].distance[level], node.element);
        level++;
      }
    };

    SpanSkipList.prototype.removeNode = function(node, previous) {
      var level;
      level = 0;
      while (level < node.height) {
        previous[level].next[level] = node.next[level];
        this.incrementDistance(previous[level].distance[level], node.distance[level]);
        level++;
      }
      level = node.height;
      while (level < this.maxHeight) {
        this.decrementDistance(previous[level].distance[level], node.element);
        level++;
      }
      return node.next[0];
    };

    SpanSkipList.prototype.buildPreviousArray = function() {
      var index, previous;
      previous = new Array(this.maxHeight);
      index = 0;
      while (index < this.maxHeight) {
        previous[index] = this.head;
        index++;
      }
      return previous;
    };

    SpanSkipList.prototype.buildPreviousDistancesArray = function() {
      var distances, index;
      distances = new Array(this.maxHeight);
      index = 0;
      while (index < this.maxHeight) {
        distances[index] = this.buildZeroDistance();
        index++;
      }
      return distances;
    };

    SpanSkipList.prototype.getRandomNodeHeight = function() {
      var height;
      height = 1;
      while (height < this.maxHeight && Math.random() < this.probability) {
        height++;
      }
      return height;
    };

    SpanSkipList.prototype.buildZeroDistance = function() {
      var dimension, _i, _len, _ref;
      if (this.zeroDistance == null) {
        this.zeroDistance = {
          elements: 0
        };
        _ref = this.dimensions;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          dimension = _ref[_i];
          this.zeroDistance[dimension] = 0;
        }
      }
      return this.cloneObject(this.zeroDistance);
    };

    SpanSkipList.prototype.incrementDistance = function(distance, delta) {
      var dimension, _i, _len, _ref, _ref1;
      distance.elements += (_ref = delta.elements) != null ? _ref : 1;
      _ref1 = this.dimensions;
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        dimension = _ref1[_i];
        distance[dimension] += delta[dimension];
      }
    };

    SpanSkipList.prototype.decrementDistance = function(distance, delta) {
      var dimension, _i, _len, _ref, _ref1;
      distance.elements -= (_ref = delta.elements) != null ? _ref : 1;
      _ref1 = this.dimensions;
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        dimension = _ref1[_i];
        distance[dimension] -= delta[dimension];
      }
    };

    SpanSkipList.prototype.addDistances = function(a, b) {
      var dimension, distance, _i, _len, _ref, _ref1, _ref2;
      distance = {
        elements: ((_ref = a.elements) != null ? _ref : 1) + ((_ref1 = b.elements) != null ? _ref1 : 1)
      };
      _ref2 = this.dimensions;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        dimension = _ref2[_i];
        distance[dimension] = a[dimension] + b[dimension];
      }
      return distance;
    };

    SpanSkipList.prototype.subtractDistances = function(a, b) {
      var dimension, distance, _i, _len, _ref, _ref1, _ref2;
      distance = {
        elements: ((_ref = a.elements) != null ? _ref : 1) - ((_ref1 = b.elements) != null ? _ref1 : 1)
      };
      _ref2 = this.dimensions;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        dimension = _ref2[_i];
        distance[dimension] = a[dimension] - b[dimension];
      }
      return distance;
    };

    SpanSkipList.prototype.verifyDistanceInvariant = function() {
      var distanceOnPreviousLevel, distanceOnThisLevel, isEqual, level, node, _i, _ref, _results;
      isEqual = require('underscore').isEqual;
      _results = [];
      for (level = _i = _ref = this.maxHeight - 1; _ref <= 1 ? _i <= 1 : _i >= 1; level = _ref <= 1 ? ++_i : --_i) {
        node = this.head;
        _results.push((function() {
          var _results1;
          _results1 = [];
          while (node !== this.tail) {
            distanceOnThisLevel = this.addDistances(node.element, node.distance[level]);
            distanceOnPreviousLevel = this.distanceBetweenNodesAtLevel(node, node.next[level], level - 1);
            if (!isEqual(distanceOnThisLevel, distanceOnPreviousLevel)) {
              console.log(this.inspect());
              throw new Error("On level " + level + ": Distance " + (JSON.stringify(distanceOnThisLevel)) + " does not match " + (JSON.stringify(distanceOnPreviousLevel)));
            }
            _results1.push(node = node.next[level]);
          }
          return _results1;
        }).call(this));
      }
      return _results;
    };

    SpanSkipList.prototype.distanceBetweenNodesAtLevel = function(startNode, endNode, level) {
      var distance, node;
      distance = this.buildZeroDistance();
      node = startNode;
      while (node !== endNode) {
        this.incrementDistance(distance, node.element);
        this.incrementDistance(distance, node.distance[level]);
        node = node.next[level];
      }
      return distance;
    };

    SpanSkipList.prototype.createNode = function(height, element) {
      return {
        height: height,
        element: element,
        next: new Array(height),
        distance: new Array(height)
      };
    };

    SpanSkipList.prototype.cloneObject = function(object) {
      var cloned, key, value;
      cloned = {};
      for (key in object) {
        value = object[key];
        cloned[key] = value;
      }
      return cloned;
    };

    return SpanSkipList;

  })();

}).call(this);

}),
  "get-parameter-names": (function (exports, require, module, __filename, __dirname, process, global) { var COMMENTS = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg;
function getParameterNames(fn) {
  var code = fn.toString().replace(COMMENTS, '');
  var result = code.slice(code.indexOf('(') + 1, code.indexOf(')'))
    .match(/([^\s,]+)/g);

  return result === null
    ? []
    : result;
}

module.exports = getParameterNames;

}),
  "serializable": (function (exports, require, module, __filename, __dirname, process, global) {
    (function() {
  var Mixin, Serializable, extend, getParameterNames, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice;

  extend = require('underscore-plus').extend;

  Mixin = require('mixto');

  getParameterNames = require('get-parameter-names');

  module.exports = Serializable = (function(_super) {
    __extends(Serializable, _super);

    function Serializable() {
      _ref = Serializable.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    Serializable.prototype.deserializers = null;

    Serializable.registerDeserializers = function() {
      var deserializer, deserializers, _i, _len, _results;
      deserializers = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      _results = [];
      for (_i = 0, _len = deserializers.length; _i < _len; _i++) {
        deserializer = deserializers[_i];
        _results.push(this.registerDeserializer(deserializer));
      }
      return _results;
    };

    Serializable.registerDeserializer = function(deserializer) {
      if (this.deserializers == null) {
        this.deserializers = {};
      }
      return this.deserializers[deserializer.name] = deserializer;
    };

    Serializable.deserialize = function(state, params) {
      var deserializer, object, orderedParams, _ref1;
      if (state == null) {
        return;
      }
      if (state.deserializer === this.name) {
        deserializer = this;
      } else {
        deserializer = (_ref1 = this.deserializers) != null ? _ref1[state.deserializer] : void 0;
      }
      if (!((deserializer != null) && deserializer.version === state.version)) {
        return;
      }
      object = Object.create(deserializer.prototype);
      params = extend({}, state, params);
      delete params.deserializer;
      if (typeof object.deserializeParams === 'function') {
        params = object.deserializeParams(params);
      }
      if (params == null) {
        return;
      }
      if (deserializer.parameterNames == null) {
        deserializer.parameterNames = getParameterNames(deserializer);
      }
      if (deserializer.parameterNames.length > 1 || params.hasOwnProperty(deserializer.parameterNames[0])) {
        orderedParams = deserializer.parameterNames.map(function(name) {
          return params[name];
        });
        deserializer.call.apply(deserializer, [object].concat(__slice.call(orderedParams)));
      } else {
        deserializer.call(object, params);
      }
      return object;
    };

    Serializable.prototype.serialize = function() {
      var state, _ref1;
      state = (_ref1 = typeof this.serializeParams === "function" ? this.serializeParams() : void 0) != null ? _ref1 : {};
      state.deserializer = this.constructor.name;
      if (this.constructor.version != null) {
        state.version = this.constructor.version;
      }
      return state;
    };

    Serializable.prototype.testSerialization = function(params) {
      return this.constructor.deserialize(this.serialize(), params);
    };

    return Serializable;

  })(Mixin);

}).call(this);

  }),
  "mixto": (function (exports, require, module, __filename, __dirname, process, global) {
    (function() {
  var ExcludedClassProperties, ExcludedPrototypeProperties, Mixin, name;

  module.exports = Mixin = (function() {
    Mixin.includeInto = function(constructor) {
      var name, value, _ref;
      this.extend(constructor.prototype);
      for (name in this) {
        value = this[name];
        if (ExcludedClassProperties.indexOf(name) === -1) {
          if (!constructor.hasOwnProperty(name)) {
            constructor[name] = value;
          }
        }
      }
      return (_ref = this.included) != null ? _ref.call(constructor) : void 0;
    };

    Mixin.extend = function(object) {
      var name, _i, _len, _ref, _ref1;
      _ref = Object.getOwnPropertyNames(this.prototype);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        name = _ref[_i];
        if (ExcludedPrototypeProperties.indexOf(name) === -1) {
          if (!object.hasOwnProperty(name)) {
            object[name] = this.prototype[name];
          }
        }
      }
      return (_ref1 = this.prototype.extended) != null ? _ref1.call(object) : void 0;
    };

    function Mixin() {
      if (typeof this.extended === "function") {
        this.extended();
      }
    }

    return Mixin;

  })();

  ExcludedClassProperties = ['__super__'];

  for (name in Mixin) {
    ExcludedClassProperties.push(name);
  }

  ExcludedPrototypeProperties = ['constructor', 'extended'];

}).call(this);

  }),
  "./match-iterator": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var Backwards, Forwards;

  Forwards = (function() {
    function Forwards(text, regex, startIndex, endIndex) {
      this.text = text;
      this.regex = regex;
      this.startIndex = startIndex;
      this.endIndex = endIndex;
      this.regex.lastIndex = this.startIndex;
    }

    Forwards.prototype.next = function() {
      var match, matchEndIndex, matchLength, matchStartIndex, submatch;
      if (match = this.regex.exec(this.text)) {
        matchLength = match[0].length;
        matchStartIndex = match.index;
        matchEndIndex = matchStartIndex + matchLength;
        if (matchEndIndex > this.endIndex) {
          this.regex.lastIndex = 0;
          if (matchStartIndex < this.endIndex && (submatch = this.regex.exec(this.text.slice(matchStartIndex, this.endIndex)))) {
            submatch.index = matchStartIndex;
            match = submatch;
          } else {
            match = null;
          }
          this.regex.lastIndex = Infinity;
        } else {
          if (matchLength === 0) {
            matchEndIndex++;
          }
          this.regex.lastIndex = matchEndIndex;
        }
      }
      if (match) {
        return {
          value: match,
          done: false
        };
      } else {
        return {
          value: null,
          done: true
        };
      }
    };

    return Forwards;

  })();

  Backwards = (function() {
    function Backwards(text, regex, startIndex, endIndex, chunkSize) {
      this.text = text;
      this.regex = regex;
      this.startIndex = startIndex;
      this.chunkSize = chunkSize;
      this.bufferedMatches = [];
      this.doneScanning = false;
      this.chunkStartIndex = this.chunkEndIndex = endIndex;
      this.lastMatchIndex = Infinity;
    }

    Backwards.prototype.scanNextChunk = function() {
      var firstResultIndex, match, matchEndIndex, matchLength, matchStartIndex, submatch, _ref;
      this.doneScanning = this.chunkStartIndex === this.startIndex;
      this.chunkEndIndex = Math.min(this.chunkEndIndex, this.lastMatchIndex);
      this.chunkStartIndex = Math.max(this.startIndex, this.chunkStartIndex - this.chunkSize);
      firstResultIndex = null;
      this.regex.lastIndex = this.chunkStartIndex;
      while (match = this.regex.exec(this.text)) {
        matchLength = match[0].length;
        matchStartIndex = match.index;
        matchEndIndex = matchStartIndex + matchLength;
        if ((matchStartIndex === (_ref = this.chunkStartIndex) && _ref > this.startIndex)) {
          break;
        }
        if (matchStartIndex >= this.chunkEndIndex) {
          break;
        }
        if (matchEndIndex > this.chunkEndIndex) {
          this.regex.lastIndex = 0;
          if (submatch = this.regex.exec(this.text.slice(matchStartIndex, this.chunkEndIndex))) {
            submatch.index = matchStartIndex;
            if (firstResultIndex == null) {
              firstResultIndex = matchStartIndex;
            }
            this.bufferedMatches.push(submatch);
          }
          break;
        } else {
          if (firstResultIndex == null) {
            firstResultIndex = matchStartIndex;
          }
          this.bufferedMatches.push(match);
          if (matchLength === 0) {
            matchEndIndex++;
          }
          this.regex.lastIndex = matchEndIndex;
        }
      }
      if (firstResultIndex) {
        return this.lastMatchIndex = firstResultIndex;
      }
    };

    Backwards.prototype.next = function() {
      var match;
      while (!(this.doneScanning || this.bufferedMatches.length > 0)) {
        this.scanNextChunk();
      }
      if (match = this.bufferedMatches.pop()) {
        return {
          value: match,
          done: false
        };
      } else {
        return {
          value: null,
          done: true
        };
      }
    };

    return Backwards;

  })();

  module.exports = {
    Forwards: Forwards,
    Backwards: Backwards
  };

}).call(this);

}),
  "./marker-store": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var Marker, MarkerIndex, MarkerStore, Point, Range, SerializationVersion, clone, filterSet, intersectSet;

  clone = require("underscore-plus").clone;

  Point = require("./point");

  Range = require("./range");

  Marker = require("./marker");

  MarkerIndex = require("./marker-index");

  intersectSet = require("./set-helpers").intersectSet;

  SerializationVersion = 2;

  module.exports = MarkerStore = (function() {
    MarkerStore.deserialize = function(delegate, state) {
      var store;
      store = new MarkerStore(delegate);
      store.deserialize(state);
      return store;
    };

    MarkerStore.serializeSnapshot = function(snapshot) {
      var id, markerSnapshot, result;
      result = {};
      for (id in snapshot) {
        markerSnapshot = snapshot[id];
        result[id] = clone(markerSnapshot);
        result[id].range = markerSnapshot.range.serialize();
      }
      return result;
    };

    MarkerStore.deserializeSnapshot = function(snapshot) {
      var id, markerSnapshot, result;
      result = {};
      for (id in snapshot) {
        markerSnapshot = snapshot[id];
        result[id] = clone(markerSnapshot);
        result[id].range = Range.deserialize(markerSnapshot.range);
      }
      return result;
    };

    function MarkerStore(delegate) {
      this.delegate = delegate;
      this.index = new MarkerIndex;
      this.markersById = {};
      this.historiedMarkers = new Set;
      this.nextMarkerId = 0;
    }


    /*
    Section: TextBuffer API
     */

    MarkerStore.prototype.getMarker = function(id) {
      return this.markersById[id];
    };

    MarkerStore.prototype.getMarkers = function() {
      var id, marker, _ref, _results;
      _ref = this.markersById;
      _results = [];
      for (id in _ref) {
        marker = _ref[id];
        _results.push(marker);
      }
      return _results;
    };

    MarkerStore.prototype.getMarkerCount = function() {
      return Object.keys(this.markersById).length;
    };

    MarkerStore.prototype.findMarkers = function(params) {
      var end, key, markerIds, result, start, value, _i, _len, _ref, _ref1, _ref2, _ref3;
      markerIds = null;
      _ref = Object.keys(params);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        key = _ref[_i];
        value = params[key];
        switch (key) {
          case 'startPosition':
            markerIds = filterSet(markerIds, this.index.findStartingIn(Point.fromObject(value)));
            break;
          case 'endPosition':
            markerIds = filterSet(markerIds, this.index.findEndingIn(Point.fromObject(value)));
            break;
          case 'containsPoint':
          case 'containsPosition':
            markerIds = filterSet(markerIds, this.index.findContaining(Point.fromObject(value)));
            break;
          case 'containsRange':
            _ref1 = Range.fromObject(value), start = _ref1.start, end = _ref1.end;
            markerIds = filterSet(markerIds, this.index.findContaining(start, end));
            break;
          case 'intersectsRange':
            _ref2 = Range.fromObject(value), start = _ref2.start, end = _ref2.end;
            markerIds = filterSet(markerIds, this.index.findIntersecting(start, end));
            break;
          case 'startRow':
            markerIds = filterSet(markerIds, this.index.findStartingIn(Point(value, 0), Point(value, Infinity)));
            break;
          case 'endRow':
            markerIds = filterSet(markerIds, this.index.findEndingIn(Point(value, 0), Point(value, Infinity)));
            break;
          case 'intersectsRow':
            markerIds = filterSet(markerIds, this.index.findIntersecting(Point(value, 0), Point(value, Infinity)));
            break;
          case 'intersectsRowRange':
            markerIds = filterSet(markerIds, this.index.findIntersecting(Point(value[0], 0), Point(value[1], Infinity)));
            break;
          case 'containedInRange':
            _ref3 = Range.fromObject(value), start = _ref3.start, end = _ref3.end;
            markerIds = filterSet(markerIds, this.index.findContainedIn(start, end));
            break;
          default:
            continue;
        }
        delete params[key];
      }
      if (markerIds == null) {
        markerIds = new Set(Object.keys(this.markersById));
      }
      result = [];
      markerIds.forEach((function(_this) {
        return function(id) {
          var marker;
          marker = _this.markersById[id];
          if (marker.matchesParams(params)) {
            return result.push(marker);
          }
        };
      })(this));
      return result.sort(function(a, b) {
        return a.compare(b);
      });
    };

    MarkerStore.prototype.markRange = function(range, options) {
      if (options == null) {
        options = {};
      }
      return this.createMarker(Range.fromObject(range), Marker.extractParams(options));
    };

    MarkerStore.prototype.markPosition = function(position, options) {
      if (options == null) {
        options = {};
      }
      if (options.tailed == null) {
        options.tailed = false;
      }
      return this.markRange(Range(position, position), options);
    };

    MarkerStore.prototype.splice = function(start, oldExtent, newExtent) {
      var end, endingAt, endingIn, id, intersecting, invalid, marker, startingAt, startingIn, _i, _len, _ref;
      end = start.traverse(oldExtent);
      intersecting = this.index.findIntersecting(start, end);
      endingAt = this.index.findEndingIn(start);
      startingAt = this.index.findStartingIn(end);
      startingIn = this.index.findStartingIn(start.traverse(Point(0, 1)), end.traverse(Point(0, -1)));
      endingIn = this.index.findEndingIn(start.traverse(Point(0, 1)), end.traverse(Point(0, -1)));
      _ref = Object.keys(this.markersById);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        id = _ref[_i];
        marker = this.markersById[id];
        switch (marker.getInvalidationStrategy()) {
          case 'touch':
            invalid = intersecting.has(id);
            break;
          case 'inside':
            invalid = intersecting.has(id) && !(startingAt.has(id) || endingAt.has(id));
            break;
          case 'overlap':
            invalid = startingIn.has(id) || endingIn.has(id);
            break;
          case 'surround':
            invalid = startingIn.has(id) && endingIn.has(id);
            break;
          case 'never':
            invalid = false;
        }
        if (invalid) {
          marker.valid = false;
        }
      }
      return this.index.splice(start, oldExtent, newExtent);
    };

    MarkerStore.prototype.restoreFromSnapshot = function(snapshots) {
      var createdIds, existingMarkerIds, id, marker, newMarker, snapshot, snapshotIds, _i, _j, _len, _len1;
      if (snapshots == null) {
        return;
      }
      createdIds = new Set;
      snapshotIds = Object.keys(snapshots);
      existingMarkerIds = Object.keys(this.markersById);
      for (_i = 0, _len = snapshotIds.length; _i < _len; _i++) {
        id = snapshotIds[_i];
        snapshot = snapshots[id];
        if (marker = this.markersById[id]) {
          marker.update(marker.getRange(), snapshot, true);
        } else {
          newMarker = this.createMarker(snapshot.range, snapshot);
          createdIds.add(newMarker.id);
        }
      }
      for (_j = 0, _len1 = existingMarkerIds.length; _j < _len1; _j++) {
        id = existingMarkerIds[_j];
        if ((marker = this.markersById[id]) && (snapshots[id] == null)) {
          if (this.historiedMarkers.has(id)) {
            marker.destroy();
          } else {
            marker.emitChangeEvent(marker.getRange(), true, false);
          }
        }
      }
      this.delegate.markersUpdated();
    };

    MarkerStore.prototype.createSnapshot = function(emitChangeEvents) {
      var id, marker, ranges, result, _i, _len, _ref;
      if (emitChangeEvents == null) {
        emitChangeEvents = false;
      }
      result = {};
      ranges = this.index.dump(this.historiedMarkers);
      _ref = Object.keys(this.markersById);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        id = _ref[_i];
        if (marker = this.markersById[id]) {
          if (marker.maintainHistory) {
            result[id] = marker.getSnapshot(ranges[id], false);
          }
          if (emitChangeEvents) {
            marker.emitChangeEvent(ranges[id], true, false);
          }
        }
      }
      if (emitChangeEvents) {
        this.delegate.markersUpdated();
      }
      return result;
    };

    MarkerStore.prototype.serialize = function() {
      var id, marker, markersById, ranges, _i, _len, _ref;
      ranges = this.index.dump();
      markersById = {};
      _ref = Object.keys(this.markersById);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        id = _ref[_i];
        marker = this.markersById[id];
        if (marker.persistent) {
          markersById[id] = marker.getSnapshot(ranges[id], false);
        }
      }
      return {
        nextMarkerId: this.nextMarkerId,
        markersById: markersById,
        version: SerializationVersion
      };
    };

    MarkerStore.prototype.deserialize = function(state) {
      var id, markerState, range, _ref;
      if (state.version !== SerializationVersion) {
        return;
      }
      this.nextMarkerId = state.nextMarkerId;
      _ref = state.markersById;
      for (id in _ref) {
        markerState = _ref[id];
        range = Range.fromObject(markerState.range);
        delete markerState.range;
        this.addMarker(id, range, markerState);
      }
    };


    /*
    Section: Marker interface
     */

    MarkerStore.prototype.markerUpdated = function() {
      return this.delegate.markersUpdated();
    };

    MarkerStore.prototype.destroyMarker = function(id) {
      delete this.markersById[id];
      this.historiedMarkers["delete"](id);
      this.index["delete"](id);
      return this.delegate.markersUpdated();
    };

    MarkerStore.prototype.getMarkerRange = function(id) {
      return this.index.getRange(id);
    };

    MarkerStore.prototype.getMarkerStartPosition = function(id) {
      return this.index.getStart(id);
    };

    MarkerStore.prototype.getMarkerEndPosition = function(id) {
      return this.index.getEnd(id);
    };

    MarkerStore.prototype.setMarkerRange = function(id, range) {
      var end, start, _ref;
      _ref = Range.fromObject(range), start = _ref.start, end = _ref.end;
      start = this.delegate.clipPosition(start);
      end = this.delegate.clipPosition(end);
      this.index["delete"](id);
      return this.index.insert(id, start, end);
    };

    MarkerStore.prototype.setMarkerHasTail = function(id, hasTail) {
      return this.index.setExclusive(id, !hasTail);
    };

    MarkerStore.prototype.createMarker = function(range, params) {
      var id, marker;
      id = String(this.nextMarkerId++);
      marker = this.addMarker(id, range, params);
      this.delegate.markerCreated(marker);
      this.delegate.markersUpdated();
      return marker;
    };


    /*
    Section: Private
     */

    MarkerStore.prototype.addMarker = function(id, range, params) {
      var marker;
      Point.assertValid(range.start);
      Point.assertValid(range.end);
      marker = new Marker(id, this, range, params);
      this.markersById[id] = marker;
      this.index.insert(id, range.start, range.end);
      if (marker.getInvalidationStrategy() === 'inside') {
        this.index.setExclusive(id, true);
      }
      if (marker.maintainHistory) {
        this.historiedMarkers.add(id);
      }
      return marker;
    };

    return MarkerStore;

  })();

  filterSet = function(set1, set2) {
    if (set1) {
      intersectSet(set1, set2);
      return set1;
    } else {
      return set2;
    }
  };

}).call(this);

}),
  "./marker-index": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var BRANCHING_THRESHOLD, Leaf, MarkerIndex, Node, Point, Range, addSet, assertValidId, extend, intersectSet, last, setEqual, setsOverlap, subtractSet, templateRange, _ref, _ref1,
    __slice = [].slice;

  Point = require("./point");

  Range = require("./range");

  _ref = require("underscore-plus"), last = _ref.last, extend = _ref.extend;

  _ref1 = require("./set-helpers"), addSet = _ref1.addSet, subtractSet = _ref1.subtractSet, intersectSet = _ref1.intersectSet, setEqual = _ref1.setEqual;

  BRANCHING_THRESHOLD = 3;

  Node = (function() {
    function Node(children) {
      var child, _i, _len, _ref2;
      this.children = children;
      this.ids = new Set;
      this.extent = Point.ZERO;
      _ref2 = this.children;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        child = _ref2[_i];
        this.extent = this.extent.traverse(child.extent);
        addSet(this.ids, child.ids);
      }
    }

    Node.prototype.insert = function(ids, start, end) {
      var child, childEnd, childFollowsRange, childPrecedesRange, childStart, i, newChildren, newNodes, rangeIsEmpty, relativeEnd, relativeStart, _ref2;
      rangeIsEmpty = start.compare(end) === 0;
      childEnd = Point.ZERO;
      i = 0;
      while (i < this.children.length) {
        child = this.children[i++];
        childStart = childEnd;
        childEnd = childStart.traverse(child.extent);
        switch (childEnd.compare(start)) {
          case -1:
            childPrecedesRange = true;
            break;
          case 1:
            childPrecedesRange = false;
            break;
          case 0:
            if (child.hasEmptyRightmostLeaf()) {
              childPrecedesRange = false;
            } else {
              childPrecedesRange = true;
              if (rangeIsEmpty) {
                ids = new Set(ids);
                child.findContaining(child.extent, ids);
              }
            }
        }
        if (childPrecedesRange) {
          continue;
        }
        switch (childStart.compare(end)) {
          case -1:
            childFollowsRange = false;
            break;
          case 1:
            childFollowsRange = true;
            break;
          case 0:
            childFollowsRange = !(child.hasEmptyLeftmostLeaf() || rangeIsEmpty);
        }
        if (childFollowsRange) {
          break;
        }
        relativeStart = Point.max(Point.ZERO, start.traversalFrom(childStart));
        relativeEnd = Point.min(child.extent, end.traversalFrom(childStart));
        if (newChildren = child.insert(ids, relativeStart, relativeEnd)) {
          (_ref2 = this.children).splice.apply(_ref2, [i - 1, 1].concat(__slice.call(newChildren)));
          i += newChildren.length - 1;
        }
        if (rangeIsEmpty) {
          break;
        }
      }
      if (newNodes = this.splitIfNeeded()) {
        return newNodes;
      } else {
        addSet(this.ids, ids);
      }
    };

    Node.prototype["delete"] = function(id) {
      var i, _results;
      if (!this.ids["delete"](id)) {
        return;
      }
      i = 0;
      _results = [];
      while (i < this.children.length) {
        this.children[i]["delete"](id);
        if (!this.mergeChildrenIfNeeded(i - 1)) {
          _results.push(i++);
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    Node.prototype.splice = function(position, oldExtent, newExtent, exclusiveIds, precedingIds, followingIds) {
      var child, childEnd, childPrecedesRange, childStart, extentAfterChange, i, nextChildIds, oldRangeIsEmpty, previousChildIds, previousExtent, remainderToDelete, spliceNewEnd, spliceOldEnd, splitNodes, _ref2, _ref3, _ref4, _ref5, _ref6;
      oldRangeIsEmpty = oldExtent.isZero();
      spliceOldEnd = position.traverse(oldExtent);
      spliceNewEnd = position.traverse(newExtent);
      extentAfterChange = this.extent.traversalFrom(spliceOldEnd);
      this.extent = spliceNewEnd.traverse(Point.max(Point.ZERO, extentAfterChange));
      if (position.isZero() && oldRangeIsEmpty) {
        if (precedingIds != null) {
          precedingIds.forEach((function(_this) {
            return function(id) {
              if (!exclusiveIds.has(id)) {
                return _this.ids.add(id);
              }
            };
          })(this));
        }
      }
      i = 0;
      childEnd = Point.ZERO;
      while (i < this.children.length) {
        child = this.children[i];
        childStart = childEnd;
        childEnd = childStart.traverse(child.extent);
        switch (childEnd.compare(position)) {
          case -1:
            childPrecedesRange = true;
            break;
          case 0:
            childPrecedesRange = !(child.hasEmptyRightmostLeaf() && oldRangeIsEmpty);
            break;
          case 1:
            childPrecedesRange = false;
        }
        if (!childPrecedesRange) {
          if (typeof remainderToDelete !== "undefined" && remainderToDelete !== null) {
            if (remainderToDelete.isPositive()) {
              previousExtent = child.extent;
              child.splice(Point.ZERO, remainderToDelete, Point.ZERO);
              remainderToDelete = remainderToDelete.traversalFrom(previousExtent);
              childEnd = childStart.traverse(child.extent);
            }
          } else {
            if (oldRangeIsEmpty) {
              previousChildIds = (_ref2 = (_ref3 = this.children[i - 1]) != null ? _ref3.getRightmostIds() : void 0) != null ? _ref2 : precedingIds;
              nextChildIds = (_ref4 = (_ref5 = this.children[i + 1]) != null ? _ref5.getLeftmostIds() : void 0) != null ? _ref4 : followingIds;
            }
            splitNodes = child.splice(position.traversalFrom(childStart), oldExtent, newExtent, exclusiveIds, previousChildIds, nextChildIds);
            if (splitNodes) {
              (_ref6 = this.children).splice.apply(_ref6, [i, 1].concat(__slice.call(splitNodes)));
            }
            remainderToDelete = spliceOldEnd.traversalFrom(childEnd);
            childEnd = childStart.traverse(child.extent);
          }
        }
        if (!this.mergeChildrenIfNeeded(i - 1)) {
          i++;
        }
      }
      return this.splitIfNeeded();
    };

    Node.prototype.getStart = function(id) {
      var child, childEnd, childStart, startRelativeToChild, _i, _len, _ref2;
      if (!this.ids.has(id)) {
        return;
      }
      childEnd = Point.ZERO;
      _ref2 = this.children;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        child = _ref2[_i];
        childStart = childEnd;
        childEnd = childStart.traverse(child.extent);
        if (startRelativeToChild = child.getStart(id)) {
          return childStart.traverse(startRelativeToChild);
        }
      }
    };

    Node.prototype.getEnd = function(id) {
      var child, childEnd, childStart, end, endRelativeToChild, _i, _len, _ref2;
      if (!this.ids.has(id)) {
        return;
      }
      childEnd = Point.ZERO;
      _ref2 = this.children;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        child = _ref2[_i];
        childStart = childEnd;
        childEnd = childStart.traverse(child.extent);
        if (endRelativeToChild = child.getEnd(id)) {
          end = childStart.traverse(endRelativeToChild);
        } else if (end != null) {
          break;
        }
      }
      return end;
    };

    Node.prototype.dump = function(ids, offset, snapshot) {
      var child, _i, _len, _ref2;
      _ref2 = this.children;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        child = _ref2[_i];
        if ((!ids) || setsOverlap(ids, child.ids)) {
          offset = child.dump(ids, offset, snapshot);
        } else {
          offset = offset.traverse(child.extent);
        }
      }
      return offset;
    };

    Node.prototype.findContaining = function(point, set) {
      var child, childEnd, childStart, _i, _len, _ref2;
      childEnd = Point.ZERO;
      _ref2 = this.children;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        child = _ref2[_i];
        childStart = childEnd;
        childEnd = childStart.traverse(child.extent);
        if (childEnd.compare(point) < 0) {
          continue;
        }
        if (childStart.compare(point) > 0) {
          break;
        }
        child.findContaining(point.traversalFrom(childStart), set);
      }
    };

    Node.prototype.findIntersecting = function(start, end, set) {
      var child, childEnd, childStart, _i, _len, _ref2;
      if (start.isZero() && end.compare(this.extent) === 0) {
        addSet(set, this.ids);
        return;
      }
      childEnd = Point.ZERO;
      _ref2 = this.children;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        child = _ref2[_i];
        childStart = childEnd;
        childEnd = childStart.traverse(child.extent);
        if (childEnd.compare(start) < 0) {
          continue;
        }
        if (childStart.compare(end) > 0) {
          break;
        }
        child.findIntersecting(Point.max(Point.ZERO, start.traversalFrom(childStart)), Point.min(child.extent, end.traversalFrom(childStart)), set);
      }
    };

    Node.prototype.findStartingAt = function(position, result, previousIds) {
      var child, nextPosition, _i, _len, _ref2;
      _ref2 = this.children;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        child = _ref2[_i];
        if (position.isNegative()) {
          break;
        }
        nextPosition = position.traversalFrom(child.extent);
        if (!nextPosition.isPositive()) {
          child.findStartingAt(position, result, previousIds);
        }
        previousIds = child.ids;
        position = nextPosition;
      }
    };

    Node.prototype.findEndingAt = function(position, result) {
      var child, nextPosition, _i, _len, _ref2;
      _ref2 = this.children;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        child = _ref2[_i];
        if (position.isNegative()) {
          break;
        }
        nextPosition = position.traversalFrom(child.extent);
        if (!nextPosition.isPositive()) {
          child.findEndingAt(position, result);
        }
        position = nextPosition;
      }
    };

    Node.prototype.hasEmptyRightmostLeaf = function() {
      return this.children[this.children.length - 1].hasEmptyRightmostLeaf();
    };

    Node.prototype.hasEmptyLeftmostLeaf = function() {
      return this.children[0].hasEmptyLeftmostLeaf();
    };

    Node.prototype.getLeftmostIds = function() {
      return this.children[0].getLeftmostIds();
    };

    Node.prototype.getRightmostIds = function() {
      return last(this.children).getRightmostIds();
    };

    Node.prototype.merge = function(other) {
      var childCount, _ref2;
      childCount = this.children.length + other.children.length;
      if (childCount <= BRANCHING_THRESHOLD + 1) {
        if (last(this.children).merge(other.children[0])) {
          other.children.shift();
          childCount--;
        }
        if (childCount <= BRANCHING_THRESHOLD) {
          this.extent = this.extent.traverse(other.extent);
          addSet(this.ids, other.ids);
          (_ref2 = this.children).push.apply(_ref2, other.children);
          return true;
        }
      }
      return false;
    };

    Node.prototype.splitIfNeeded = function() {
      var branchingRatio, splitIndex;
      if ((branchingRatio = this.children.length / BRANCHING_THRESHOLD) > 1) {
        splitIndex = Math.ceil(branchingRatio);
        return [new Node(this.children.slice(0, splitIndex)), new Node(this.children.slice(splitIndex))];
      }
    };

    Node.prototype.mergeChildrenIfNeeded = function(i) {
      var _ref2;
      if ((_ref2 = this.children[i]) != null ? _ref2.merge(this.children[i + 1]) : void 0) {
        this.children.splice(i + 1, 1);
        return true;
      } else {
        return false;
      }
    };

    Node.prototype.toString = function(indentLevel) {
      var i, ids, indent, next, values, _i;
      if (indentLevel == null) {
        indentLevel = 0;
      }
      indent = "";
      for (i = _i = 0; _i < indentLevel; i = _i += 1) {
        indent += " ";
      }
      ids = [];
      values = this.ids.values();
      while (!(next = values.next()).done) {
        ids.push(next.value);
      }
      return "" + indent + "Node " + this.extent + " (" + (ids.join(" ")) + ")\n" + (this.children.map(function(c) {
        return c.toString(indentLevel + 2);
      }).join("\n"));
    };

    return Node;

  })();

  Leaf = (function() {
    function Leaf(extent, ids) {
      this.extent = extent;
      this.ids = ids;
    }

    Leaf.prototype.insert = function(ids, start, end) {
      var newIds, newLeaves;
      if (start.isZero() && end.compare(this.extent) === 0) {
        addSet(this.ids, ids);
      } else {
        newIds = new Set(this.ids);
        addSet(newIds, ids);
        newLeaves = [];
        if (start.isPositive()) {
          newLeaves.push(new Leaf(start, new Set(this.ids)));
        }
        newLeaves.push(new Leaf(end.traversalFrom(start), newIds));
        if (this.extent.compare(end) > 0) {
          newLeaves.push(new Leaf(this.extent.traversalFrom(end), new Set(this.ids)));
        }
        return newLeaves;
      }
    };

    Leaf.prototype["delete"] = function(id) {
      return this.ids["delete"](id);
    };

    Leaf.prototype.splice = function(position, spliceOldExtent, spliceNewExtent, exclusiveIds, precedingIds, followingIds) {
      var extentAfterChange, leftIds, spliceNewEnd, spliceOldEnd;
      if (position.isZero() && spliceOldExtent.isZero()) {
        leftIds = new Set(precedingIds);
        addSet(leftIds, this.ids);
        subtractSet(leftIds, exclusiveIds);
        if (this.extent.isZero()) {
          precedingIds.forEach((function(_this) {
            return function(id) {
              if (!followingIds.has(id)) {
                return _this.ids["delete"](id);
              }
            };
          })(this));
        }
        return [new Leaf(spliceNewExtent, leftIds), this];
      } else {
        spliceOldEnd = position.traverse(spliceOldExtent);
        spliceNewEnd = position.traverse(spliceNewExtent);
        extentAfterChange = this.extent.traversalFrom(spliceOldEnd);
        this.extent = spliceNewEnd.traverse(Point.max(Point.ZERO, extentAfterChange));
      }
    };

    Leaf.prototype.getStart = function(id) {
      if (this.ids.has(id)) {
        return Point.ZERO;
      }
    };

    Leaf.prototype.getEnd = function(id) {
      if (this.ids.has(id)) {
        return this.extent;
      }
    };

    Leaf.prototype.dump = function(ids, offset, snapshot) {
      var end, id, next, values, _base;
      end = offset.traverse(this.extent);
      values = this.ids.values();
      while (!(next = values.next()).done) {
        id = next.value;
        if ((!ids) || ids.has(id)) {
          if (snapshot[id] == null) {
            snapshot[id] = templateRange();
          }
          if ((_base = snapshot[id]).start == null) {
            _base.start = offset;
          }
          snapshot[id].end = end;
        }
      }
      return end;
    };

    Leaf.prototype.findEndingAt = function(position, result) {
      if (position.isEqual(this.extent)) {
        addSet(result, this.ids);
      } else if (position.isZero()) {
        subtractSet(result, this.ids);
      }
    };

    Leaf.prototype.findStartingAt = function(position, result, previousIds) {
      if (position.isZero()) {
        this.ids.forEach(function(id) {
          if (!previousIds.has(id)) {
            return result.add(id);
          }
        });
      }
    };

    Leaf.prototype.findContaining = function(point, set) {
      return addSet(set, this.ids);
    };

    Leaf.prototype.findIntersecting = function(start, end, set) {
      return addSet(set, this.ids);
    };

    Leaf.prototype.hasEmptyRightmostLeaf = function() {
      return this.extent.isZero();
    };

    Leaf.prototype.hasEmptyLeftmostLeaf = function() {
      return this.extent.isZero();
    };

    Leaf.prototype.getLeftmostIds = function() {
      return this.ids;
    };

    Leaf.prototype.getRightmostIds = function() {
      return this.ids;
    };

    Leaf.prototype.merge = function(other) {
      if (setEqual(this.ids, other.ids) || this.extent.isZero() && other.extent.isZero()) {
        this.extent = this.extent.traverse(other.extent);
        addSet(this.ids, other.ids);
        return true;
      } else {
        return false;
      }
    };

    Leaf.prototype.toString = function(indentLevel) {
      var i, ids, indent, next, values, _i;
      if (indentLevel == null) {
        indentLevel = 0;
      }
      indent = "";
      for (i = _i = 0; _i < indentLevel; i = _i += 1) {
        indent += " ";
      }
      ids = [];
      values = this.ids.values();
      while (!(next = values.next()).done) {
        ids.push(next.value);
      }
      return "" + indent + "Leaf " + this.extent + " (" + (ids.join(" ")) + ")";
    };

    return Leaf;

  })();

  module.exports = MarkerIndex = (function() {
    function MarkerIndex() {
      this.clear();
    }

    MarkerIndex.prototype.insert = function(id, start, end) {
      var splitNodes;
      assertValidId(id);
      this.rangeCache[id] = Range(start, end);
      if (splitNodes = this.rootNode.insert(new Set().add(id + ""), start, end)) {
        return this.rootNode = new Node(splitNodes);
      }
    };

    MarkerIndex.prototype["delete"] = function(id) {
      assertValidId(id);
      delete this.rangeCache[id];
      this.rootNode["delete"](id);
      return this.condenseIfNeeded();
    };

    MarkerIndex.prototype.splice = function(position, oldExtent, newExtent) {
      var splitNodes;
      this.clearRangeCache();
      if (splitNodes = this.rootNode.splice(position, oldExtent, newExtent, this.exclusiveIds, new Set, new Set)) {
        this.rootNode = new Node(splitNodes);
      }
      return this.condenseIfNeeded();
    };

    MarkerIndex.prototype.isExclusive = function(id) {
      return this.exclusiveIds.has(id);
    };

    MarkerIndex.prototype.setExclusive = function(id, isExclusive) {
      assertValidId(id);
      if (isExclusive) {
        return this.exclusiveIds.add(id);
      } else {
        return this.exclusiveIds["delete"](id);
      }
    };

    MarkerIndex.prototype.getRange = function(id) {
      var start;
      if (start = this.getStart(id)) {
        return Range(start, this.getEnd(id));
      }
    };

    MarkerIndex.prototype.getStart = function(id) {
      var entry, _base;
      if (!this.rootNode.ids.has(id)) {
        return;
      }
      entry = (_base = this.rangeCache)[id] != null ? _base[id] : _base[id] = templateRange();
      return entry.start != null ? entry.start : entry.start = this.rootNode.getStart(id);
    };

    MarkerIndex.prototype.getEnd = function(id) {
      var entry, _base;
      if (!this.rootNode.ids.has(id)) {
        return;
      }
      entry = (_base = this.rangeCache)[id] != null ? _base[id] : _base[id] = templateRange();
      return entry.end != null ? entry.end : entry.end = this.rootNode.getEnd(id);
    };

    MarkerIndex.prototype.findContaining = function(start, end) {
      var containing, containingEnd;
      containing = new Set;
      this.rootNode.findContaining(start, containing);
      if ((end != null) && end.compare(start) !== 0) {
        containingEnd = new Set;
        this.rootNode.findContaining(end, containingEnd);
        containing.forEach(function(id) {
          if (!containingEnd.has(id)) {
            return containing["delete"](id);
          }
        });
      }
      return containing;
    };

    MarkerIndex.prototype.findContainedIn = function(start, end) {
      var result;
      if (end == null) {
        end = start;
      }
      result = this.findStartingIn(start, end);
      subtractSet(result, this.findIntersecting(end.traverse(Point(0, 1))));
      return result;
    };

    MarkerIndex.prototype.findIntersecting = function(start, end) {
      var intersecting;
      if (end == null) {
        end = start;
      }
      intersecting = new Set;
      this.rootNode.findIntersecting(start, end, intersecting);
      return intersecting;
    };

    MarkerIndex.prototype.findStartingIn = function(start, end) {
      var previousPoint, result;
      if (end != null) {
        result = this.findIntersecting(start, end);
        if (start.isPositive()) {
          if (start.column === 0) {
            previousPoint = Point(start.row - 1, Infinity);
          } else {
            previousPoint = Point(start.row, start.column - 1);
          }
          subtractSet(result, this.findIntersecting(previousPoint));
        }
        return result;
      } else {
        result = new Set;
        this.rootNode.findStartingAt(start, result, new Set);
        return result;
      }
    };

    MarkerIndex.prototype.findEndingIn = function(start, end) {
      var result;
      if (end != null) {
        result = this.findIntersecting(start, end);
        subtractSet(result, this.findIntersecting(end.traverse(Point(0, 1))));
        return result;
      } else {
        result = new Set;
        this.rootNode.findEndingAt(start, result);
        return result;
      }
    };

    MarkerIndex.prototype.clear = function() {
      this.rootNode = new Leaf(Point.INFINITY, new Set);
      this.exclusiveIds = new Set;
      return this.clearRangeCache();
    };

    MarkerIndex.prototype.dump = function(ids) {
      var result;
      result = {};
      this.rootNode.dump(ids, Point.ZERO, result);
      extend(this.rangeCache, result);
      return result;
    };


    /*
    Section: Private
     */

    MarkerIndex.prototype.clearRangeCache = function() {
      return this.rangeCache = {};
    };

    MarkerIndex.prototype.condenseIfNeeded = function() {
      var _ref2;
      while (((_ref2 = this.rootNode.children) != null ? _ref2.length : void 0) === 1) {
        this.rootNode = this.rootNode.children[0];
      }
    };

    return MarkerIndex;

  })();

  assertValidId = function(id) {
    if (typeof id !== 'string') {
      throw new TypeError("Marker ID must be a string");
    }
  };

  templateRange = function() {
    return Object.create(Range.prototype);
  };

  setsOverlap = function(set1, set2) {
    var next, values;
    values = set1.values();
    while (!(next = values.next()).done) {
      if (set2.has(next.value)) {
        return true;
      }
    }
    return false;
  };

}).call(this);

}),
  "./set-helpers": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var addSet, intersectSet, setEqual, subtractSet;

  setEqual = function(a, b) {
    var iterator, next;
    if (a.size !== b.size) {
      return false;
    }
    iterator = a.values();
    while (!(next = iterator.next()).done) {
      if (!b.has(next.value)) {
        return false;
      }
    }
    return true;
  };

  subtractSet = function(set, valuesToRemove) {
    if (set.size > valuesToRemove.size) {
      return valuesToRemove.forEach(function(value) {
        return set["delete"](value);
      });
    } else {
      return set.forEach(function(value) {
        if (valuesToRemove.has(value)) {
          return set["delete"](value);
        }
      });
    }
  };

  addSet = function(set, valuesToAdd) {
    return valuesToAdd.forEach(function(value) {
      return set.add(value);
    });
  };

  intersectSet = function(set, other) {
    return set.forEach(function(value) {
      if (!other.has(value)) {
        return set["delete"](value);
      }
    });
  };

  module.exports = {
    setEqual: setEqual,
    subtractSet: subtractSet,
    addSet: addSet,
    intersectSet: intersectSet
  };

}).call(this);

}),
  "./history": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var Checkpoint, GroupEnd, GroupStart, History, SerializationVersion;

  SerializationVersion = 3;

  Checkpoint = (function() {
    function Checkpoint(id, snapshot, isBoundary) {
      var _ref;
      this.id = id;
      this.snapshot = snapshot;
      this.isBoundary = isBoundary;
      if (this.snapshot == null) {
        if ((_ref = global.atom) != null) {
          _ref.assert(false, "Checkpoint created without snapshot");
        }
        this.snapshot = {};
      }
    }

    return Checkpoint;

  })();

  GroupStart = (function() {
    function GroupStart(snapshot) {
      this.snapshot = snapshot;
    }

    return GroupStart;

  })();

  GroupEnd = (function() {
    function GroupEnd(snapshot) {
      this.snapshot = snapshot;
      this.timestamp = Date.now();
      this.groupingInterval = 0;
    }

    return GroupEnd;

  })();

  module.exports = History = (function() {
    History.deserialize = function(delegate, state) {
      var history;
      history = new History(delegate);
      history.deserialize(state);
      return history;
    };

    function History(delegate, maxUndoEntries) {
      this.delegate = delegate;
      this.maxUndoEntries = maxUndoEntries;
      this.nextCheckpointId = 0;
      this.undoStack = [];
      this.redoStack = [];
    }

    History.prototype.createCheckpoint = function(snapshot, isBoundary) {
      var checkpoint;
      checkpoint = new Checkpoint(this.nextCheckpointId++, snapshot, isBoundary);
      this.undoStack.push(checkpoint);
      return checkpoint.id;
    };

    History.prototype.groupChangesSinceCheckpoint = function(checkpointId, endSnapshot, deleteCheckpoint) {
      var changesSinceCheckpoint, checkpointIndex, entry, i, startSnapshot, withinGroup, _i, _ref, _ref1;
      if (deleteCheckpoint == null) {
        deleteCheckpoint = false;
      }
      withinGroup = false;
      checkpointIndex = null;
      startSnapshot = null;
      changesSinceCheckpoint = [];
      _ref = this.undoStack;
      for (i = _i = _ref.length - 1; _i >= 0; i = _i += -1) {
        entry = _ref[i];
        if (checkpointIndex != null) {
          break;
        }
        switch (entry.constructor) {
          case GroupEnd:
            withinGroup = true;
            break;
          case GroupStart:
            if (withinGroup) {
              withinGroup = false;
            } else {
              return false;
            }
            break;
          case Checkpoint:
            if (entry.id === checkpointId) {
              checkpointIndex = i;
              startSnapshot = entry.snapshot;
            } else if (entry.isBoundary) {
              return false;
            }
            break;
          default:
            changesSinceCheckpoint.unshift(entry);
        }
      }
      if (checkpointIndex != null) {
        if (changesSinceCheckpoint.length > 0) {
          this.undoStack.splice(checkpointIndex + 1);
          this.undoStack.push(new GroupStart(startSnapshot));
          (_ref1 = this.undoStack).push.apply(_ref1, changesSinceCheckpoint);
          this.undoStack.push(new GroupEnd(endSnapshot));
        }
        if (deleteCheckpoint) {
          this.undoStack.splice(checkpointIndex, 1);
        }
        return true;
      } else {
        return false;
      }
    };

    History.prototype.applyGroupingInterval = function(groupingInterval) {
      var entry, i, previousEntry, topEntry, _i, _ref;
      topEntry = this.undoStack[this.undoStack.length - 1];
      if (topEntry instanceof GroupEnd) {
        topEntry.groupingInterval = groupingInterval;
      } else {
        return;
      }
      if (groupingInterval === 0) {
        return;
      }
      _ref = this.undoStack;
      for (i = _i = _ref.length - 1; _i >= 0; i = _i += -1) {
        entry = _ref[i];
        if (entry instanceof GroupStart) {
          previousEntry = this.undoStack[i - 1];
          if (previousEntry instanceof GroupEnd) {
            if (topEntry.timestamp - previousEntry.timestamp < Math.min(previousEntry.groupingInterval, groupingInterval)) {
              this.undoStack.splice(i - 1, 2);
            }
          }
          return;
        }
      }
      throw new Error("Didn't find matching group-start entry");
    };

    History.prototype.pushChange = function(change) {
      var entry, i, spliceIndex, withinGroup, _i, _len, _ref;
      this.undoStack.push(change);
      this.clearRedoStack();
      if (this.undoStack.length - this.maxUndoEntries > 0) {
        spliceIndex = null;
        withinGroup = false;
        _ref = this.undoStack;
        for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
          entry = _ref[i];
          if (spliceIndex != null) {
            break;
          }
          switch (entry.constructor) {
            case GroupStart:
              if (withinGroup) {
                throw new Error("Invalid undo stack state");
              } else {
                withinGroup = true;
              }
              break;
            case GroupEnd:
              if (withinGroup) {
                spliceIndex = i;
              } else {
                throw new Error("Invalid undo stack state");
              }
          }
        }
        if (spliceIndex != null) {
          return this.undoStack.splice(0, spliceIndex + 1);
        }
      }
    };

    History.prototype.popUndoStack = function() {
      var entry, i, invertedChanges, snapshotBelow, spliceIndex, withinGroup, _i, _ref, _ref1;
      snapshotBelow = null;
      spliceIndex = null;
      withinGroup = false;
      invertedChanges = [];
      _ref = this.undoStack;
      for (i = _i = _ref.length - 1; _i >= 0; i = _i += -1) {
        entry = _ref[i];
        if (spliceIndex != null) {
          break;
        }
        switch (entry.constructor) {
          case GroupStart:
            if (withinGroup) {
              snapshotBelow = entry.snapshot;
              spliceIndex = i;
            } else {
              return false;
            }
            break;
          case GroupEnd:
            if (withinGroup) {
              throw new Error("Invalid undo stack state");
            } else {
              withinGroup = true;
            }
            break;
          case Checkpoint:
            if (entry.isBoundary) {
              return false;
            }
            break;
          default:
            invertedChanges.push(this.delegate.invertChange(entry));
            if (!withinGroup) {
              spliceIndex = i;
            }
        }
      }
      if (spliceIndex != null) {
        (_ref1 = this.redoStack).push.apply(_ref1, this.undoStack.splice(spliceIndex).reverse());
        return {
          snapshot: snapshotBelow,
          changes: invertedChanges
        };
      } else {
        return false;
      }
    };

    History.prototype.popRedoStack = function() {
      var changes, entry, i, snapshotBelow, spliceIndex, withinGroup, _i, _ref, _ref1;
      snapshotBelow = null;
      spliceIndex = null;
      withinGroup = false;
      changes = [];
      _ref = this.redoStack;
      for (i = _i = _ref.length - 1; _i >= 0; i = _i += -1) {
        entry = _ref[i];
        if (spliceIndex != null) {
          break;
        }
        switch (entry.constructor) {
          case GroupEnd:
            if (withinGroup) {
              snapshotBelow = entry.snapshot;
              spliceIndex = i;
            } else {
              return false;
            }
            break;
          case GroupStart:
            if (withinGroup) {
              throw new Error("Invalid redo stack state");
            } else {
              withinGroup = true;
            }
            break;
          case Checkpoint:
            if (entry.isBoundary) {
              throw new Error("Invalid redo stack state");
            }
            break;
          default:
            changes.push(entry);
            if (!withinGroup) {
              spliceIndex = i;
            }
        }
      }
      while (this.redoStack[spliceIndex - 1] instanceof Checkpoint) {
        spliceIndex--;
      }
      if (spliceIndex != null) {
        (_ref1 = this.undoStack).push.apply(_ref1, this.redoStack.splice(spliceIndex).reverse());
        return {
          snapshot: snapshotBelow,
          changes: changes
        };
      } else {
        return false;
      }
    };

    History.prototype.truncateUndoStack = function(checkpointId) {
      var entry, i, invertedChanges, snapshotBelow, spliceIndex, withinGroup, _i, _ref;
      snapshotBelow = null;
      spliceIndex = null;
      withinGroup = false;
      invertedChanges = [];
      _ref = this.undoStack;
      for (i = _i = _ref.length - 1; _i >= 0; i = _i += -1) {
        entry = _ref[i];
        if (spliceIndex != null) {
          break;
        }
        switch (entry.constructor) {
          case GroupStart:
            if (withinGroup) {
              withinGroup = false;
            } else {
              return false;
            }
            break;
          case GroupEnd:
            if (withinGroup) {
              throw new Error("Invalid undo stack state");
            } else {
              withinGroup = true;
            }
            break;
          case Checkpoint:
            if (entry.id === checkpointId) {
              spliceIndex = i;
              snapshotBelow = entry.snapshot;
            } else if (entry.isBoundary) {
              return false;
            }
            break;
          default:
            invertedChanges.push(this.delegate.invertChange(entry));
        }
      }
      if (spliceIndex != null) {
        this.undoStack.splice(spliceIndex);
        return {
          snapshot: snapshotBelow,
          changes: invertedChanges
        };
      } else {
        return false;
      }
    };

    History.prototype.clearUndoStack = function() {
      return this.undoStack.length = 0;
    };

    History.prototype.clearRedoStack = function() {
      return this.redoStack.length = 0;
    };

    History.prototype.serialize = function() {
      return {
        version: SerializationVersion,
        nextCheckpointId: this.nextCheckpointId,
        undoStack: this.serializeStack(this.undoStack),
        redoStack: this.serializeStack(this.redoStack)
      };
    };

    History.prototype.deserialize = function(state) {
      if (state.version !== SerializationVersion) {
        return;
      }
      this.nextCheckpointId = state.nextCheckpointId;
      this.maxUndoEntries = state.maxUndoEntries;
      this.undoStack = this.deserializeStack(state.undoStack);
      return this.redoStack = this.deserializeStack(state.redoStack);
    };


    /*
    Section: Private
     */

    History.prototype.getCheckpointIndex = function(checkpointId) {
      var entry, i, _i, _ref;
      _ref = this.undoStack;
      for (i = _i = _ref.length - 1; _i >= 0; i = _i += -1) {
        entry = _ref[i];
        if (entry instanceof Checkpoint && entry.id === checkpointId) {
          return i;
        }
      }
      return null;
    };

    History.prototype.serializeStack = function(stack) {
      var entry, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = stack.length; _i < _len; _i++) {
        entry = stack[_i];
        switch (entry.constructor) {
          case Checkpoint:
            _results.push({
              type: 'checkpoint',
              id: entry.id,
              snapshot: this.delegate.serializeSnapshot(entry.snapshot),
              isBoundary: entry.isBoundary
            });
            break;
          case GroupStart:
            _results.push({
              type: 'group-start',
              snapshot: this.delegate.serializeSnapshot(entry.snapshot)
            });
            break;
          case GroupEnd:
            _results.push({
              type: 'group-end',
              snapshot: this.delegate.serializeSnapshot(entry.snapshot)
            });
            break;
          default:
            _results.push({
              type: 'change',
              content: this.delegate.serializeChange(entry)
            });
        }
      }
      return _results;
    };

    History.prototype.deserializeStack = function(stack) {
      var entry, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = stack.length; _i < _len; _i++) {
        entry = stack[_i];
        switch (entry.type) {
          case 'checkpoint':
            _results.push(new Checkpoint(entry.id, this.delegate.deserializeSnapshot(entry.snapshot), entry.isBoundary));
            break;
          case 'group-start':
            _results.push(new GroupStart(this.delegate.deserializeSnapshot(entry.snapshot)));
            break;
          case 'group-end':
            _results.push(new GroupEnd(this.delegate.deserializeSnapshot(entry.snapshot)));
            break;
          case 'change':
            _results.push(this.delegate.deserializeChange(entry.content));
            break;
          default:
            _results.push(void 0);
        }
      }
      return _results;
    };

    return History;

  })();

}).call(this);

}),
  "atom-diff": (function (exports, require, module, __filename, __dirname, process, global) { /* See LICENSE file for terms of use */

/*
 * Text diff implementation.
 *
 * This library supports the following APIS:
 * JsDiff.diffChars: Character by character diff
 * JsDiff.diffWords: Word (as defined by \b regex) diff which ignores whitespace
 * JsDiff.diffLines: Line based diff
 *
 * JsDiff.diffCss: Diff targeted at CSS content
 *
 * These methods are based on the implementation proposed in
 * "An O(ND) Difference Algorithm and its Variations" (Myers, 1986).
 * http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.4.6927
 */
var JsDiff = (function() {
  /*jshint maxparams: 5*/
  function clonePath(path) {
    return { newPos: path.newPos, components: path.components.slice(0) };
  }
  function removeEmpty(array) {
    var ret = [];
    for (var i = 0; i < array.length; i++) {
      if (array[i]) {
        ret.push(array[i]);
      }
    }
    return ret;
  }
  function escapeHTML(s) {
    var n = s;
    n = n.replace(/&/g, '&amp;');
    n = n.replace(/</g, '&lt;');
    n = n.replace(/>/g, '&gt;');
    n = n.replace(/"/g, '&quot;');

    return n;
  }

  var Diff = function(ignoreWhitespace) {
    this.ignoreWhitespace = ignoreWhitespace;
  };
  Diff.prototype = {
      diff: function(oldString, newString) {
        // Handle the identity case (this is due to unrolling editLength == 0
        if (newString === oldString) {
          return [{ value: newString }];
        }
        if (!newString) {
          return [{ value: oldString, removed: true }];
        }
        if (!oldString) {
          return [{ value: newString, added: true }];
        }

        newString = this.tokenize(newString);
        oldString = this.tokenize(oldString);

        var newLen = newString.length, oldLen = oldString.length;
        var maxEditLength = newLen + oldLen;
        var bestPath = [{ newPos: -1, components: [] }];

        // Seed editLength = 0
        var oldPos = this.extractCommon(bestPath[0], newString, oldString, 0);
        if (bestPath[0].newPos+1 >= newLen && oldPos+1 >= oldLen) {
          return bestPath[0].components;
        }

        for (var editLength = 1; editLength <= maxEditLength; editLength++) {
          for (var diagonalPath = -1*editLength; diagonalPath <= editLength; diagonalPath+=2) {
            var basePath;
            var addPath = bestPath[diagonalPath-1],
                removePath = bestPath[diagonalPath+1];
            oldPos = (removePath ? removePath.newPos : 0) - diagonalPath;
            if (addPath) {
              // No one else is going to attempt to use this value, clear it
              bestPath[diagonalPath-1] = undefined;
            }

            var canAdd = addPath && addPath.newPos+1 < newLen;
            var canRemove = removePath && 0 <= oldPos && oldPos < oldLen;
            if (!canAdd && !canRemove) {
              bestPath[diagonalPath] = undefined;
              continue;
            }

            // Select the diagonal that we want to branch from. We select the prior
            // path whose position in the new string is the farthest from the origin
            // and does not pass the bounds of the diff graph
            if (!canAdd || (canRemove && addPath.newPos < removePath.newPos)) {
              basePath = clonePath(removePath);
              this.pushComponent(basePath.components, oldString[oldPos], undefined, true);
            } else {
              basePath = clonePath(addPath);
              basePath.newPos++;
              this.pushComponent(basePath.components, newString[basePath.newPos], true, undefined);
            }

            var oldPos = this.extractCommon(basePath, newString, oldString, diagonalPath);

            if (basePath.newPos+1 >= newLen && oldPos+1 >= oldLen) {
              return basePath.components;
            } else {
              bestPath[diagonalPath] = basePath;
            }
          }
        }
      },

      pushComponent: function(components, value, added, removed) {
        var last = components[components.length-1];
        if (last && last.added === added && last.removed === removed) {
          // We need to clone here as the component clone operation is just
          // as shallow array clone
          components[components.length-1] =
            {value: this.join(last.value, value), added: added, removed: removed };
        } else {
          components.push({value: value, added: added, removed: removed });
        }
      },
      extractCommon: function(basePath, newString, oldString, diagonalPath) {
        var newLen = newString.length,
            oldLen = oldString.length,
            newPos = basePath.newPos,
            oldPos = newPos - diagonalPath;
        while (newPos+1 < newLen && oldPos+1 < oldLen && this.equals(newString[newPos+1], oldString[oldPos+1])) {
          newPos++;
          oldPos++;

          this.pushComponent(basePath.components, newString[newPos], undefined, undefined);
        }
        basePath.newPos = newPos;
        return oldPos;
      },

      equals: function(left, right) {
        var reWhitespace = /\S/;
        if (this.ignoreWhitespace && !reWhitespace.test(left) && !reWhitespace.test(right)) {
          return true;
        } else {
          return left === right;
        }
      },
      join: function(left, right) {
        return left + right;
      },
      tokenize: function(value) {
        return value;
      }
  };

  var CharDiff = new Diff();

  var WordDiff = new Diff(true);
  var WordWithSpaceDiff = new Diff();
  WordDiff.tokenize = WordWithSpaceDiff.tokenize = function(value) {
    return removeEmpty(value.split(/(\s+|\b)/));
  };

  var CssDiff = new Diff(true);
  CssDiff.tokenize = function(value) {
    return removeEmpty(value.split(/([{}:;,]|\s+)/));
  };

  var LineDiff = new Diff();
  LineDiff.tokenize = function(value) {
    var retLines = [];
    var lines = value.split(/^/m);

    for(var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var lastLine = lines[i - 1];

      if(line == '\n' && lastLine && lastLine.indexOf('\r') == lastLine.length - 1)
        retLines[retLines.length - 1] += '\n';
      else if(line)
        retLines.push(line);
    }

    return retLines;
  };

  return {
    Diff: Diff,

    diffChars: function(oldStr, newStr) { return CharDiff.diff(oldStr, newStr); },
    diffWords: function(oldStr, newStr) { return WordDiff.diff(oldStr, newStr); },
    diffWordsWithSpace: function(oldStr, newStr) { return WordWithSpaceDiff.diff(oldStr, newStr); },
    diffLines: function(oldStr, newStr) { return LineDiff.diff(oldStr, newStr); },

    diffCss: function(oldStr, newStr) { return CssDiff.diff(oldStr, newStr); },

    createPatch: function(fileName, oldStr, newStr, oldHeader, newHeader) {
      var ret = [];

      ret.push('Index: ' + fileName);
      ret.push('===================================================================');
      ret.push('--- ' + fileName + (typeof oldHeader === 'undefined' ? '' : '\t' + oldHeader));
      ret.push('+++ ' + fileName + (typeof newHeader === 'undefined' ? '' : '\t' + newHeader));

      var diff = LineDiff.diff(oldStr, newStr);
      if (!diff[diff.length-1].value) {
        diff.pop();   // Remove trailing newline add
      }
      diff.push({value: '', lines: []});   // Append an empty value to make cleanup easier

      function contextLines(lines) {
        return lines.map(function(entry) { return ' ' + entry; });
      }
      function eofNL(curRange, i, current) {
        var last = diff[diff.length-2],
            isLast = i === diff.length-2,
            isLastOfType = i === diff.length-3 && (current.added !== last.added || current.removed !== last.removed);

        // Figure out if this is the last line for the given file and missing NL
        if (!/\n$/.test(current.value) && (isLast || isLastOfType)) {
          curRange.push('\\ No newline at end of file');
        }
      }

      var oldRangeStart = 0, newRangeStart = 0, curRange = [],
          oldLine = 1, newLine = 1;
      for (var i = 0; i < diff.length; i++) {
        var current = diff[i],
            lines = current.lines || current.value.replace(/\n$/, '').split('\n');
        current.lines = lines;

        if (current.added || current.removed) {
          if (!oldRangeStart) {
            var prev = diff[i-1];
            oldRangeStart = oldLine;
            newRangeStart = newLine;

            if (prev) {
              curRange = contextLines(prev.lines.slice(-4));
              oldRangeStart -= curRange.length;
              newRangeStart -= curRange.length;
            }
          }
          curRange.push.apply(curRange, lines.map(function(entry) { return (current.added?'+':'-') + entry; }));
          eofNL(curRange, i, current);

          if (current.added) {
            newLine += lines.length;
          } else {
            oldLine += lines.length;
          }
        } else {
          if (oldRangeStart) {
            // Close out any changes that have been output (or join overlapping)
            if (lines.length <= 8 && i < diff.length-2) {
              // Overlapping
              curRange.push.apply(curRange, contextLines(lines));
            } else {
              // end the range and output
              var contextSize = Math.min(lines.length, 4);
              ret.push(
                  '@@ -' + oldRangeStart + ',' + (oldLine-oldRangeStart+contextSize)
                  + ' +' + newRangeStart + ',' + (newLine-newRangeStart+contextSize)
                  + ' @@');
              ret.push.apply(ret, curRange);
              ret.push.apply(ret, contextLines(lines.slice(0, contextSize)));
              if (lines.length <= 4) {
                eofNL(ret, i, current);
              }

              oldRangeStart = 0;  newRangeStart = 0; curRange = [];
            }
          }
          oldLine += lines.length;
          newLine += lines.length;
        }
      }

      return ret.join('\n') + '\n';
    },

    applyPatch: function(oldStr, uniDiff) {
      var diffstr = uniDiff.split('\n');
      var diff = [];
      var remEOFNL = false,
          addEOFNL = false;

      for (var i = (diffstr[0][0]==='I'?4:0); i < diffstr.length; i++) {
        if(diffstr[i][0] === '@') {
          var meh = diffstr[i].split(/@@ -(\d+),(\d+) \+(\d+),(\d+) @@/);
          diff.unshift({
            start:meh[3],
            oldlength:meh[2],
            oldlines:[],
            newlength:meh[4],
            newlines:[]
          });
        } else if(diffstr[i][0] === '+') {
          diff[0].newlines.push(diffstr[i].substr(1));
        } else if(diffstr[i][0] === '-') {
          diff[0].oldlines.push(diffstr[i].substr(1));
        } else if(diffstr[i][0] === ' ') {
          diff[0].newlines.push(diffstr[i].substr(1));
          diff[0].oldlines.push(diffstr[i].substr(1));
        } else if(diffstr[i][0] === '\\') {
          if (diffstr[i-1][0] === '+') {
            remEOFNL = true;
          } else if(diffstr[i-1][0] === '-') {
            addEOFNL = true;
          }
        }
      }

      var str = oldStr.split('\n');
      for (var i = diff.length - 1; i >= 0; i--) {
        var d = diff[i];
        for (var j = 0; j < d.oldlength; j++) {
          if(str[d.start-1+j] !== d.oldlines[j]) {
            return false;
          }
        }
        Array.prototype.splice.apply(str,[d.start-1,+d.oldlength].concat(d.newlines));
      }

      if (remEOFNL) {
        while (!str[str.length-1]) {
          str.pop();
        }
      } else if (addEOFNL) {
        str.push('');
      }
      return str.join('\n');
    },

    convertChangesToXML: function(changes){
      var ret = [];
      for ( var i = 0; i < changes.length; i++) {
        var change = changes[i];
        if (change.added) {
          ret.push('<ins>');
        } else if (change.removed) {
          ret.push('<del>');
        }

        ret.push(escapeHTML(change.value));

        if (change.added) {
          ret.push('</ins>');
        } else if (change.removed) {
          ret.push('</del>');
        }
      }
      return ret.join('');
    },

    // See: http://code.google.com/p/google-diff-match-patch/wiki/API
    convertChangesToDMP: function(changes){
      var ret = [], change;
      for ( var i = 0; i < changes.length; i++) {
        change = changes[i];
        ret.push([(change.added ? 1 : change.removed ? -1 : 0), change.value]);
      }
      return ret;
    }
  };
})();

if (typeof module !== 'undefined') {
    module.exports = JsDiff;
}

}),
  "./patch": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var BRANCHING_THRESHOLD, ChangeIterator, Leaf, Node, Patch, Point, RegionIterator, isEmpty, last,
    __slice = [].slice;

  Point = require("./point");

  last = function(array) {
    return array[array.length - 1];
  };

  isEmpty = function(node) {
    return node.inputExtent.isZero() && node.outputExtent.isZero();
  };

  BRANCHING_THRESHOLD = 3;

  Node = (function() {
    function Node(children) {
      this.children = children;
      this.calculateExtent();
    }

    Node.prototype.splice = function(childIndex, splitChildren) {
      var inputOffset, leftMergeIndex, outputOffset, rightMergeIndex, rightNeighbor, spliceChild, splitIndex, splitNodes, _ref, _ref1;
      spliceChild = this.children[childIndex];
      leftMergeIndex = rightMergeIndex = childIndex;
      if (splitChildren != null) {
        (_ref = this.children).splice.apply(_ref, [childIndex, 1].concat(__slice.call(splitChildren)));
        childIndex += splitChildren.indexOf(spliceChild);
        rightMergeIndex += splitChildren.length - 1;
      }
      if (rightNeighbor = this.children[rightMergeIndex + 1]) {
        this.children[rightMergeIndex].merge(rightNeighbor);
        if (isEmpty(rightNeighbor)) {
          this.children.splice(rightMergeIndex + 1, 1);
        }
      }
      splitIndex = Math.ceil(this.children.length / BRANCHING_THRESHOLD);
      if (splitIndex > 1) {
        if (childIndex < splitIndex) {
          splitNodes = [this, new Node(this.children.splice(splitIndex))];
        } else {
          splitNodes = [new Node(this.children.splice(0, splitIndex)), this];
          childIndex -= splitIndex;
        }
      }
      _ref1 = this.calculateExtent(childIndex), inputOffset = _ref1.inputOffset, outputOffset = _ref1.outputOffset;
      return {
        splitNodes: splitNodes,
        inputOffset: inputOffset,
        outputOffset: outputOffset,
        childIndex: childIndex
      };
    };

    Node.prototype.merge = function(rightNeighbor) {
      var childMerge, result, _ref, _ref1;
      childMerge = (_ref = last(this.children)) != null ? _ref.merge(rightNeighbor.children[0]) : void 0;
      if (isEmpty(rightNeighbor.children[0])) {
        rightNeighbor.children.shift();
      }
      if (this.children.length + rightNeighbor.children.length <= BRANCHING_THRESHOLD) {
        this.inputExtent = this.inputExtent.traverse(rightNeighbor.inputExtent);
        this.outputExtent = this.outputExtent.traverse(rightNeighbor.outputExtent);
        (_ref1 = this.children).push.apply(_ref1, rightNeighbor.children);
        result = {
          inputExtent: rightNeighbor.inputExtent,
          outputExtent: rightNeighbor.outputExtent
        };
        rightNeighbor.inputExtent = rightNeighbor.outputExtent = Point.ZERO;
        return result;
      } else if (childMerge != null) {
        this.inputExtent = this.inputExtent.traverse(childMerge.inputExtent);
        this.outputExtent = this.outputExtent.traverse(childMerge.outputExtent);
        rightNeighbor.inputExtent = rightNeighbor.inputExtent.traversalFrom(childMerge.inputExtent);
        rightNeighbor.outputExtent = rightNeighbor.outputExtent.traversalFrom(childMerge.outputExtent);
        return childMerge;
      }
    };

    Node.prototype.calculateExtent = function(childIndex) {
      var child, i, result, _i, _len, _ref;
      result = {
        inputOffset: null,
        outputOffset: null
      };
      this.inputExtent = Point.ZERO;
      this.outputExtent = Point.ZERO;
      _ref = this.children;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        child = _ref[i];
        if (i === childIndex) {
          result.inputOffset = this.inputExtent;
          result.outputOffset = this.outputExtent;
        }
        this.inputExtent = this.inputExtent.traverse(child.inputExtent);
        this.outputExtent = this.outputExtent.traverse(child.outputExtent);
      }
      return result;
    };

    Node.prototype.toString = function(indentLevel) {
      var i, indent, _i;
      if (indentLevel == null) {
        indentLevel = 0;
      }
      indent = "";
      for (i = _i = 0; _i < indentLevel; i = _i += 1) {
        indent += " ";
      }
      return "" + indent + "[Node " + this.inputExtent + " " + this.outputExtent + "]\n" + (this.children.map(function(c) {
        return c.toString(indentLevel + 2);
      }).join("\n"));
    };

    return Node;

  })();

  Leaf = (function() {
    function Leaf(inputExtent, outputExtent, content) {
      this.inputExtent = inputExtent;
      this.outputExtent = outputExtent;
      this.content = content;
    }

    Leaf.prototype.insert = function(inputOffset, outputOffset, newInputExtent, newOutputExtent, newContent) {
      var inputExtentAfterOffset, outputExtentAfterOffset, splitNodes;
      inputExtentAfterOffset = this.inputExtent.traversalFrom(inputOffset);
      outputExtentAfterOffset = this.outputExtent.traversalFrom(outputOffset);
      if (this.content != null) {
        this.inputExtent = inputOffset.traverse(newInputExtent).traverse(inputExtentAfterOffset);
        this.outputExtent = outputOffset.traverse(newOutputExtent).traverse(outputExtentAfterOffset);
        this.content = this.content.slice(0, outputOffset.column) + newContent + this.content.slice(outputOffset.column);
        inputOffset = inputOffset.traverse(newInputExtent);
        outputOffset = outputOffset.traverse(newOutputExtent);
      } else if (newInputExtent.isPositive() || newOutputExtent.isPositive()) {
        splitNodes = [];
        if (outputOffset.isPositive()) {
          splitNodes.push(new Leaf(inputOffset, outputOffset, null));
        }
        this.inputExtent = newInputExtent;
        this.outputExtent = newOutputExtent;
        this.content = newContent;
        splitNodes.push(this);
        if (outputExtentAfterOffset.isPositive()) {
          splitNodes.push(new Leaf(inputExtentAfterOffset, outputExtentAfterOffset, null));
        }
        inputOffset = this.inputExtent;
        outputOffset = this.outputExtent;
      }
      return {
        splitNodes: splitNodes,
        inputOffset: inputOffset,
        outputOffset: outputOffset
      };
    };

    Leaf.prototype.merge = function(rightNeighbor) {
      var result, _ref, _ref1;
      if (((this.content != null) === (rightNeighbor.content != null)) || isEmpty(this) || isEmpty(rightNeighbor)) {
        this.outputExtent = this.outputExtent.traverse(rightNeighbor.outputExtent);
        this.inputExtent = this.inputExtent.traverse(rightNeighbor.inputExtent);
        this.content = ((_ref = this.content) != null ? _ref : "") + ((_ref1 = rightNeighbor.content) != null ? _ref1 : "");
        if (this.content === "" && this.outputExtent.isPositive()) {
          this.content = null;
        }
        result = {
          inputExtent: rightNeighbor.inputExtent,
          outputExtent: rightNeighbor.outputExtent
        };
        rightNeighbor.inputExtent = rightNeighbor.outputExtent = Point.ZERO;
        rightNeighbor.content = null;
        return result;
      }
    };

    Leaf.prototype.toString = function(indentLevel) {
      var i, indent, _i;
      if (indentLevel == null) {
        indentLevel = 0;
      }
      indent = "";
      for (i = _i = 0; _i < indentLevel; i = _i += 1) {
        indent += " ";
      }
      if (this.content != null) {
        return "" + indent + "[Leaf " + this.inputExtent + " " + this.outputExtent + " " + (JSON.stringify(this.content)) + "]";
      } else {
        return "" + indent + "[Leaf " + this.inputExtent + " " + this.outputExtent + "]";
      }
    };

    return Leaf;

  })();

  RegionIterator = (function() {
    function RegionIterator(patch, path) {
      this.patch = patch;
      this.path = path;
      if (this.path == null) {
        this.path = [];
        this.descendToLeftmostLeaf(this.patch.rootNode);
      }
    }

    RegionIterator.prototype.next = function() {
      var entry, nextChild, parentEntry, value, _ref, _ref1;
      while ((entry = last(this.path)) && entry.inputOffset.isEqual(entry.node.inputExtent) && entry.outputOffset.isEqual(entry.node.outputExtent)) {
        this.path.pop();
        if (parentEntry = last(this.path)) {
          parentEntry.childIndex++;
          parentEntry.inputOffset = parentEntry.inputOffset.traverse(entry.inputOffset);
          parentEntry.outputOffset = parentEntry.outputOffset.traverse(entry.outputOffset);
          if (nextChild = parentEntry.node.children[parentEntry.childIndex]) {
            this.descendToLeftmostLeaf(nextChild);
            entry = last(this.path);
          }
        } else {
          this.path.push(entry);
          return {
            value: null,
            done: true
          };
        }
      }
      value = (_ref = (_ref1 = entry.node.content) != null ? _ref1.slice(entry.outputOffset.column) : void 0) != null ? _ref : null;
      entry.outputOffset = entry.node.outputExtent;
      entry.inputOffset = entry.node.inputExtent;
      return {
        value: value,
        done: false
      };
    };

    RegionIterator.prototype.seek = function(targetOutputOffset) {
      var child, childIndex, childInputEnd, childInputStart, childOutputEnd, childOutputStart, inputOffset, node, outputOffset, _i, _len, _ref;
      this.path.length = 0;
      node = this.patch.rootNode;
      while (true) {
        if (node.children != null) {
          childInputEnd = Point.ZERO;
          childOutputEnd = Point.ZERO;
          _ref = node.children;
          for (childIndex = _i = 0, _len = _ref.length; _i < _len; childIndex = ++_i) {
            child = _ref[childIndex];
            childInputStart = childInputEnd;
            childOutputStart = childOutputEnd;
            childInputEnd = childInputStart.traverse(child.inputExtent);
            childOutputEnd = childOutputStart.traverse(child.outputExtent);
            if (childOutputEnd.compare(targetOutputOffset) >= 0) {
              inputOffset = childInputStart;
              outputOffset = childOutputStart;
              this.path.push({
                node: node,
                childIndex: childIndex,
                inputOffset: inputOffset,
                outputOffset: outputOffset
              });
              targetOutputOffset = targetOutputOffset.traversalFrom(childOutputStart);
              node = child;
              break;
            }
          }
        } else {
          if (targetOutputOffset.isEqual(node.outputExtent)) {
            inputOffset = node.inputExtent;
          } else {
            inputOffset = Point.min(node.inputExtent, targetOutputOffset);
          }
          outputOffset = targetOutputOffset;
          childIndex = null;
          this.path.push({
            node: node,
            inputOffset: inputOffset,
            outputOffset: outputOffset,
            childIndex: childIndex
          });
          break;
        }
      }
      return this;
    };

    RegionIterator.prototype.seekToInputPosition = function(targetInputOffset) {
      var child, childIndex, childInputEnd, childInputStart, childOutputEnd, childOutputStart, inputOffset, node, outputOffset, _i, _len, _ref;
      this.path.length = 0;
      node = this.patch.rootNode;
      while (true) {
        if (node.children != null) {
          childInputEnd = Point.ZERO;
          childOutputEnd = Point.ZERO;
          _ref = node.children;
          for (childIndex = _i = 0, _len = _ref.length; _i < _len; childIndex = ++_i) {
            child = _ref[childIndex];
            childInputStart = childInputEnd;
            childOutputStart = childOutputEnd;
            childInputEnd = childInputStart.traverse(child.inputExtent);
            childOutputEnd = childOutputStart.traverse(child.outputExtent);
            if (childInputEnd.compare(targetInputOffset) >= 0) {
              inputOffset = childInputStart;
              outputOffset = childOutputStart;
              this.path.push({
                node: node,
                childIndex: childIndex,
                inputOffset: inputOffset,
                outputOffset: outputOffset
              });
              targetInputOffset = targetInputOffset.traversalFrom(childInputStart);
              node = child;
              break;
            }
          }
        } else {
          inputOffset = targetInputOffset;
          if (targetInputOffset.isEqual(node.inputExtent)) {
            outputOffset = node.outputExtent;
          } else {
            outputOffset = Point.min(node.outputExtent, targetInputOffset);
          }
          childIndex = null;
          this.path.push({
            node: node,
            inputOffset: inputOffset,
            outputOffset: outputOffset,
            childIndex: childIndex
          });
          break;
        }
      }
      return this;
    };

    RegionIterator.prototype.splice = function(oldOutputExtent, newExtent, newContent) {
      var inputExtent, rightEdge;
      rightEdge = this.copy().seek(this.getOutputPosition().traverse(oldOutputExtent));
      inputExtent = rightEdge.getInputPosition().traversalFrom(this.getInputPosition());
      this.deleteUntil(rightEdge);
      return this.insert(inputExtent, newExtent, newContent);
    };

    RegionIterator.prototype.getOutputPosition = function() {
      var entry, result, _i, _len, _ref;
      result = Point.ZERO;
      _ref = this.path;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        entry = _ref[_i];
        result = result.traverse(entry.outputOffset);
      }
      return result;
    };

    RegionIterator.prototype.getInputPosition = function() {
      var inputOffset, node, outputOffset, result, _i, _len, _ref, _ref1;
      result = Point.ZERO;
      _ref = this.path;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        _ref1 = _ref[_i], node = _ref1.node, inputOffset = _ref1.inputOffset, outputOffset = _ref1.outputOffset;
        result = result.traverse(inputOffset);
      }
      return result;
    };

    RegionIterator.prototype.copy = function() {
      return new RegionIterator(this.patch, this.path.slice());
    };

    RegionIterator.prototype.descendToLeftmostLeaf = function(node) {
      var entry, _results;
      _results = [];
      while (true) {
        entry = {
          node: node,
          outputOffset: Point.ZERO,
          inputOffset: Point.ZERO,
          childIndex: null
        };
        this.path.push(entry);
        if (node.children != null) {
          entry.childIndex = 0;
          _results.push(node = node.children[0]);
        } else {
          break;
        }
      }
      return _results;
    };

    RegionIterator.prototype.deleteUntil = function(rightIterator) {
      var childIndex, i, inputOffset, left, meetingIndex, node, outputOffset, right, spliceIndex, totalInputOffset, totalOutputOffset, _i, _j, _ref, _ref1, _ref2, _ref3;
      meetingIndex = null;
      totalInputOffset = Point.ZERO;
      totalOutputOffset = Point.ZERO;
      _ref = this.path;
      for (i = _i = _ref.length - 1; _i >= 0; i = _i += -1) {
        _ref1 = _ref[i], node = _ref1.node, inputOffset = _ref1.inputOffset, outputOffset = _ref1.outputOffset, childIndex = _ref1.childIndex;
        if (node === rightIterator.path[i].node) {
          meetingIndex = i;
          break;
        }
        if (node.content != null) {
          node.content = node.content.slice(0, outputOffset.column);
        } else if (node.children != null) {
          node.children.splice(childIndex + 1);
        }
        totalInputOffset = inputOffset.traverse(totalInputOffset);
        totalOutputOffset = outputOffset.traverse(totalOutputOffset);
        node.inputExtent = totalInputOffset;
        node.outputExtent = totalOutputOffset;
      }
      totalInputOffset = Point.ZERO;
      totalOutputOffset = Point.ZERO;
      _ref2 = rightIterator.path;
      for (i = _j = _ref2.length - 1; _j >= 0; i = _j += -1) {
        _ref3 = _ref2[i], node = _ref3.node, inputOffset = _ref3.inputOffset, outputOffset = _ref3.outputOffset, childIndex = _ref3.childIndex;
        if (i === meetingIndex) {
          break;
        }
        if (node.content != null) {
          node.content = node.content.slice(outputOffset.column);
        } else if (node.children != null) {
          if (isEmpty(node.children[childIndex])) {
            node.children.splice(childIndex, 1);
          }
          node.children.splice(0, childIndex);
        }
        totalInputOffset = inputOffset.traverse(totalInputOffset);
        totalOutputOffset = outputOffset.traverse(totalOutputOffset);
        node.inputExtent = node.inputExtent.traversalFrom(totalInputOffset);
        node.outputExtent = node.outputExtent.traversalFrom(totalOutputOffset);
      }
      left = this.path[meetingIndex];
      right = rightIterator.path[meetingIndex];
      node = left.node;
      node.outputExtent = left.outputOffset.traverse(node.outputExtent.traversalFrom(right.outputOffset));
      node.inputExtent = left.inputOffset.traverse(node.inputExtent.traversalFrom(right.inputOffset));
      if (node.content != null) {
        node.content = node.content.slice(0, left.outputOffset.column) + node.content.slice(right.outputOffset.column);
      } else if (node.children != null) {
        spliceIndex = left.childIndex + 1;
        if (isEmpty(node.children[right.childIndex])) {
          node.children.splice(right.childIndex, 1);
        }
        node.children.splice(spliceIndex, right.childIndex - spliceIndex);
      }
      return this;
    };

    RegionIterator.prototype.insert = function(newInputExtent, newOutputExtent, newContent) {
      var childIndex, entry, inputOffset, newPath, node, outputOffset, splitNodes, _i, _ref, _ref1, _ref2, _ref3, _ref4, _ref5;
      newPath = [];
      splitNodes = null;
      _ref = this.path;
      for (_i = _ref.length - 1; _i >= 0; _i += -1) {
        _ref1 = _ref[_i], node = _ref1.node, inputOffset = _ref1.inputOffset, outputOffset = _ref1.outputOffset, childIndex = _ref1.childIndex;
        if (node instanceof Leaf) {
          _ref2 = node.insert(inputOffset, outputOffset, newInputExtent, newOutputExtent, newContent), splitNodes = _ref2.splitNodes, inputOffset = _ref2.inputOffset, outputOffset = _ref2.outputOffset;
        } else {
          _ref3 = node.splice(childIndex, splitNodes), splitNodes = _ref3.splitNodes, inputOffset = _ref3.inputOffset, outputOffset = _ref3.outputOffset, childIndex = _ref3.childIndex;
        }
        newPath.unshift({
          node: node,
          inputOffset: inputOffset,
          outputOffset: outputOffset,
          childIndex: childIndex
        });
      }
      if (splitNodes != null) {
        node = this.patch.rootNode = new Node([node]);
        _ref4 = node.splice(0, splitNodes), inputOffset = _ref4.inputOffset, outputOffset = _ref4.outputOffset, childIndex = _ref4.childIndex;
        newPath.unshift({
          node: node,
          inputOffset: inputOffset,
          outputOffset: outputOffset,
          childIndex: childIndex
        });
      }
      while (((_ref5 = this.patch.rootNode.children) != null ? _ref5.length : void 0) === 1) {
        this.patch.rootNode = this.patch.rootNode.children[0];
        newPath.shift();
      }
      entry = last(newPath);
      if (entry.outputOffset.isEqual(entry.node.outputExtent)) {
        entry.inputOffset = entry.node.inputExtent;
      } else {
        entry.inputOffset = Point.min(entry.node.inputExtent, entry.outputOffset);
      }
      this.path = newPath;
      return this;
    };

    RegionIterator.prototype.toString = function() {
      var childIndex, entries, inputOffset, node, outputOffset;
      entries = (function() {
        var _i, _len, _ref, _ref1, _results;
        _ref = this.path;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          _ref1 = _ref[_i], node = _ref1.node, inputOffset = _ref1.inputOffset, outputOffset = _ref1.outputOffset, childIndex = _ref1.childIndex;
          _results.push("  {inputOffset:" + inputOffset + ", outputOffset:" + outputOffset + ", childIndex:" + childIndex + "}");
        }
        return _results;
      }).call(this);
      return "[RegionIterator\n" + (entries.join("\n")) + "]";
    };

    return RegionIterator;

  })();

  ChangeIterator = (function() {
    function ChangeIterator(patchIterator) {
      this.patchIterator = patchIterator;
      this.inputPosition = Point.ZERO;
      this.outputPosition = Point.ZERO;
    }

    ChangeIterator.prototype.next = function() {
      var content, lastInputPosition, lastOutputPosition, newExtent, next, oldExtent, position;
      while (!(next = this.patchIterator.next()).done) {
        lastInputPosition = this.inputPosition;
        lastOutputPosition = this.outputPosition;
        this.inputPosition = this.patchIterator.getInputPosition();
        this.outputPosition = this.patchIterator.getOutputPosition();
        if ((content = next.value) != null) {
          position = lastOutputPosition;
          oldExtent = this.inputPosition.traversalFrom(lastInputPosition);
          newExtent = this.outputPosition.traversalFrom(lastOutputPosition);
          return {
            done: false,
            value: {
              position: position,
              oldExtent: oldExtent,
              newExtent: newExtent,
              content: content
            }
          };
        }
      }
      return {
        done: true,
        value: null
      };
    };

    return ChangeIterator;

  })();

  module.exports = Patch = (function() {
    function Patch() {
      this.clear();
    }

    Patch.prototype.splice = function(spliceOutputStart, oldOutputExtent, newOutputExtent, content) {
      var iterator;
      iterator = this.regions();
      iterator.seek(spliceOutputStart);
      return iterator.splice(oldOutputExtent, newOutputExtent, content);
    };

    Patch.prototype.clear = function() {
      return this.rootNode = new Leaf(Point.INFINITY, Point.INFINITY, null);
    };

    Patch.prototype.regions = function() {
      return new RegionIterator(this);
    };

    Patch.prototype.changes = function() {
      return new ChangeIterator(this.regions());
    };

    Patch.prototype.toInputPosition = function(outputPosition) {
      return this.regions().seek(outputPosition).getInputPosition();
    };

    Patch.prototype.toOutputPosition = function(inputPosition) {
      return this.regions().seekToInputPosition(inputPosition).getOutputPosition();
    };

    return Patch;

  })();

}).call(this);

}),
  "./helpers": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var SpliceArrayChunkSize,
    __slice = [].slice;

  SpliceArrayChunkSize = 100000;

  module.exports = {
    spliceArray: function(originalArray, start, length, insertedArray) {
      var chunk, chunkEnd, chunkStart, removedValues, _i, _ref;
      if (insertedArray == null) {
        insertedArray = [];
      }
      if (insertedArray.length < SpliceArrayChunkSize) {
        return originalArray.splice.apply(originalArray, [start, length].concat(__slice.call(insertedArray)));
      } else {
        removedValues = originalArray.splice(start, length);
        for (chunkStart = _i = 0, _ref = insertedArray.length; SpliceArrayChunkSize > 0 ? _i <= _ref : _i >= _ref; chunkStart = _i += SpliceArrayChunkSize) {
          chunkEnd = chunkStart + SpliceArrayChunkSize;
          chunk = insertedArray.slice(chunkStart, chunkEnd);
          originalArray.splice.apply(originalArray, [start + chunkStart, 0].concat(__slice.call(chunk)));
        }
        return removedValues;
      }
    },
    newlineRegex: /\r\n|\n|\r/g
  };

}).call(this);

}),
  "./range": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var Grim, Point, Range, newlineRegex,
    __slice = [].slice;

  Grim = require('grim');

  Point = require('./point');

  newlineRegex = require('./helpers').newlineRegex;

  module.exports = Range = (function() {

    /*
    Section: Properties
     */
    Range.prototype.start = null;

    Range.prototype.end = null;


    /*
    Section: Construction
     */

    Range.fromObject = function(object, copy) {
      if (Array.isArray(object)) {
        return new this(object[0], object[1]);
      } else if (object instanceof this) {
        if (copy) {
          return object.copy();
        } else {
          return object;
        }
      } else {
        return new this(object.start, object.end);
      }
    };

    Range.fromText = function() {
      var args, endPoint, lastIndex, lines, startPoint, text;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      if (args.length > 1) {
        startPoint = Point.fromObject(args.shift());
      } else {
        startPoint = new Point(0, 0);
      }
      text = args.shift();
      endPoint = startPoint.copy();
      lines = text.split(newlineRegex);
      if (lines.length > 1) {
        lastIndex = lines.length - 1;
        endPoint.row += lastIndex;
        endPoint.column = lines[lastIndex].length;
      } else {
        endPoint.column += lines[0].length;
      }
      return new this(startPoint, endPoint);
    };

    Range.fromPointWithDelta = function(startPoint, rowDelta, columnDelta) {
      var endPoint;
      startPoint = Point.fromObject(startPoint);
      endPoint = new Point(startPoint.row + rowDelta, startPoint.column + columnDelta);
      return new this(startPoint, endPoint);
    };


    /*
    Section: Serialization and Deserialization
     */

    Range.deserialize = function(array) {
      if (Array.isArray(array)) {
        return new this(array[0], array[1]);
      } else {
        return new this();
      }
    };


    /*
    Section: Construction
     */

    function Range(pointA, pointB) {
      if (pointA == null) {
        pointA = new Point(0, 0);
      }
      if (pointB == null) {
        pointB = new Point(0, 0);
      }
      if (!(this instanceof Range)) {
        return new Range(pointA, pointB);
      }
      pointA = Point.fromObject(pointA);
      pointB = Point.fromObject(pointB);
      if (pointA.isLessThanOrEqual(pointB)) {
        this.start = pointA;
        this.end = pointB;
      } else {
        this.start = pointB;
        this.end = pointA;
      }
    }

    Range.prototype.copy = function() {
      return new this.constructor(this.start.copy(), this.end.copy());
    };

    Range.prototype.negate = function() {
      return new this.constructor(this.start.negate(), this.end.negate());
    };


    /*
    Section: Serialization and Deserialization
     */

    Range.prototype.serialize = function() {
      return [this.start.serialize(), this.end.serialize()];
    };


    /*
    Section: Range Details
     */

    Range.prototype.isEmpty = function() {
      return this.start.isEqual(this.end);
    };

    Range.prototype.isSingleLine = function() {
      return this.start.row === this.end.row;
    };

    Range.prototype.getRowCount = function() {
      return this.end.row - this.start.row + 1;
    };

    Range.prototype.getRows = function() {
      var _i, _ref, _ref1, _results;
      return (function() {
        _results = [];
        for (var _i = _ref = this.start.row, _ref1 = this.end.row; _ref <= _ref1 ? _i <= _ref1 : _i >= _ref1; _ref <= _ref1 ? _i++ : _i--){ _results.push(_i); }
        return _results;
      }).apply(this);
    };


    /*
    Section: Operations
     */

    Range.prototype.freeze = function() {
      this.start.freeze();
      this.end.freeze();
      return Object.freeze(this);
    };

    Range.prototype.union = function(otherRange) {
      var end, start;
      start = this.start.isLessThan(otherRange.start) ? this.start : otherRange.start;
      end = this.end.isGreaterThan(otherRange.end) ? this.end : otherRange.end;
      return new this.constructor(start, end);
    };

    Range.prototype.translate = function(startDelta, endDelta) {
      if (endDelta == null) {
        endDelta = startDelta;
      }
      return new this.constructor(this.start.translate(startDelta), this.end.translate(endDelta));
    };

    Range.prototype.traverse = function(delta) {
      return new this.constructor(this.start.traverse(delta), this.end.traverse(delta));
    };


    /*
    Section: Comparison
     */

    Range.prototype.compare = function(other) {
      var value;
      other = this.constructor.fromObject(other);
      if (value = this.start.compare(other.start)) {
        return value;
      } else {
        return other.end.compare(this.end);
      }
    };

    Range.prototype.isEqual = function(other) {
      if (other == null) {
        return false;
      }
      other = this.constructor.fromObject(other);
      return other.start.isEqual(this.start) && other.end.isEqual(this.end);
    };

    Range.prototype.coversSameRows = function(other) {
      return this.start.row === other.start.row && this.end.row === other.end.row;
    };

    Range.prototype.intersectsWith = function(otherRange, exclusive) {
      if (exclusive) {
        return !(this.end.isLessThanOrEqual(otherRange.start) || this.start.isGreaterThanOrEqual(otherRange.end));
      } else {
        return !(this.end.isLessThan(otherRange.start) || this.start.isGreaterThan(otherRange.end));
      }
    };

    Range.prototype.containsRange = function(otherRange, exclusive) {
      var end, start, _ref;
      _ref = this.constructor.fromObject(otherRange), start = _ref.start, end = _ref.end;
      return this.containsPoint(start, exclusive) && this.containsPoint(end, exclusive);
    };

    Range.prototype.containsPoint = function(point, exclusive) {
      if (Grim.includeDeprecatedAPIs && (exclusive != null) && typeof exclusive === 'object') {
        Grim.deprecate("The second param is no longer an object, it's a boolean argument named `exclusive`.");
        exclusive = exclusive.exclusive;
      }
      point = Point.fromObject(point);
      if (exclusive) {
        return point.isGreaterThan(this.start) && point.isLessThan(this.end);
      } else {
        return point.isGreaterThanOrEqual(this.start) && point.isLessThanOrEqual(this.end);
      }
    };

    Range.prototype.intersectsRow = function(row) {
      return (this.start.row <= row && row <= this.end.row);
    };

    Range.prototype.intersectsRowRange = function(startRow, endRow) {
      var _ref;
      if (startRow > endRow) {
        _ref = [endRow, startRow], startRow = _ref[0], endRow = _ref[1];
      }
      return this.end.row >= startRow && endRow >= this.start.row;
    };

    Range.prototype.getExtent = function() {
      return this.end.traversalFrom(this.start);
    };


    /*
    Section: Conversion
     */

    Range.prototype.toDelta = function() {
      var columns, rows;
      rows = this.end.row - this.start.row;
      if (rows === 0) {
        columns = this.end.column - this.start.column;
      } else {
        columns = this.end.column;
      }
      return new Point(rows, columns);
    };

    Range.prototype.toString = function() {
      return "[" + this.start + " - " + this.end + "]";
    };

    return Range;

  })();

  if (Grim.includeDeprecatedAPIs) {
    Range.prototype.add = function(delta) {
      Grim.deprecate("Use Range::traverse instead");
      return this.traverse(delta);
    };
  }

}).call(this);

}),
  "./point": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var Point, deprecate, includeDeprecatedAPIs, isNumber, _ref;

  _ref = require('grim'), includeDeprecatedAPIs = _ref.includeDeprecatedAPIs, deprecate = _ref.deprecate;

  module.exports = Point = (function() {

    /*
    Section: Properties
     */
    Point.prototype.row = null;

    Point.prototype.column = null;


    /*
    Section: Construction
     */

    Point.fromObject = function(object, copy) {
      var column, row;
      if (object instanceof Point) {
        if (copy) {
          return object.copy();
        } else {
          return object;
        }
      } else {
        if (Array.isArray(object)) {
          row = object[0], column = object[1];
        } else {
          row = object.row, column = object.column;
        }
        return new Point(row, column);
      }
    };


    /*
    Section: Comparison
     */

    Point.min = function(point1, point2) {
      point1 = this.fromObject(point1);
      point2 = this.fromObject(point2);
      if (point1.isLessThanOrEqual(point2)) {
        return point1;
      } else {
        return point2;
      }
    };

    Point.max = function(point1, point2) {
      point1 = Point.fromObject(point1);
      point2 = Point.fromObject(point2);
      if (point1.compare(point2) >= 0) {
        return point1;
      } else {
        return point2;
      }
    };

    Point.assertValid = function(point) {
      if (!(isNumber(point.row) && isNumber(point.column))) {
        throw new TypeError("Invalid Point: " + point);
      }
    };

    Point.ZERO = Object.freeze(new Point(0, 0));

    Point.INFINITY = Object.freeze(new Point(Infinity, Infinity));


    /*
    Section: Construction
     */

    function Point(row, column) {
      if (row == null) {
        row = 0;
      }
      if (column == null) {
        column = 0;
      }
      if (!(this instanceof Point)) {
        return new Point(row, column);
      }
      this.row = row;
      this.column = column;
    }

    Point.prototype.copy = function() {
      return new Point(this.row, this.column);
    };

    Point.prototype.negate = function() {
      return new Point(-this.row, -this.column);
    };


    /*
    Section: Operations
     */

    Point.prototype.freeze = function() {
      return Object.freeze(this);
    };

    Point.prototype.translate = function(other) {
      var column, row, _ref1;
      _ref1 = Point.fromObject(other), row = _ref1.row, column = _ref1.column;
      return new Point(this.row + row, this.column + column);
    };

    Point.prototype.traverse = function(other) {
      var column, row;
      other = Point.fromObject(other);
      row = this.row + other.row;
      if (other.row === 0) {
        column = this.column + other.column;
      } else {
        column = other.column;
      }
      return new Point(row, column);
    };

    Point.prototype.traversalFrom = function(other) {
      other = Point.fromObject(other);
      if (this.row === other.row) {
        if (this.column === Infinity && other.column === Infinity) {
          return new Point(0, 0);
        } else {
          return new Point(0, this.column - other.column);
        }
      } else {
        return new Point(this.row - other.row, this.column);
      }
    };

    Point.prototype.splitAt = function(column) {
      var rightColumn;
      if (this.row === 0) {
        rightColumn = this.column - column;
      } else {
        rightColumn = this.column;
      }
      return [new Point(0, column), new Point(this.row, rightColumn)];
    };


    /*
    Section: Comparison
     */

    Point.prototype.compare = function(other) {
      other = Point.fromObject(other);
      if (this.row > other.row) {
        return 1;
      } else if (this.row < other.row) {
        return -1;
      } else {
        if (this.column > other.column) {
          return 1;
        } else if (this.column < other.column) {
          return -1;
        } else {
          return 0;
        }
      }
    };

    Point.prototype.isEqual = function(other) {
      if (!other) {
        return false;
      }
      other = Point.fromObject(other);
      return this.row === other.row && this.column === other.column;
    };

    Point.prototype.isLessThan = function(other) {
      return this.compare(other) < 0;
    };

    Point.prototype.isLessThanOrEqual = function(other) {
      return this.compare(other) <= 0;
    };

    Point.prototype.isGreaterThan = function(other) {
      return this.compare(other) > 0;
    };

    Point.prototype.isGreaterThanOrEqual = function(other) {
      return this.compare(other) >= 0;
    };

    Point.prototype.isZero = function() {
      return this.row === 0 && this.column === 0;
    };

    Point.prototype.isPositive = function() {
      if (this.row > 0) {
        return true;
      } else if (this.row < 0) {
        return false;
      } else {
        return this.column > 0;
      }
    };

    Point.prototype.isNegative = function() {
      if (this.row < 0) {
        return true;
      } else if (this.row > 0) {
        return false;
      } else {
        return this.column < 0;
      }
    };


    /*
    Section: Conversion
     */

    Point.prototype.toArray = function() {
      return [this.row, this.column];
    };

    Point.prototype.serialize = function() {
      return this.toArray();
    };

    Point.prototype.toString = function() {
      return "(" + this.row + ", " + this.column + ")";
    };

    return Point;

  })();

  if (includeDeprecatedAPIs) {
    Point.prototype.add = function(other) {
      deprecate("Use Point::traverse instead");
      return this.traverse(other);
    };
  }

  isNumber = function(value) {
    return (typeof value === 'number') && (!Number.isNaN(value));
  };

}).call(this);

}),
  "./marker": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var Delegator, Emitter, EmitterMixin, Grim, Marker, OptionKeys, Point, Range, extend, isEqual, omit, pick, size, _ref,
    __slice = [].slice;

  _ref = require('underscore-plus'), extend = _ref.extend, isEqual = _ref.isEqual, omit = _ref.omit, pick = _ref.pick, size = _ref.size;
  //
  Emitter = require('event-kit').Emitter;
  //
  Grim = require('grim');
  //
  Delegator = require('delegato');
  //
  Point = require('./point');
  //
  Range = require('./range');
  //
  OptionKeys = new Set(['reversed', 'tailed', 'invalidate', 'persistent', 'maintainHistory']);

  module.exports = Marker = (function() {
    Delegator.includeInto(Marker);

    Marker.extractParams = function(inputParams) {
      var key, outputParams, _i, _len, _ref1;
      outputParams = {};
      if (inputParams != null) {
        _ref1 = Object.keys(inputParams);
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          key = _ref1[_i];
          if (OptionKeys.has(key)) {
            outputParams[key] = inputParams[key];
          } else {
            if (outputParams.properties == null) {
              outputParams.properties = {};
            }
            outputParams.properties[key] = inputParams[key];
          }
        }
      }
      return outputParams;
    };

    // Marker.delegatesMethods('containsPoint', 'containsRange', 'intersectsRow', {
    //   toMethod: 'getRange'
    // });

    function Marker(id, store, range, params) {
      this.id = id;
      this.store = store;
      this.tailed = params.tailed, this.reversed = params.reversed, this.valid = params.valid, this.invalidate = params.invalidate, this.persistent = params.persistent, this.properties = params.properties, this.maintainHistory = params.maintainHistory;
      this.emitter = new Emitter;
      if (this.tailed == null) {
        this.tailed = true;
      }
      if (this.reversed == null) {
        this.reversed = false;
      }
      if (this.valid == null) {
        this.valid = true;
      }
      if (this.invalidate == null) {
        this.invalidate = 'overlap';
      }
      if (this.persistent == null) {
        this.persistent = true;
      }
      if (this.maintainHistory == null) {
        this.maintainHistory = false;
      }
      if (this.properties == null) {
        this.properties = {};
      }
      this.hasChangeObservers = false;
      this.rangeWhenDestroyed = null;
      Object.freeze(this.properties);
      this.store.setMarkerHasTail(this.id, this.tailed);
    }


    /*
    Section: Event Subscription
     */

    Marker.prototype.onDidDestroy = function(callback) {
      return this.emitter.on('did-destroy', callback);
    };

    Marker.prototype.onDidChange = function(callback) {
      if (!this.hasChangeObservers) {
        this.previousEventState = this.getSnapshot(this.getRange());
        this.hasChangeObservers = true;
      }
      return this.emitter.on('did-change', callback);
    };

    Marker.prototype.getRange = function() {
      var _ref1;
      return (_ref1 = this.rangeWhenDestroyed) != null ? _ref1 : this.store.getMarkerRange(this.id);
    };

    Marker.prototype.setRange = function(range, properties) {
      var params;
      params = this.extractParams(properties);
      params.tailed = true;
      params.range = Range.fromObject(range, true);
      return this.update(this.getRange(), params);
    };

    Marker.prototype.getHeadPosition = function() {
      if (this.reversed) {
        return this.getStartPosition();
      } else {
        return this.getEndPosition();
      }
    };

    Marker.prototype.setHeadPosition = function(position, properties) {
      var oldRange, params;
      position = Point.fromObject(position);
      params = this.extractParams(properties);
      oldRange = this.getRange();
      if (this.hasTail()) {
        if (this.isReversed()) {
          if (position.isLessThan(oldRange.end)) {
            params.range = new Range(position, oldRange.end);
          } else {
            params.reversed = false;
            params.range = new Range(oldRange.end, position);
          }
        } else {
          if (position.isLessThan(oldRange.start)) {
            params.reversed = true;
            params.range = new Range(position, oldRange.start);
          } else {
            params.range = new Range(oldRange.start, position);
          }
        }
      } else {
        params.range = new Range(position, position);
      }
      return this.update(oldRange, params);
    };

    Marker.prototype.getTailPosition = function() {
      if (this.reversed) {
        return this.getEndPosition();
      } else {
        return this.getStartPosition();
      }
    };

    Marker.prototype.setTailPosition = function(position, properties) {
      var oldRange, params;
      position = Point.fromObject(position);
      params = this.extractParams(properties);
      params.tailed = true;
      oldRange = this.getRange();
      if (this.reversed) {
        if (position.isLessThan(oldRange.start)) {
          params.reversed = false;
          params.range = new Range(position, oldRange.start);
        } else {
          params.range = new Range(oldRange.start, position);
        }
      } else {
        if (position.isLessThan(oldRange.end)) {
          params.range = new Range(position, oldRange.end);
        } else {
          params.reversed = true;
          params.range = new Range(oldRange.end, position);
        }
      }
      return this.update(oldRange, params);
    };

    Marker.prototype.getStartPosition = function() {
      var _ref1, _ref2;
      return (_ref1 = (_ref2 = this.rangeWhenDestroyed) != null ? _ref2.start : void 0) != null ? _ref1 : this.store.getMarkerStartPosition(this.id);
    };

    Marker.prototype.getEndPosition = function() {
      var _ref1, _ref2;
      return (_ref1 = (_ref2 = this.rangeWhenDestroyed) != null ? _ref2.end : void 0) != null ? _ref1 : this.store.getMarkerEndPosition(this.id);
    };

    Marker.prototype.clearTail = function(properties) {
      var headPosition, params;
      params = this.extractParams(properties);
      params.tailed = false;
      headPosition = this.getHeadPosition();
      params.range = new Range(headPosition, headPosition);
      return this.update(this.getRange(), params);
    };

    Marker.prototype.plantTail = function(properties) {
      var params;
      params = this.extractParams(properties);
      if (!this.hasTail()) {
        params.tailed = true;
        params.range = new Range(this.getHeadPosition(), this.getHeadPosition());
      }
      return this.update(this.getRange(), params);
    };

    Marker.prototype.isReversed = function() {
      return this.tailed && this.reversed;
    };

    Marker.prototype.hasTail = function() {
      return this.tailed;
    };

    Marker.prototype.isValid = function() {
      return !this.isDestroyed() && this.valid;
    };

    Marker.prototype.isDestroyed = function() {
      return this.rangeWhenDestroyed != null;
    };

    Marker.prototype.isEqual = function(other) {
      return this.invalidate === other.invalidate && this.tailed === other.tailed && this.persistent === other.persistent && this.maintainHistory === other.maintainHistory && this.reversed === other.reversed && isEqual(this.properties, other.properties) && this.getRange().isEqual(other.getRange());
    };

    Marker.prototype.getInvalidationStrategy = function() {
      return this.invalidate;
    };

    Marker.prototype.getProperties = function() {
      return this.properties;
    };

    Marker.prototype.setProperties = function(properties) {
      return this.update(this.getRange(), {
        properties: extend({}, this.properties, properties)
      });
    };

    Marker.prototype.copy = function(options) {
      var snapshot;
      if (options == null) {
        options = {};
      }
      snapshot = this.getSnapshot(null);
      options = Marker.extractParams(options);
      return this.store.createMarker(this.getRange(), extend({}, snapshot, options, {
        properties: extend({}, snapshot.properties, options.properties)
      }));
    };

    Marker.prototype.destroy = function() {
      this.rangeWhenDestroyed = this.getRange();
      this.store.destroyMarker(this.id);
      this.emitter.emit('did-destroy');
    };

    Marker.prototype.extractParams = function(params) {
      params = this.constructor.extractParams(params);
      if (params.properties != null) {
        params.properties = extend({}, this.properties, params.properties);
      }
      return params;
    };

    Marker.prototype.compare = function(other) {
      return this.getRange().compare(other.getRange());
    };

    Marker.prototype.matchesParams = function(params) {
      var key, _i, _len, _ref1;
      _ref1 = Object.keys(params);
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        key = _ref1[_i];
        if (!this.matchesParam(key, params[key])) {
          return false;
        }
      }
      return true;
    };

    Marker.prototype.matchesParam = function(key, value) {
      switch (key) {
        case 'startPosition':
          return this.getStartPosition().isEqual(value);
        case 'endPosition':
          return this.getEndPosition().isEqual(value);
        case 'containsPoint':
        case 'containsPosition':
          return this.containsPoint(value);
        case 'containsRange':
          return this.containsRange(value);
        case 'startRow':
          return this.getStartPosition().row === value;
        case 'endRow':
          return this.getEndPosition().row === value;
        case 'intersectsRow':
          return this.intersectsRow(value);
        case 'invalidate':
        case 'reversed':
        case 'tailed':
        case 'persistent':
        case 'maintainHistory':
          return isEqual(this[key], value);
        default:
          return isEqual(this.properties[key], value);
      }
    };

    Marker.prototype.update = function(oldRange, _arg, textChanged) {
      var properties, propertiesChanged, range, reversed, tailed, updated, valid;
      range = _arg.range, reversed = _arg.reversed, tailed = _arg.tailed, valid = _arg.valid, properties = _arg.properties;
      if (textChanged == null) {
        textChanged = false;
      }
      if (this.isDestroyed()) {
        return;
      }
      updated = propertiesChanged = false;
      if ((range != null) && !range.isEqual(oldRange)) {
        this.store.setMarkerRange(this.id, range);
        updated = true;
      }
      if ((reversed != null) && reversed !== this.reversed) {
        this.reversed = reversed;
        updated = true;
      }
      if ((tailed != null) && tailed !== this.tailed) {
        this.tailed = tailed;
        this.store.setMarkerHasTail(this.id, this.tailed);
        updated = true;
      }
      if ((valid != null) && valid !== this.valid) {
        this.valid = valid;
        updated = true;
      }
      if ((properties != null) && !isEqual(properties, this.properties)) {
        this.properties = Object.freeze(properties);
        propertiesChanged = true;
        updated = true;
      }
      this.emitChangeEvent(range != null ? range : oldRange, textChanged, propertiesChanged);
      if (updated && !textChanged) {
        this.store.markerUpdated();
      }
      return updated;
    };

    Marker.prototype.getSnapshot = function(range) {
      return Object.freeze({
        range: range,
        properties: this.properties,
        reversed: this.reversed,
        tailed: this.tailed,
        valid: this.valid,
        invalidate: this.invalidate,
        maintainHistory: this.maintainHistory
      });
    };

    Marker.prototype.toString = function() {
      return "[Marker " + this.id + ", " + (this.getRange()) + "]";
    };


    /*
    Section: Private
     */

    Marker.prototype.emitChangeEvent = function(currentRange, textChanged, propertiesChanged) {
      var newHeadPosition, newState, newTailPosition, oldHeadPosition, oldState, oldTailPosition;
      if (!this.hasChangeObservers) {
        return;
      }
      oldState = this.previousEventState;
      if (currentRange == null) {
        currentRange = this.getRange();
      }
      if (!(propertiesChanged || oldState.valid !== this.valid || oldState.tailed !== this.tailed || oldState.reversed !== this.reversed || oldState.range.compare(currentRange) !== 0)) {
        return false;
      }
      newState = this.previousEventState = this.getSnapshot(currentRange);
      if (oldState.reversed) {
        oldHeadPosition = oldState.range.start;
        oldTailPosition = oldState.range.end;
      } else {
        oldHeadPosition = oldState.range.end;
        oldTailPosition = oldState.range.start;
      }
      if (newState.reversed) {
        newHeadPosition = newState.range.start;
        newTailPosition = newState.range.end;
      } else {
        newHeadPosition = newState.range.end;
        newTailPosition = newState.range.start;
      }
      this.emitter.emit("did-change", {
        wasValid: oldState.valid,
        isValid: newState.valid,
        hadTail: oldState.tailed,
        hasTail: newState.tailed,
        oldProperties: oldState.properties,
        newProperties: newState.properties,
        oldHeadPosition: oldHeadPosition,
        newHeadPosition: newHeadPosition,
        oldTailPosition: oldTailPosition,
        newTailPosition: newTailPosition,
        textChanged: textChanged
      });
      return true;
    };

    return Marker;

  })();

  // if (Grim.includeDeprecatedAPIs) {
  //   EmitterMixin = require('emissary').Emitter;
  //   EmitterMixin.includeInto(Marker);
  //   Marker.prototype.on = function(eventName) {
  //     switch (eventName) {
  //       case 'changed':
  //         Grim.deprecate("Use Marker::onDidChange instead");
  //         break;
  //       case 'destroyed':
  //         Grim.deprecate("Use Marker::onDidDestroy instead");
  //         break;
  //       default:
  //         Grim.deprecate("Marker::on is deprecated. Use event subscription methods instead.");
  //     }
  //     return EmitterMixin.prototype.on.apply(this, arguments);
  //   };
  //   Marker.prototype.matchesAttributes = function() {
  //     var args;
  //     args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
  //     Grim.deprecate("Use Marker::matchesParams instead.");
  //     return this.matchesParams.apply(this, args);
  //   };
  //   Marker.prototype.getAttributes = function() {
  //     Grim.deprecate("Use Marker::getProperties instead.");
  //     return this.getProperties();
  //   };
  //   Marker.prototype.setAttributes = function() {
  //     var args;
  //     args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
  //     Grim.deprecate("Use Marker::setProperties instead.");
  //     return this.setProperties.apply(this, args);
  //   };
  //   Marker.handleDeprecatedParams = function(params) {
  //     if (params.isReversed != null) {
  //       Grim.deprecate("The option `isReversed` is deprecated, use `reversed` instead");
  //       params.reversed = params.isReversed;
  //       delete params.isReversed;
  //     }
  //     if (params.hasTail != null) {
  //       Grim.deprecate("The option `hasTail` is deprecated, use `tailed` instead");
  //       params.tailed = params.hasTail;
  //       delete params.hasTail;
  //     }
  //     if (params.persist != null) {
  //       Grim.deprecate("The option `persist` is deprecated, use `persistent` instead");
  //       params.persistent = params.persist;
  //       delete params.persist;
  //     }
  //     if (params.invalidation) {
  //       Grim.deprecate("The option `invalidation` is deprecated, use `invalidate` instead");
  //       params.invalidate = params.invalidation;
  //       return delete params.invalidation;
  //     }
  //   };
  // }

}).call(this);

}),
  "mixto": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var ExcludedClassProperties, ExcludedPrototypeProperties, Mixin, name;

  module.exports = Mixin = (function() {
    Mixin.includeInto = function(constructor) {
      var name, value, _ref;
      this.extend(constructor.prototype);
      for (name in this) {
        value = this[name];
        if (ExcludedClassProperties.indexOf(name) === -1) {
          if (!constructor.hasOwnProperty(name)) {
            constructor[name] = value;
          }
        }
      }
      return (_ref = this.included) != null ? _ref.call(constructor) : void 0;
    };

    Mixin.extend = function(object) {
      var name, _i, _len, _ref, _ref1;
      _ref = Object.getOwnPropertyNames(this.prototype);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        name = _ref[_i];
        if (ExcludedPrototypeProperties.indexOf(name) === -1) {
          if (!object.hasOwnProperty(name)) {
            object[name] = this.prototype[name];
          }
        }
      }
      return (_ref1 = this.prototype.extended) != null ? _ref1.call(object) : void 0;
    };

    function Mixin() {
      if (typeof this.extended === "function") {
        this.extended();
      }
    }

    return Mixin;

  })();

  ExcludedClassProperties = ['__super__'];

  for (name in Mixin) {
    ExcludedClassProperties.push(name);
  }

  ExcludedPrototypeProperties = ['constructor', 'extended'];

}).call(this);

}),
  "delegato": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var Delegator, Mixin, _ref,
    __extends = function(child, parent) { for (var key in parent) { if (parent.hasOwnProperty(key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice;

  Mixin = require('mixto');

  module.exports = Delegator = (function(_super) {
    __extends(Delegator, _super);

    function Delegator() {
      _ref = Delegator.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    Delegator.delegatesProperties = function() {
      var propertyName, propertyNames, toMethod, toProperty, _arg, _i, _j, _len, _results,
        _this = this;
      propertyNames = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), _arg = arguments[_i++];
      toProperty = _arg.toProperty, toMethod = _arg.toMethod;
      _results = [];
      for (_j = 0, _len = propertyNames.length; _j < _len; _j++) {
        propertyName = propertyNames[_j];
        _results.push((function(propertyName) {
          return Object.defineProperty(_this.prototype, propertyName, (function() {
            if (toProperty != null) {
              return {
                get: function() {
                  return this[toProperty][propertyName];
                },
                set: function(value) {
                  return this[toProperty][propertyName] = value;
                }
              };
            } else if (toMethod != null) {
              return {
                get: function() {
                  return this[toMethod]()[propertyName];
                },
                set: function(value) {
                  return this[toMethod]()[propertyName] = value;
                }
              };
            } else {
              throw new Error("No delegation target specified");
            }
          })());
        })(propertyName));
      }
      return _results;
    };

    Delegator.delegatesMethods = function() {
      var methodName, methodNames, toMethod, toProperty, _arg, _i, _j, _len, _results,
        _this = this;
      methodNames = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), _arg = arguments[_i++];
      toProperty = _arg.toProperty, toMethod = _arg.toMethod;
      _results = [];
      for (_j = 0, _len = methodNames.length; _j < _len; _j++) {
        methodName = methodNames[_j];
        _results.push((function(methodName) {
          if (toProperty != null) {
            return _this.prototype[methodName] = function() {
              var args, _ref1;
              args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
              return (_ref1 = this[toProperty])[methodName].apply(_ref1, args);
            };
          } else if (toMethod != null) {
            return _this.prototype[methodName] = function() {
              var args, _ref1;
              args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
              return (_ref1 = this[toMethod]())[methodName].apply(_ref1, args);
            };
          } else {
            throw new Error("No delegation target specified");
          }
        })(methodName));
      }
      return _results;
    };

    Delegator.delegatesProperty = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return this.delegatesProperties.apply(this, args);
    };

    Delegator.delegatesMethod = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return this.delegatesMethods.apply(this, args);
    };

    return Delegator;

  })(Mixin);

}).call(this);

}),
  "underscore": (function (exports, require, module, __filename, __dirname, process, global) { //     Underscore.js 1.6.0
//     http://underscorejs.org
//     (c) 2009-2014 Jeremy Ashkenas, DocumentCloud and Investigative Reporters & Editors
//     Underscore may be freely distributed under the MIT license.

(function() {

  // Baseline setup
  // --------------

  // Establish the root object, `window` in the browser, or `exports` on the server.
  var root = this;

  // Save the previous value of the `_` variable.
  var previousUnderscore = root._;

  // Establish the object that gets returned to break out of a loop iteration.
  var breaker = {};

  // Save bytes in the minified (but not gzipped) version:
  var ArrayProto = Array.prototype, ObjProto = Object.prototype, FuncProto = Function.prototype;

  // Create quick reference variables for speed access to core prototypes.
  var
    push             = ArrayProto.push,
    slice            = ArrayProto.slice,
    concat           = ArrayProto.concat;

  // All **ECMAScript 5** native function implementations that we hope to use
  // are declared here.
  var
    nativeForEach      = ArrayProto.forEach,
    nativeMap          = ArrayProto.map,
    nativeReduce       = ArrayProto.reduce,
    nativeReduceRight  = ArrayProto.reduceRight,
    nativeFilter       = ArrayProto.filter,
    nativeEvery        = ArrayProto.every,
    nativeSome         = ArrayProto.some,
    nativeIndexOf      = ArrayProto.indexOf,
    nativeLastIndexOf  = ArrayProto.lastIndexOf,
    nativeIsArray      = Array.isArray,
    nativeKeys         = Object.keys,
    nativeBind         = FuncProto.bind;

  // Create a safe reference to the Underscore object for use below.
  var _ = function(obj) {
    if (obj instanceof _) return obj;
    if (!(this instanceof _)) return new _(obj);
    this._wrapped = obj;
  };

  // Export the Underscore object for **Node.js**, with
  // backwards-compatibility for the old `require()` API. If we're in
  // the browser, add `_` as a global object via a string identifier,
  // for Closure Compiler "advanced" mode.
  if (typeof exports !== 'undefined') {
    if (typeof module !== 'undefined' && module.exports) {
      exports = module.exports = _;
    }
    exports._ = _;
  } else {
    root._ = _;
  }

  // Current version.
  _.VERSION = '1.6.0';

  // Collection Functions
  // --------------------

  // The cornerstone, an `each` implementation, aka `forEach`.
  // Handles objects with the built-in `forEach`, arrays, and raw objects.
  // Delegates to **ECMAScript 5**'s native `forEach` if available.
  var each = _.each = _.forEach = function(obj, iterator, context) {
    if (obj == null) return obj;
    if (nativeForEach && obj.forEach === nativeForEach) {
      obj.forEach(iterator, context);
    } else if (obj.length === +obj.length) {
      for (var i = 0, length = obj.length; i < length; i++) {
        if (iterator.call(context, obj[i], i, obj) === breaker) return;
      }
    } else {
      var keys = _.keys(obj);
      for (var i = 0, length = keys.length; i < length; i++) {
        if (iterator.call(context, obj[keys[i]], keys[i], obj) === breaker) return;
      }
    }
    return obj;
  };

  // Return the results of applying the iterator to each element.
  // Delegates to **ECMAScript 5**'s native `map` if available.
  _.map = _.collect = function(obj, iterator, context) {
    var results = [];
    if (obj == null) return results;
    if (nativeMap && obj.map === nativeMap) return obj.map(iterator, context);
    each(obj, function(value, index, list) {
      results.push(iterator.call(context, value, index, list));
    });
    return results;
  };

  var reduceError = 'Reduce of empty array with no initial value';

  // **Reduce** builds up a single result from a list of values, aka `inject`,
  // or `foldl`. Delegates to **ECMAScript 5**'s native `reduce` if available.
  _.reduce = _.foldl = _.inject = function(obj, iterator, memo, context) {
    var initial = arguments.length > 2;
    if (obj == null) obj = [];
    if (nativeReduce && obj.reduce === nativeReduce) {
      if (context) iterator = _.bind(iterator, context);
      return initial ? obj.reduce(iterator, memo) : obj.reduce(iterator);
    }
    each(obj, function(value, index, list) {
      if (!initial) {
        memo = value;
        initial = true;
      } else {
        memo = iterator.call(context, memo, value, index, list);
      }
    });
    if (!initial) throw new TypeError(reduceError);
    return memo;
  };

  // The right-associative version of reduce, also known as `foldr`.
  // Delegates to **ECMAScript 5**'s native `reduceRight` if available.
  _.reduceRight = _.foldr = function(obj, iterator, memo, context) {
    var initial = arguments.length > 2;
    if (obj == null) obj = [];
    if (nativeReduceRight && obj.reduceRight === nativeReduceRight) {
      if (context) iterator = _.bind(iterator, context);
      return initial ? obj.reduceRight(iterator, memo) : obj.reduceRight(iterator);
    }
    var length = obj.length;
    if (length !== +length) {
      var keys = _.keys(obj);
      length = keys.length;
    }
    each(obj, function(value, index, list) {
      index = keys ? keys[--length] : --length;
      if (!initial) {
        memo = obj[index];
        initial = true;
      } else {
        memo = iterator.call(context, memo, obj[index], index, list);
      }
    });
    if (!initial) throw new TypeError(reduceError);
    return memo;
  };

  // Return the first value which passes a truth test. Aliased as `detect`.
  _.find = _.detect = function(obj, predicate, context) {
    var result;
    any(obj, function(value, index, list) {
      if (predicate.call(context, value, index, list)) {
        result = value;
        return true;
      }
    });
    return result;
  };

  // Return all the elements that pass a truth test.
  // Delegates to **ECMAScript 5**'s native `filter` if available.
  // Aliased as `select`.
  _.filter = _.select = function(obj, predicate, context) {
    var results = [];
    if (obj == null) return results;
    if (nativeFilter && obj.filter === nativeFilter) return obj.filter(predicate, context);
    each(obj, function(value, index, list) {
      if (predicate.call(context, value, index, list)) results.push(value);
    });
    return results;
  };

  // Return all the elements for which a truth test fails.
  _.reject = function(obj, predicate, context) {
    return _.filter(obj, function(value, index, list) {
      return !predicate.call(context, value, index, list);
    }, context);
  };

  // Determine whether all of the elements match a truth test.
  // Delegates to **ECMAScript 5**'s native `every` if available.
  // Aliased as `all`.
  _.every = _.all = function(obj, predicate, context) {
    predicate || (predicate = _.identity);
    var result = true;
    if (obj == null) return result;
    if (nativeEvery && obj.every === nativeEvery) return obj.every(predicate, context);
    each(obj, function(value, index, list) {
      if (!(result = result && predicate.call(context, value, index, list))) return breaker;
    });
    return !!result;
  };

  // Determine if at least one element in the object matches a truth test.
  // Delegates to **ECMAScript 5**'s native `some` if available.
  // Aliased as `any`.
  var any = _.some = _.any = function(obj, predicate, context) {
    predicate || (predicate = _.identity);
    var result = false;
    if (obj == null) return result;
    if (nativeSome && obj.some === nativeSome) return obj.some(predicate, context);
    each(obj, function(value, index, list) {
      if (result || (result = predicate.call(context, value, index, list))) return breaker;
    });
    return !!result;
  };

  // Determine if the array or object contains a given value (using `===`).
  // Aliased as `include`.
  _.contains = _.include = function(obj, target) {
    if (obj == null) return false;
    if (nativeIndexOf && obj.indexOf === nativeIndexOf) return obj.indexOf(target) != -1;
    return any(obj, function(value) {
      return value === target;
    });
  };

  // Invoke a method (with arguments) on every item in a collection.
  _.invoke = function(obj, method) {
    var args = slice.call(arguments, 2);
    var isFunc = _.isFunction(method);
    return _.map(obj, function(value) {
      return (isFunc ? method : value[method]).apply(value, args);
    });
  };

  // Convenience version of a common use case of `map`: fetching a property.
  _.pluck = function(obj, key) {
    return _.map(obj, _.property(key));
  };

  // Convenience version of a common use case of `filter`: selecting only objects
  // containing specific `key:value` pairs.
  _.where = function(obj, attrs) {
    return _.filter(obj, _.matches(attrs));
  };

  // Convenience version of a common use case of `find`: getting the first object
  // containing specific `key:value` pairs.
  _.findWhere = function(obj, attrs) {
    return _.find(obj, _.matches(attrs));
  };

  // Return the maximum element or (element-based computation).
  // Can't optimize arrays of integers longer than 65,535 elements.
  // See [WebKit Bug 80797](https://bugs.webkit.org/show_bug.cgi?id=80797)
  _.max = function(obj, iterator, context) {
    if (!iterator && _.isArray(obj) && obj[0] === +obj[0] && obj.length < 65535) {
      return Math.max.apply(Math, obj);
    }
    var result = -Infinity, lastComputed = -Infinity;
    each(obj, function(value, index, list) {
      var computed = iterator ? iterator.call(context, value, index, list) : value;
      if (computed > lastComputed) {
        result = value;
        lastComputed = computed;
      }
    });
    return result;
  };

  // Return the minimum element (or element-based computation).
  _.min = function(obj, iterator, context) {
    if (!iterator && _.isArray(obj) && obj[0] === +obj[0] && obj.length < 65535) {
      return Math.min.apply(Math, obj);
    }
    var result = Infinity, lastComputed = Infinity;
    each(obj, function(value, index, list) {
      var computed = iterator ? iterator.call(context, value, index, list) : value;
      if (computed < lastComputed) {
        result = value;
        lastComputed = computed;
      }
    });
    return result;
  };

  // Shuffle an array, using the modern version of the
  // [Fisher-Yates shuffle](http://en.wikipedia.org/wiki/Fisher–Yates_shuffle).
  _.shuffle = function(obj) {
    var rand;
    var index = 0;
    var shuffled = [];
    each(obj, function(value) {
      rand = _.random(index++);
      shuffled[index - 1] = shuffled[rand];
      shuffled[rand] = value;
    });
    return shuffled;
  };

  // Sample **n** random values from a collection.
  // If **n** is not specified, returns a single random element.
  // The internal `guard` argument allows it to work with `map`.
  _.sample = function(obj, n, guard) {
    if (n == null || guard) {
      if (obj.length !== +obj.length) obj = _.values(obj);
      return obj[_.random(obj.length - 1)];
    }
    return _.shuffle(obj).slice(0, Math.max(0, n));
  };

  // An internal function to generate lookup iterators.
  var lookupIterator = function(value) {
    if (value == null) return _.identity;
    if (_.isFunction(value)) return value;
    return _.property(value);
  };

  // Sort the object's values by a criterion produced by an iterator.
  _.sortBy = function(obj, iterator, context) {
    iterator = lookupIterator(iterator);
    return _.pluck(_.map(obj, function(value, index, list) {
      return {
        value: value,
        index: index,
        criteria: iterator.call(context, value, index, list)
      };
    }).sort(function(left, right) {
      var a = left.criteria;
      var b = right.criteria;
      if (a !== b) {
        if (a > b || a === void 0) return 1;
        if (a < b || b === void 0) return -1;
      }
      return left.index - right.index;
    }), 'value');
  };

  // An internal function used for aggregate "group by" operations.
  var group = function(behavior) {
    return function(obj, iterator, context) {
      var result = {};
      iterator = lookupIterator(iterator);
      each(obj, function(value, index) {
        var key = iterator.call(context, value, index, obj);
        behavior(result, key, value);
      });
      return result;
    };
  };

  // Groups the object's values by a criterion. Pass either a string attribute
  // to group by, or a function that returns the criterion.
  _.groupBy = group(function(result, key, value) {
    _.has(result, key) ? result[key].push(value) : result[key] = [value];
  });

  // Indexes the object's values by a criterion, similar to `groupBy`, but for
  // when you know that your index values will be unique.
  _.indexBy = group(function(result, key, value) {
    result[key] = value;
  });

  // Counts instances of an object that group by a certain criterion. Pass
  // either a string attribute to count by, or a function that returns the
  // criterion.
  _.countBy = group(function(result, key) {
    _.has(result, key) ? result[key]++ : result[key] = 1;
  });

  // Use a comparator function to figure out the smallest index at which
  // an object should be inserted so as to maintain order. Uses binary search.
  _.sortedIndex = function(array, obj, iterator, context) {
    iterator = lookupIterator(iterator);
    var value = iterator.call(context, obj);
    var low = 0, high = array.length;
    while (low < high) {
      var mid = (low + high) >>> 1;
      iterator.call(context, array[mid]) < value ? low = mid + 1 : high = mid;
    }
    return low;
  };

  // Safely create a real, live array from anything iterable.
  _.toArray = function(obj) {
    if (!obj) return [];
    if (_.isArray(obj)) return slice.call(obj);
    if (obj.length === +obj.length) return _.map(obj, _.identity);
    return _.values(obj);
  };

  // Return the number of elements in an object.
  _.size = function(obj) {
    if (obj == null) return 0;
    return (obj.length === +obj.length) ? obj.length : _.keys(obj).length;
  };

  // Array Functions
  // ---------------

  // Get the first element of an array. Passing **n** will return the first N
  // values in the array. Aliased as `head` and `take`. The **guard** check
  // allows it to work with `_.map`.
  _.first = _.head = _.take = function(array, n, guard) {
    if (array == null) return void 0;
    if ((n == null) || guard) return array[0];
    if (n < 0) return [];
    return slice.call(array, 0, n);
  };

  // Returns everything but the last entry of the array. Especially useful on
  // the arguments object. Passing **n** will return all the values in
  // the array, excluding the last N. The **guard** check allows it to work with
  // `_.map`.
  _.initial = function(array, n, guard) {
    return slice.call(array, 0, array.length - ((n == null) || guard ? 1 : n));
  };

  // Get the last element of an array. Passing **n** will return the last N
  // values in the array. The **guard** check allows it to work with `_.map`.
  _.last = function(array, n, guard) {
    if (array == null) return void 0;
    if ((n == null) || guard) return array[array.length - 1];
    return slice.call(array, Math.max(array.length - n, 0));
  };

  // Returns everything but the first entry of the array. Aliased as `tail` and `drop`.
  // Especially useful on the arguments object. Passing an **n** will return
  // the rest N values in the array. The **guard**
  // check allows it to work with `_.map`.
  _.rest = _.tail = _.drop = function(array, n, guard) {
    return slice.call(array, (n == null) || guard ? 1 : n);
  };

  // Trim out all falsy values from an array.
  _.compact = function(array) {
    return _.filter(array, _.identity);
  };

  // Internal implementation of a recursive `flatten` function.
  var flatten = function(input, shallow, output) {
    if (shallow && _.every(input, _.isArray)) {
      return concat.apply(output, input);
    }
    each(input, function(value) {
      if (_.isArray(value) || _.isArguments(value)) {
        shallow ? push.apply(output, value) : flatten(value, shallow, output);
      } else {
        output.push(value);
      }
    });
    return output;
  };

  // Flatten out an array, either recursively (by default), or just one level.
  _.flatten = function(array, shallow) {
    return flatten(array, shallow, []);
  };

  // Return a version of the array that does not contain the specified value(s).
  _.without = function(array) {
    return _.difference(array, slice.call(arguments, 1));
  };

  // Split an array into two arrays: one whose elements all satisfy the given
  // predicate, and one whose elements all do not satisfy the predicate.
  _.partition = function(array, predicate) {
    var pass = [], fail = [];
    each(array, function(elem) {
      (predicate(elem) ? pass : fail).push(elem);
    });
    return [pass, fail];
  };

  // Produce a duplicate-free version of the array. If the array has already
  // been sorted, you have the option of using a faster algorithm.
  // Aliased as `unique`.
  _.uniq = _.unique = function(array, isSorted, iterator, context) {
    if (_.isFunction(isSorted)) {
      context = iterator;
      iterator = isSorted;
      isSorted = false;
    }
    var initial = iterator ? _.map(array, iterator, context) : array;
    var results = [];
    var seen = [];
    each(initial, function(value, index) {
      if (isSorted ? (!index || seen[seen.length - 1] !== value) : !_.contains(seen, value)) {
        seen.push(value);
        results.push(array[index]);
      }
    });
    return results;
  };

  // Produce an array that contains the union: each distinct element from all of
  // the passed-in arrays.
  _.union = function() {
    return _.uniq(_.flatten(arguments, true));
  };

  // Produce an array that contains every item shared between all the
  // passed-in arrays.
  _.intersection = function(array) {
    var rest = slice.call(arguments, 1);
    return _.filter(_.uniq(array), function(item) {
      return _.every(rest, function(other) {
        return _.contains(other, item);
      });
    });
  };

  // Take the difference between one array and a number of other arrays.
  // Only the elements present in just the first array will remain.
  _.difference = function(array) {
    var rest = concat.apply(ArrayProto, slice.call(arguments, 1));
    return _.filter(array, function(value){ return !_.contains(rest, value); });
  };

  // Zip together multiple lists into a single array -- elements that share
  // an index go together.
  _.zip = function() {
    var length = _.max(_.pluck(arguments, 'length').concat(0));
    var results = new Array(length);
    for (var i = 0; i < length; i++) {
      results[i] = _.pluck(arguments, '' + i);
    }
    return results;
  };

  // Converts lists into objects. Pass either a single array of `[key, value]`
  // pairs, or two parallel arrays of the same length -- one of keys, and one of
  // the corresponding values.
  _.object = function(list, values) {
    if (list == null) return {};
    var result = {};
    for (var i = 0, length = list.length; i < length; i++) {
      if (values) {
        result[list[i]] = values[i];
      } else {
        result[list[i][0]] = list[i][1];
      }
    }
    return result;
  };

  // If the browser doesn't supply us with indexOf (I'm looking at you, **MSIE**),
  // we need this function. Return the position of the first occurrence of an
  // item in an array, or -1 if the item is not included in the array.
  // Delegates to **ECMAScript 5**'s native `indexOf` if available.
  // If the array is large and already in sort order, pass `true`
  // for **isSorted** to use binary search.
  _.indexOf = function(array, item, isSorted) {
    if (array == null) return -1;
    var i = 0, length = array.length;
    if (isSorted) {
      if (typeof isSorted == 'number') {
        i = (isSorted < 0 ? Math.max(0, length + isSorted) : isSorted);
      } else {
        i = _.sortedIndex(array, item);
        return array[i] === item ? i : -1;
      }
    }
    if (nativeIndexOf && array.indexOf === nativeIndexOf) return array.indexOf(item, isSorted);
    for (; i < length; i++) if (array[i] === item) return i;
    return -1;
  };

  // Delegates to **ECMAScript 5**'s native `lastIndexOf` if available.
  _.lastIndexOf = function(array, item, from) {
    if (array == null) return -1;
    var hasIndex = from != null;
    if (nativeLastIndexOf && array.lastIndexOf === nativeLastIndexOf) {
      return hasIndex ? array.lastIndexOf(item, from) : array.lastIndexOf(item);
    }
    var i = (hasIndex ? from : array.length);
    while (i--) if (array[i] === item) return i;
    return -1;
  };

  // Generate an integer Array containing an arithmetic progression. A port of
  // the native Python `range()` function. See
  // [the Python documentation](http://docs.python.org/library/functions.html#range).
  _.range = function(start, stop, step) {
    if (arguments.length <= 1) {
      stop = start || 0;
      start = 0;
    }
    step = arguments[2] || 1;

    var length = Math.max(Math.ceil((stop - start) / step), 0);
    var idx = 0;
    var range = new Array(length);

    while(idx < length) {
      range[idx++] = start;
      start += step;
    }

    return range;
  };

  // Function (ahem) Functions
  // ------------------

  // Reusable constructor function for prototype setting.
  var ctor = function(){};

  // Create a function bound to a given object (assigning `this`, and arguments,
  // optionally). Delegates to **ECMAScript 5**'s native `Function.bind` if
  // available.
  _.bind = function(func, context) {
    var args, bound;
    if (nativeBind && func.bind === nativeBind) return nativeBind.apply(func, slice.call(arguments, 1));
    if (!_.isFunction(func)) throw new TypeError;
    args = slice.call(arguments, 2);
    return bound = function() {
      if (!(this instanceof bound)) return func.apply(context, args.concat(slice.call(arguments)));
      ctor.prototype = func.prototype;
      var self = new ctor;
      ctor.prototype = null;
      var result = func.apply(self, args.concat(slice.call(arguments)));
      if (Object(result) === result) return result;
      return self;
    };
  };

  // Partially apply a function by creating a version that has had some of its
  // arguments pre-filled, without changing its dynamic `this` context. _ acts
  // as a placeholder, allowing any combination of arguments to be pre-filled.
  _.partial = function(func) {
    var boundArgs = slice.call(arguments, 1);
    return function() {
      var position = 0;
      var args = boundArgs.slice();
      for (var i = 0, length = args.length; i < length; i++) {
        if (args[i] === _) args[i] = arguments[position++];
      }
      while (position < arguments.length) args.push(arguments[position++]);
      return func.apply(this, args);
    };
  };

  // Bind a number of an object's methods to that object. Remaining arguments
  // are the method names to be bound. Useful for ensuring that all callbacks
  // defined on an object belong to it.
  _.bindAll = function(obj) {
    var funcs = slice.call(arguments, 1);
    if (funcs.length === 0) throw new Error('bindAll must be passed function names');
    each(funcs, function(f) { obj[f] = _.bind(obj[f], obj); });
    return obj;
  };

  // Memoize an expensive function by storing its results.
  _.memoize = function(func, hasher) {
    var memo = {};
    hasher || (hasher = _.identity);
    return function() {
      var key = hasher.apply(this, arguments);
      return _.has(memo, key) ? memo[key] : (memo[key] = func.apply(this, arguments));
    };
  };

  // Delays a function for the given number of milliseconds, and then calls
  // it with the arguments supplied.
  _.delay = function(func, wait) {
    var args = slice.call(arguments, 2);
    return setTimeout(function(){ return func.apply(null, args); }, wait);
  };

  // Defers a function, scheduling it to run after the current call stack has
  // cleared.
  _.defer = function(func) {
    return _.delay.apply(_, [func, 1].concat(slice.call(arguments, 1)));
  };

  // Returns a function, that, when invoked, will only be triggered at most once
  // during a given window of time. Normally, the throttled function will run
  // as much as it can, without ever going more than once per `wait` duration;
  // but if you'd like to disable the execution on the leading edge, pass
  // `{leading: false}`. To disable execution on the trailing edge, ditto.
  _.throttle = function(func, wait, options) {
    var context, args, result;
    var timeout = null;
    var previous = 0;
    options || (options = {});
    var later = function() {
      previous = options.leading === false ? 0 : _.now();
      timeout = null;
      result = func.apply(context, args);
      context = args = null;
    };
    return function() {
      var now = _.now();
      if (!previous && options.leading === false) previous = now;
      var remaining = wait - (now - previous);
      context = this;
      args = arguments;
      if (remaining <= 0) {
        clearTimeout(timeout);
        timeout = null;
        previous = now;
        result = func.apply(context, args);
        context = args = null;
      } else if (!timeout && options.trailing !== false) {
        timeout = setTimeout(later, remaining);
      }
      return result;
    };
  };

  // Returns a function, that, as long as it continues to be invoked, will not
  // be triggered. The function will be called after it stops being called for
  // N milliseconds. If `immediate` is passed, trigger the function on the
  // leading edge, instead of the trailing.
  _.debounce = function(func, wait, immediate) {
    var timeout, args, context, timestamp, result;

    var later = function() {
      var last = _.now() - timestamp;
      if (last < wait) {
        timeout = setTimeout(later, wait - last);
      } else {
        timeout = null;
        if (!immediate) {
          result = func.apply(context, args);
          context = args = null;
        }
      }
    };

    return function() {
      context = this;
      args = arguments;
      timestamp = _.now();
      var callNow = immediate && !timeout;
      if (!timeout) {
        timeout = setTimeout(later, wait);
      }
      if (callNow) {
        result = func.apply(context, args);
        context = args = null;
      }

      return result;
    };
  };

  // Returns a function that will be executed at most one time, no matter how
  // often you call it. Useful for lazy initialization.
  _.once = function(func) {
    var ran = false, memo;
    return function() {
      if (ran) return memo;
      ran = true;
      memo = func.apply(this, arguments);
      func = null;
      return memo;
    };
  };

  // Returns the first function passed as an argument to the second,
  // allowing you to adjust arguments, run code before and after, and
  // conditionally execute the original function.
  _.wrap = function(func, wrapper) {
    return _.partial(wrapper, func);
  };

  // Returns a function that is the composition of a list of functions, each
  // consuming the return value of the function that follows.
  _.compose = function() {
    var funcs = arguments;
    return function() {
      var args = arguments;
      for (var i = funcs.length - 1; i >= 0; i--) {
        args = [funcs[i].apply(this, args)];
      }
      return args[0];
    };
  };

  // Returns a function that will only be executed after being called N times.
  _.after = function(times, func) {
    return function() {
      if (--times < 1) {
        return func.apply(this, arguments);
      }
    };
  };

  // Object Functions
  // ----------------

  // Retrieve the names of an object's properties.
  // Delegates to **ECMAScript 5**'s native `Object.keys`
  _.keys = function(obj) {
    if (!_.isObject(obj)) return [];
    if (nativeKeys) return nativeKeys(obj);
    var keys = [];
    for (var key in obj) if (_.has(obj, key)) keys.push(key);
    return keys;
  };

  // Retrieve the values of an object's properties.
  _.values = function(obj) {
    var keys = _.keys(obj);
    var length = keys.length;
    var values = new Array(length);
    for (var i = 0; i < length; i++) {
      values[i] = obj[keys[i]];
    }
    return values;
  };

  // Convert an object into a list of `[key, value]` pairs.
  _.pairs = function(obj) {
    var keys = _.keys(obj);
    var length = keys.length;
    var pairs = new Array(length);
    for (var i = 0; i < length; i++) {
      pairs[i] = [keys[i], obj[keys[i]]];
    }
    return pairs;
  };

  // Invert the keys and values of an object. The values must be serializable.
  _.invert = function(obj) {
    var result = {};
    var keys = _.keys(obj);
    for (var i = 0, length = keys.length; i < length; i++) {
      result[obj[keys[i]]] = keys[i];
    }
    return result;
  };

  // Return a sorted list of the function names available on the object.
  // Aliased as `methods`
  _.functions = _.methods = function(obj) {
    var names = [];
    for (var key in obj) {
      if (_.isFunction(obj[key])) names.push(key);
    }
    return names.sort();
  };

  // Extend a given object with all the properties in passed-in object(s).
  _.extend = function(obj) {
    each(slice.call(arguments, 1), function(source) {
      if (source) {
        for (var prop in source) {
          obj[prop] = source[prop];
        }
      }
    });
    return obj;
  };

  // Return a copy of the object only containing the whitelisted properties.
  _.pick = function(obj) {
    var copy = {};
    var keys = concat.apply(ArrayProto, slice.call(arguments, 1));
    each(keys, function(key) {
      if (key in obj) copy[key] = obj[key];
    });
    return copy;
  };

   // Return a copy of the object without the blacklisted properties.
  _.omit = function(obj) {
    var copy = {};
    var keys = concat.apply(ArrayProto, slice.call(arguments, 1));
    for (var key in obj) {
      if (!_.contains(keys, key)) copy[key] = obj[key];
    }
    return copy;
  };

  // Fill in a given object with default properties.
  _.defaults = function(obj) {
    each(slice.call(arguments, 1), function(source) {
      if (source) {
        for (var prop in source) {
          if (obj[prop] === void 0) obj[prop] = source[prop];
        }
      }
    });
    return obj;
  };

  // Create a (shallow-cloned) duplicate of an object.
  _.clone = function(obj) {
    if (!_.isObject(obj)) return obj;
    return _.isArray(obj) ? obj.slice() : _.extend({}, obj);
  };

  // Invokes interceptor with the obj, and then returns obj.
  // The primary purpose of this method is to "tap into" a method chain, in
  // order to perform operations on intermediate results within the chain.
  _.tap = function(obj, interceptor) {
    interceptor(obj);
    return obj;
  };

  // Internal recursive comparison function for `isEqual`.
  var eq = function(a, b, aStack, bStack) {
    // Identical objects are equal. `0 === -0`, but they aren't identical.
    // See the [Harmony `egal` proposal](http://wiki.ecmascript.org/doku.php?id=harmony:egal).
    if (a === b) return a !== 0 || 1 / a == 1 / b;
    // A strict comparison is necessary because `null == undefined`.
    if (a == null || b == null) return a === b;
    // Unwrap any wrapped objects.
    if (a instanceof _) a = a._wrapped;
    if (b instanceof _) b = b._wrapped;
    // Compare `[[Class]]` names.
    var className = Object.prototype.toString.call(a);
    if (className != Object.prototype.toString.call(a)) return false;
    switch (className) {
      // Strings, numbers, dates, and booleans are compared by value.
      case '[object String]':
        // Primitives and their corresponding object wrappers are equivalent; thus, `"5"` is
        // equivalent to `new String("5")`.
        return a == String(b);
      case '[object Number]':
        // `NaN`s are equivalent, but non-reflexive. An `egal` comparison is performed for
        // other numeric values.
        return a != +a ? b != +b : (a == 0 ? 1 / a == 1 / b : a == +b);
      case '[object Date]':
      case '[object Boolean]':
        // Coerce dates and booleans to numeric primitive values. Dates are compared by their
        // millisecond representations. Note that invalid dates with millisecond representations
        // of `NaN` are not equivalent.
        return +a == +b;
      // RegExps are compared by their source patterns and flags.
      case '[object RegExp]':
        return a.source == b.source &&
               a.global == b.global &&
               a.multiline == b.multiline &&
               a.ignoreCase == b.ignoreCase;
    }
    if (typeof a != 'object' || typeof b != 'object') return false;
    // Assume equality for cyclic structures. The algorithm for detecting cyclic
    // structures is adapted from ES 5.1 section 15.12.3, abstract operation `JO`.
    var length = aStack.length;
    while (length--) {
      // Linear search. Performance is inversely proportional to the number of
      // unique nested structures.
      if (aStack[length] == a) return bStack[length] == b;
    }
    // Objects with different constructors are not equivalent, but `Object`s
    // from different frames are.
    var aCtor = a.constructor, bCtor = b.constructor;
    if (aCtor !== bCtor && !(_.isFunction(aCtor) && (aCtor instanceof aCtor) &&
                             _.isFunction(bCtor) && (bCtor instanceof bCtor))
                        && ('constructor' in a && 'constructor' in b)) {
      return false;
    }
    // Add the first object to the stack of traversed objects.
    aStack.push(a);
    bStack.push(b);
    var size = 0, result = true;
    // Recursively compare objects and arrays.
    if (className == '[object Array]') {
      // Compare array lengths to determine if a deep comparison is necessary.
      size = a.length;
      result = size == b.length;
      if (result) {
        // Deep compare the contents, ignoring non-numeric properties.
        while (size--) {
          if (!(result = eq(a[size], b[size], aStack, bStack))) break;
        }
      }
    } else {
      // Deep compare objects.
      for (var key in a) {
        if (_.has(a, key)) {
          // Count the expected number of properties.
          size++;
          // Deep compare each member.
          if (!(result = _.has(b, key) && eq(a[key], b[key], aStack, bStack))) break;
        }
      }
      // Ensure that both objects contain the same number of properties.
      if (result) {
        for (key in b) {
          if (_.has(b, key) && !(size--)) break;
        }
        result = !size;
      }
    }
    // Remove the first object from the stack of traversed objects.
    aStack.pop();
    bStack.pop();
    return result;
  };

  // Perform a deep comparison to check if two objects are equal.
  _.isEqual = function(a, b) {
    return eq(a, b, [], []);
  };

  // Is a given array, string, or object empty?
  // An "empty" object has no enumerable own-properties.
  _.isEmpty = function(obj) {
    if (obj == null) return true;
    if (_.isArray(obj) || _.isString(obj)) return obj.length === 0;
    for (var key in obj) if (_.has(obj, key)) return false;
    return true;
  };

  // Is a given value a DOM element?
  _.isElement = function(obj) {
    return !!(obj && obj.nodeType === 1);
  };

  // Is a given value an array?
  // Delegates to ECMA5's native Array.isArray
  _.isArray = nativeIsArray || function(obj) {
    return Object.prototype.toString.call(obj) == '[object Array]';
  };

  // Is a given variable an object?
  _.isObject = function(obj) {
    return obj === Object(obj);
  };

  // Add some isType methods: isArguments, isFunction, isString, isNumber, isDate, isRegExp.
  each(['Arguments', 'Function', 'String', 'Number', 'Date', 'RegExp'], function(name) {
    _['is' + name] = function(obj) {
      return Object.prototype.toString.call(obj) == '[object ' + name + ']';
    };
  });

  // Define a fallback version of the method in browsers (ahem, IE), where
  // there isn't any inspectable "Arguments" type.
  // if (!_.isArguments(arguments)) {
  //   _.isArguments = function(obj) {
  //     return !!(obj && _.has(obj, 'callee'));
  //   };
  // }

  // Optimize `isFunction` if appropriate.
  if (typeof (/./) !== 'function') {
    _.isFunction = function(obj) {
      return typeof obj === 'function';
    };
  }

  // Is a given object a finite number?
  _.isFinite = function(obj) {
    return isFinite(obj) && !isNaN(parseFloat(obj));
  };

  // Is the given value `NaN`? (NaN is the only number which does not equal itself).
  _.isNaN = function(obj) {
    return _.isNumber(obj) && obj != +obj;
  };

  // Is a given value a boolean?
  _.isBoolean = function(obj) {
    return obj === true || obj === false || Object.prototype.toString.call(obj) == '[object Boolean]';
  };

  // Is a given value equal to null?
  _.isNull = function(obj) {
    return obj === null;
  };

  // Is a given variable undefined?
  _.isUndefined = function(obj) {
    return obj === void 0;
  };

  // Shortcut function for checking if an object has a given property directly
  // on itself (in other words, not on a prototype).
  _.has = function(obj, key) {
    return obj.hasOwnProperty(key);
  };

  // Utility Functions
  // -----------------

  // Run Underscore.js in *noConflict* mode, returning the `_` variable to its
  // previous owner. Returns a reference to the Underscore object.
  _.noConflict = function() {
    root._ = previousUnderscore;
    return this;
  };

  // Keep the identity function around for default iterators.
  _.identity = function(value) {
    return value;
  };

  _.constant = function(value) {
    return function () {
      return value;
    };
  };

  _.property = function(key) {
    return function(obj) {
      return obj[key];
    };
  };

  // Returns a predicate for checking whether an object has a given set of `key:value` pairs.
  _.matches = function(attrs) {
    return function(obj) {
      if (obj === attrs) return true; //avoid comparing an object to itself.
      for (var key in attrs) {
        if (attrs[key] !== obj[key])
          return false;
      }
      return true;
    }
  };

  // Run a function **n** times.
  _.times = function(n, iterator, context) {
    var accum = Array(Math.max(0, n));
    for (var i = 0; i < n; i++) accum[i] = iterator.call(context, i);
    return accum;
  };

  // Return a random integer between min and max (inclusive).
  _.random = function(min, max) {
    if (max == null) {
      max = min;
      min = 0;
    }
    return min + Math.floor(Math.random() * (max - min + 1));
  };

  // A (possibly faster) way to get the current timestamp as an integer.
  _.now = Date.now || function() { return new Date().getTime(); };

  // List of HTML entities for escaping.
  var entityMap = {
    escape: {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#x27;'
    }
  };
  entityMap.unescape = _.invert(entityMap.escape);

  // Regexes containing the keys and values listed immediately above.
  var entityRegexes = {
    escape:   new RegExp('[' + _.keys(entityMap.escape).join('') + ']', 'g'),
    unescape: new RegExp('(' + _.keys(entityMap.unescape).join('|') + ')', 'g')
  };

  // Functions for escaping and unescaping strings to/from HTML interpolation.
  _.each(['escape', 'unescape'], function(method) {
    _[method] = function(string) {
      if (string == null) return '';
      return ('' + string).replace(entityRegexes[method], function(match) {
        return entityMap[method][match];
      });
    };
  });

  // If the value of the named `property` is a function then invoke it with the
  // `object` as context; otherwise, return it.
  _.result = function(object, property) {
    if (object == null) return void 0;
    var value = object[property];
    return _.isFunction(value) ? value.call(object) : value;
  };

  // Add your own custom functions to the Underscore object.
  _.mixin = function(obj) {
    each(_.functions(obj), function(name) {
      var func = _[name] = obj[name];
      _.prototype[name] = function() {
        var args = [this._wrapped];
        push.apply(args, arguments);
        return result.call(this, func.apply(_, args));
      };
    });
  };

  // Generate a unique integer id (unique within the entire client session).
  // Useful for temporary DOM ids.
  var idCounter = 0;
  _.uniqueId = function(prefix) {
    var id = ++idCounter + '';
    return prefix ? prefix + id : id;
  };

  // By default, Underscore uses ERB-style template delimiters, change the
  // following template settings to use alternative delimiters.
  _.templateSettings = {
    evaluate    : /<%([\s\S]+?)%>/g,
    interpolate : /<%=([\s\S]+?)%>/g,
    escape      : /<%-([\s\S]+?)%>/g
  };

  // When customizing `templateSettings`, if you don't want to define an
  // interpolation, evaluation or escaping regex, we need one that is
  // guaranteed not to match.
  var noMatch = /(.)^/;

  // Certain characters need to be escaped so that they can be put into a
  // string literal.
  var escapes = {
    "'":      "'",
    '\\':     '\\',
    '\r':     'r',
    '\n':     'n',
    '\t':     't',
    '\u2028': 'u2028',
    '\u2029': 'u2029'
  };

  var escaper = /\\|'|\r|\n|\t|\u2028|\u2029/g;

  // JavaScript micro-templating, similar to John Resig's implementation.
  // Underscore templating handles arbitrary delimiters, preserves whitespace,
  // and correctly escapes quotes within interpolated code.
  _.template = function(text, data, settings) {
    var render;
    settings = _.defaults({}, settings, _.templateSettings);

    // Combine delimiters into one regular expression via alternation.
    var matcher = new RegExp([
      (settings.escape || noMatch).source,
      (settings.interpolate || noMatch).source,
      (settings.evaluate || noMatch).source
    ].join('|') + '|$', 'g');

    // Compile the template source, escaping string literals appropriately.
    var index = 0;
    var source = "__p+='";
    text.replace(matcher, function(match, escape, interpolate, evaluate, offset) {
      source += text.slice(index, offset)
        .replace(escaper, function(match) { return '\\' + escapes[match]; });

      if (escape) {
        source += "'+\n((__t=(" + escape + "))==null?'':_.escape(__t))+\n'";
      }
      if (interpolate) {
        source += "'+\n((__t=(" + interpolate + "))==null?'':__t)+\n'";
      }
      if (evaluate) {
        source += "';\n" + evaluate + "\n__p+='";
      }
      index = offset + match.length;
      return match;
    });
    source += "';\n";

    // If a variable is not specified, place data values in local scope.
    if (!settings.variable) source = 'with(obj||{}){\n' + source + '}\n';

    source = "var __t,__p='',__j=Array.prototype.join," +
      "print=function(){__p+=__j.call(arguments,'');};\n" +
      source + "return __p;\n";

    try {
      render = new Function(settings.variable || 'obj', '_', source);
    } catch (e) {
      e.source = source;
      throw e;
    }

    if (data) return render(data, _);
    var template = function(data) {
      return render.call(this, data, _);
    };

    // Provide the compiled function source as a convenience for precompilation.
    template.source = 'function(' + (settings.variable || 'obj') + '){\n' + source + '}';

    return template;
  };

  // Add a "chain" function, which will delegate to the wrapper.
  _.chain = function(obj) {
    return _(obj).chain();
  };

  // OOP
  // ---------------
  // If Underscore is called as a function, it returns a wrapped object that
  // can be used OO-style. This wrapper holds altered versions of all the
  // underscore functions. Wrapped objects may be chained.

  // Helper function to continue chaining intermediate results.
  var result = function(obj) {
    return this._chain ? _(obj).chain() : obj;
  };

  // Add all of the Underscore functions to the wrapper object.
  _.mixin(_);

  // Add all mutator Array functions to the wrapper.
  each(['pop', 'push', 'reverse', 'shift', 'sort', 'splice', 'unshift'], function(name) {
    var method = ArrayProto[name];
    _.prototype[name] = function() {
      var obj = this._wrapped;
      method.apply(obj, arguments);
      if ((name == 'shift' || name == 'splice') && obj.length === 0) delete obj[0];
      return result.call(this, obj);
    };
  });

  // Add all accessor Array functions to the wrapper.
  each(['concat', 'join', 'slice'], function(name) {
    var method = ArrayProto[name];
    _.prototype[name] = function() {
      return result.call(this, method.apply(this._wrapped, arguments));
    };
  });

  _.extend(_.prototype, {

    // Start chaining a wrapped Underscore object.
    chain: function() {
      this._chain = true;
      return this;
    },

    // Extracts the result from a wrapped and chained object.
    value: function() {
      return this._wrapped;
    }

  });

  // AMD registration happens at the end for compatibility with AMD loaders
  // that may not enforce next-turn semantics on modules. Even though general
  // practice for AMD registration is to be anonymous, underscore registers
  // as a named module because, like jQuery, it is a base library that is
  // popular enough to be bundled in a third party lib, but not be part of
  // an AMD load request. Those cases could generate an error when an
  // anonymous define() is called outside of a loader request.
  if (typeof define === 'function' && define.amd) {
    define('underscore', [], function() {
      return _;
    });
  }
}).call(this);

}),
  "underscore-plus": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var isEqual, isPlainObject, macModifierKeyMap, nonMacModifierKeyMap, plus, shiftKeyMap, splitKeyPath, _,
    __slice = [].slice;

  _ = require('underscore');

  macModifierKeyMap = {
    cmd: '\u2318',
    ctrl: '\u2303',
    alt: '\u2325',
    option: '\u2325',
    shift: '\u21e7',
    enter: '\u23ce',
    left: '\u2190',
    right: '\u2192',
    up: '\u2191',
    down: '\u2193'
  };

  nonMacModifierKeyMap = {
    cmd: 'Cmd',
    ctrl: 'Ctrl',
    alt: 'Alt',
    option: 'Alt',
    shift: 'Shift',
    enter: 'Enter',
    left: 'Left',
    right: 'Right',
    up: 'Up',
    down: 'Down'
  };

  shiftKeyMap = {
    '~': '`',
    '_': '-',
    '+': '=',
    '|': '\\',
    '{': '[',
    '}': ']',
    ':': ';',
    '"': '\'',
    '<': ',',
    '>': '.',
    '?': '/'
  };

  splitKeyPath = function(keyPath) {
    var char, i, keyPathArray, startIndex, _i, _len;
    startIndex = 0;
    keyPathArray = [];
    if (keyPath == null) {
      return keyPathArray;
    }
    for (i = _i = 0, _len = keyPath.length; _i < _len; i = ++_i) {
      char = keyPath[i];
      if (char === '.' && (i === 0 || keyPath[i - 1] !== '\\')) {
        keyPathArray.push(keyPath.substring(startIndex, i));
        startIndex = i + 1;
      }
    }
    keyPathArray.push(keyPath.substr(startIndex, keyPath.length));
    return keyPathArray;
  };

  isPlainObject = function(value) {
    return _.isObject(value) && !_.isArray(value);
  };

  plus = {
    adviseBefore: function(object, methodName, advice) {
      var original;
      original = object[methodName];
      return object[methodName] = function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        if (advice.apply(this, args) !== false) {
          return original.apply(this, args);
        }
      };
    },
    camelize: function(string) {
      if (string) {
        return string.replace(/[_-]+(\w)/g, function(m) {
          return m[1].toUpperCase();
        });
      } else {
        return '';
      }
    },
    capitalize: function(word) {
      if (!word) {
        return '';
      }
      if (word.toLowerCase() === 'github') {
        return 'GitHub';
      } else {
        return word[0].toUpperCase() + word.slice(1);
      }
    },
    compactObject: function(object) {
      var key, newObject, value;
      newObject = {};
      for (key in object) {
        value = object[key];
        if (value != null) {
          newObject[key] = value;
        }
      }
      return newObject;
    },
    dasherize: function(string) {
      if (!string) {
        return '';
      }
      string = string[0].toLowerCase() + string.slice(1);
      return string.replace(/([A-Z])|(_)/g, function(m, letter) {
        if (letter) {
          return "-" + letter.toLowerCase();
        } else {
          return "-";
        }
      });
    },
    deepClone: function(object) {
      if (_.isArray(object)) {
        return object.map(function(value) {
          return plus.deepClone(value);
        });
      } else if (_.isObject(object) && !_.isFunction(object)) {
        return plus.mapObject(object, (function(_this) {
          return function(key, value) {
            return [key, plus.deepClone(value)];
          };
        })(this));
      } else {
        return object;
      }
    },
    deepExtend: function(target) {
      var i, key, object, result, _i, _len, _ref;
      result = target;
      i = 0;
      while (++i < arguments.length) {
        object = arguments[i];
        if (isPlainObject(result) && isPlainObject(object)) {
          _ref = Object.keys(object);
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            key = _ref[_i];
            result[key] = plus.deepExtend(result[key], object[key]);
          }
        } else {
          result = plus.deepClone(object);
        }
      }
      return result;
    },
    deepContains: function(array, target) {
      var object, _i, _len;
      if (array == null) {
        return false;
      }
      for (_i = 0, _len = array.length; _i < _len; _i++) {
        object = array[_i];
        if (_.isEqual(object, target)) {
          return true;
        }
      }
      return false;
    },
    endsWith: function(string, suffix) {
      if (suffix == null) {
        suffix = '';
      }
      if (string) {
        return string.indexOf(suffix, string.length - suffix.length) !== -1;
      } else {
        return false;
      }
    },
    escapeAttribute: function(string) {
      if (string) {
        return string.replace(/"/g, '&quot;').replace(/\n/g, '').replace(/\\/g, '-');
      } else {
        return '';
      }
    },
    escapeRegExp: function(string) {
      if (string) {
        return string.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
      } else {
        return '';
      }
    },
    humanizeEventName: function(eventName, eventDoc) {
      var event, namespace, namespaceDoc, _ref;
      _ref = eventName.split(':'), namespace = _ref[0], event = _ref[1];
      if (event == null) {
        return plus.undasherize(namespace);
      }
      namespaceDoc = plus.undasherize(namespace);
      if (eventDoc == null) {
        eventDoc = plus.undasherize(event);
      }
      return "" + namespaceDoc + ": " + eventDoc;
    },
    humanizeKey: function(key, platform) {
      var modifierKeyMap;
      if (platform == null) {
        platform = process.platform;
      }
      if (!key) {
        return key;
      }
      modifierKeyMap = platform === 'darwin' ? macModifierKeyMap : nonMacModifierKeyMap;
      if (modifierKeyMap[key]) {
        return modifierKeyMap[key];
      } else if (key.length === 1 && (shiftKeyMap[key] != null)) {
        return [modifierKeyMap.shift, shiftKeyMap[key]];
      } else if (key.length === 1 && key === key.toUpperCase() && key.toUpperCase() !== key.toLowerCase()) {
        return [modifierKeyMap.shift, key.toUpperCase()];
      } else if (key.length === 1 || /f[0-9]{1,2}/.test(key)) {
        return key.toUpperCase();
      } else {
        if (platform === 'darwin') {
          return key;
        } else {
          return plus.capitalize(key);
        }
      }
    },
    humanizeKeystroke: function(keystroke, platform) {
      var humanizedKeystrokes, index, key, keys, keystrokes, splitKeystroke, _i, _j, _len, _len1;
      if (platform == null) {
        platform = process.platform;
      }
      if (!keystroke) {
        return keystroke;
      }
      keystrokes = keystroke.split(' ');
      humanizedKeystrokes = [];
      for (_i = 0, _len = keystrokes.length; _i < _len; _i++) {
        keystroke = keystrokes[_i];
        keys = [];
        splitKeystroke = keystroke.split('-');
        for (index = _j = 0, _len1 = splitKeystroke.length; _j < _len1; index = ++_j) {
          key = splitKeystroke[index];
          if (key === '' && splitKeystroke[index - 1] === '') {
            key = '-';
          }
          if (key) {
            keys.push(plus.humanizeKey(key, platform));
          }
        }
        keys = _.uniq(_.flatten(keys));
        if (platform === 'darwin') {
          keys = keys.join('');
        } else {
          keys = keys.join('+');
        }
        humanizedKeystrokes.push(keys);
      }
      return humanizedKeystrokes.join(' ');
    },
    isSubset: function(potentialSubset, potentialSuperset) {
      return _.every(potentialSubset, function(element) {
        return _.include(potentialSuperset, element);
      });
    },
    losslessInvert: function(hash) {
      var inverted, key, value;
      inverted = {};
      for (key in hash) {
        value = hash[key];
        if (inverted[value] == null) {
          inverted[value] = [];
        }
        inverted[value].push(key);
      }
      return inverted;
    },
    mapObject: function(object, iterator) {
      var key, newObject, value, _i, _len, _ref, _ref1;
      newObject = {};
      _ref = Object.keys(object);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        key = _ref[_i];
        _ref1 = iterator(key, object[key]), key = _ref1[0], value = _ref1[1];
        newObject[key] = value;
      }
      return newObject;
    },
    multiplyString: function(string, n) {
      var finalString, i;
      finalString = "";
      i = 0;
      while (i < n) {
        finalString += string;
        i++;
      }
      return finalString;
    },
    pluralize: function(count, singular, plural) {
      if (count == null) {
        count = 0;
      }
      if (plural == null) {
        plural = singular + 's';
      }
      if (count === 1) {
        return "" + count + " " + singular;
      } else {
        return "" + count + " " + plural;
      }
    },
    remove: function(array, element) {
      var index;
      index = array.indexOf(element);
      if (index >= 0) {
        array.splice(index, 1);
      }
      return array;
    },
    setValueForKeyPath: function(object, keyPath, value) {
      var key, keys;
      keys = splitKeyPath(keyPath);
      while (keys.length > 1) {
        key = keys.shift();
        if (object[key] == null) {
          object[key] = {};
        }
        object = object[key];
      }
      if (value != null) {
        return object[keys.shift()] = value;
      } else {
        return delete object[keys.shift()];
      }
    },
    hasKeyPath: function(object, keyPath) {
      var key, keys, _i, _len;
      keys = splitKeyPath(keyPath);
      for (_i = 0, _len = keys.length; _i < _len; _i++) {
        key = keys[_i];
        if (!object.hasOwnProperty(key)) {
          return false;
        }
        object = object[key];
      }
      return true;
    },
    spliceWithArray: function(originalArray, start, length, insertedArray, chunkSize) {
      var chunkStart, _i, _ref, _results;
      if (chunkSize == null) {
        chunkSize = 100000;
      }
      if (insertedArray.length < chunkSize) {
        return originalArray.splice.apply(originalArray, [start, length].concat(__slice.call(insertedArray)));
      } else {
        originalArray.splice(start, length);
        _results = [];
        for (chunkStart = _i = 0, _ref = insertedArray.length; chunkSize > 0 ? _i <= _ref : _i >= _ref; chunkStart = _i += chunkSize) {
          _results.push(originalArray.splice.apply(originalArray, [start + chunkStart, 0].concat(__slice.call(insertedArray.slice(chunkStart, chunkStart + chunkSize)))));
        }
        return _results;
      }
    },
    sum: function(array) {
      var elt, sum, _i, _len;
      sum = 0;
      for (_i = 0, _len = array.length; _i < _len; _i++) {
        elt = array[_i];
        sum += elt;
      }
      return sum;
    },
    uncamelcase: function(string) {
      var result;
      if (!string) {
        return '';
      }
      result = string.replace(/([A-Z])|_+/g, function(match, letter) {
        if (letter == null) {
          letter = '';
        }
        return " " + letter;
      });
      return plus.capitalize(result.trim());
    },
    undasherize: function(string) {
      if (string) {
        return string.split('-').map(plus.capitalize).join(' ');
      } else {
        return '';
      }
    },
    underscore: function(string) {
      if (!string) {
        return '';
      }
      string = string[0].toLowerCase() + string.slice(1);
      return string.replace(/([A-Z])|-+/g, function(match, letter) {
        if (letter == null) {
          letter = '';
        }
        return "_" + (letter.toLowerCase());
      });
    },
    valueForKeyPath: function(object, keyPath) {
      var key, keys, _i, _len;
      keys = splitKeyPath(keyPath);
      for (_i = 0, _len = keys.length; _i < _len; _i++) {
        key = keys[_i];
        object = object[key];
        if (object == null) {
          return;
        }
      }
      return object;
    },
    isEqual: function(a, b, aStack, bStack) {
      if (_.isArray(aStack) && _.isArray(bStack)) {
        return isEqual(a, b, aStack, bStack);
      } else {
        return isEqual(a, b);
      }
    },
    isEqualForProperties: function() {
      var a, b, properties, property, _i, _len;
      a = arguments[0], b = arguments[1], properties = 3 <= arguments.length ? __slice.call(arguments, 2) : [];
      for (_i = 0, _len = properties.length; _i < _len; _i++) {
        property = properties[_i];
        if (!_.isEqual(a[property], b[property])) {
          return false;
        }
      }
      return true;
    }
  };

  isEqual = function(a, b, aStack, bStack) {
    var aCtor, aCtorValid, aElement, aKeyCount, aValue, bCtor, bCtorValid, bKeyCount, bValue, equal, i, key, stackIndex, _i, _len;
    if (aStack == null) {
      aStack = [];
    }
    if (bStack == null) {
      bStack = [];
    }
    if (a === b) {
      return _.isEqual(a, b);
    }
    if (_.isFunction(a) || _.isFunction(b)) {
      return _.isEqual(a, b);
    }
    stackIndex = aStack.length;
    while (stackIndex--) {
      if (aStack[stackIndex] === a) {
        return bStack[stackIndex] === b;
      }
    }
    aStack.push(a);
    bStack.push(b);
    equal = false;
    if (_.isFunction(a != null ? a.isEqual : void 0)) {
      equal = a.isEqual(b, aStack, bStack);
    } else if (_.isFunction(b != null ? b.isEqual : void 0)) {
      equal = b.isEqual(a, bStack, aStack);
    } else if (_.isArray(a) && _.isArray(b) && a.length === b.length) {
      equal = true;
      for (i = _i = 0, _len = a.length; _i < _len; i = ++_i) {
        aElement = a[i];
        if (!isEqual(aElement, b[i], aStack, bStack)) {
          equal = false;
          break;
        }
      }
    } else if (_.isRegExp(a) && _.isRegExp(b)) {
      equal = _.isEqual(a, b);
    } else if (_.isElement(a) && _.isElement(b)) {
      equal = a === b;
    } else if (_.isObject(a) && _.isObject(b)) {
      aCtor = a.constructor;
      bCtor = b.constructor;
      aCtorValid = _.isFunction(aCtor) && aCtor instanceof aCtor;
      bCtorValid = _.isFunction(bCtor) && bCtor instanceof bCtor;
      if (aCtor !== bCtor && !(aCtorValid && bCtorValid)) {
        equal = false;
      } else {
        aKeyCount = 0;
        equal = true;
        for (key in a) {
          aValue = a[key];
          if (!_.has(a, key)) {
            continue;
          }
          aKeyCount++;
          if (!(_.has(b, key) && isEqual(aValue, b[key], aStack, bStack))) {
            equal = false;
            break;
          }
        }
        if (equal) {
          bKeyCount = 0;
          for (key in b) {
            bValue = b[key];
            if (_.has(b, key)) {
              bKeyCount++;
            }
          }
          equal = aKeyCount === bKeyCount;
        }
      }
    } else {
      equal = _.isEqual(a, b);
    }
    aStack.pop();
    bStack.pop();
    return equal;
  };

  module.exports = _.extend({}, _, plus);

}).call(this);

}),
  "./deprecation": (function (exports, require, module, __filename, __dirname, process, global) {
     (function() {
    var Deprecation, SourceMapCache;

    SourceMapCache = {};

    module.exports = Deprecation = (function() {
      Deprecation.getFunctionNameFromCallsite = function(callsite) {};

      Deprecation.deserialize = function(_arg) {
        var deprecation, fileName, lineNumber, message, stack, stacks, _i, _len;
        message = _arg.message, fileName = _arg.fileName, lineNumber = _arg.lineNumber, stacks = _arg.stacks;
        deprecation = new Deprecation(message, fileName, lineNumber);
        for (_i = 0, _len = stacks.length; _i < _len; _i++) {
          stack = stacks[_i];
          deprecation.addStack(stack, stack.metadata);
        }
        return deprecation;
      };

      function Deprecation(message, fileName, lineNumber) {
        this.message = message;
        this.fileName = fileName;
        this.lineNumber = lineNumber;
        this.callCount = 0;
        this.stackCount = 0;
        this.stacks = {};
        this.stackCallCounts = {};
      }

      Deprecation.prototype.getFunctionNameFromCallsite = function(callsite) {
        var _ref, _ref1, _ref2;
        if (callsite.functionName != null) {
          return callsite.functionName;
        }
        if (callsite.isToplevel()) {
          return (_ref = callsite.getFunctionName()) != null ? _ref : '<unknown>';
        } else {
          if (callsite.isConstructor()) {
            return "new " + (callsite.getFunctionName());
          } else if (callsite.getMethodName() && !callsite.getFunctionName()) {
            return callsite.getMethodName();
          } else {
            return "" + (callsite.getTypeName()) + "." + ((_ref1 = (_ref2 = callsite.getMethodName()) != null ? _ref2 : callsite.getFunctionName()) != null ? _ref1 : '<anonymous>');
          }
        }
      };

      Deprecation.prototype.getLocationFromCallsite = function(callsite) {
        var column, fileName, line;
        if (callsite.location != null) {
          return callsite.location;
        }
        if (callsite.isNative()) {
          return "native";
        } else if (callsite.isEval()) {
          return "eval at " + (this.getLocationFromCallsite(callsite.getEvalOrigin()));
        } else {
          fileName = callsite.getFileName();
          line = callsite.getLineNumber();
          column = callsite.getColumnNumber();
          return "" + fileName + ":" + line + ":" + column;
        }
      };

      Deprecation.prototype.getFileNameFromCallSite = function(callsite) {
        var _ref;
        return (_ref = callsite.fileName) != null ? _ref : callsite.getFileName();
      };

      Deprecation.prototype.getOriginName = function() {
        return this.originName;
      };

      Deprecation.prototype.getMessage = function() {
        return this.message;
      };

      Deprecation.prototype.getStacks = function() {
        var location, parsedStack, parsedStacks, stack, _ref;
        parsedStacks = [];
        _ref = this.stacks;
        for (location in _ref) {
          stack = _ref[location];
          parsedStack = this.parseStack(stack);
          parsedStack.callCount = this.stackCallCounts[location];
          parsedStack.metadata = stack.metadata;
          parsedStacks.push(parsedStack);
        }
        return parsedStacks;
      };

      Deprecation.prototype.getStackCount = function() {
        return this.stackCount;
      };

      Deprecation.prototype.getCallCount = function() {
        return this.callCount;
      };

      Deprecation.prototype.addStack = function(stack, metadata) {
        var callerLocation, _base, _base1;
        if (this.originName == null) {
          this.originName = this.getFunctionNameFromCallsite(stack[0]);
        }
        if (this.fileName == null) {
          this.fileName = this.getFileNameFromCallSite(stack[0]);
        }
        if (this.lineNumber == null) {
          this.lineNumber = typeof (_base = stack[0]).getLineNumber === "function" ? _base.getLineNumber() : void 0;
        }
        this.callCount++;
        stack.metadata = metadata;
        callerLocation = this.getLocationFromCallsite(stack[1]);
        if (this.stacks[callerLocation] == null) {
          this.stacks[callerLocation] = stack;
          this.stackCount++;
        }
        if ((_base1 = this.stackCallCounts)[callerLocation] == null) {
          _base1[callerLocation] = 0;
        }
        return this.stackCallCounts[callerLocation]++;
      };

      Deprecation.prototype.parseStack = function(stack) {
        return stack.map((function(_this) {
          return function(callsite) {
            return {
              functionName: _this.getFunctionNameFromCallsite(callsite),
              location: _this.getLocationFromCallsite(callsite),
              fileName: _this.getFileNameFromCallSite(callsite)
            };
          };
        })(this));
      };

      Deprecation.prototype.serialize = function() {
        return {
          message: this.getMessage(),
          lineNumber: this.lineNumber,
          fileName: this.fileName,
          stacks: this.getStacks()
        };
      };

      return Deprecation;

    })();

  }).call(this);

}),
  "grim": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
    var Deprecation, Emitter, getRawStack, grim;

    Deprecation = require('./deprecation');

    if (global.__grim__ == null) {
      Emitter = require('event-kit').Emitter;
      grim = global.__grim__ = {
        deprecations: {},
        emitter: new Emitter,
        includeDeprecatedAPIs: true,
        getDeprecations: function() {
          var deprecation, deprecations, deprecationsByLineNumber, deprecationsByPackage, fileName, lineNumber, packageName, _ref;
          deprecations = [];
          _ref = grim.deprecations;
          for (fileName in _ref) {
            deprecationsByLineNumber = _ref[fileName];
            for (lineNumber in deprecationsByLineNumber) {
              deprecationsByPackage = deprecationsByLineNumber[lineNumber];
              for (packageName in deprecationsByPackage) {
                deprecation = deprecationsByPackage[packageName];
                deprecations.push(deprecation);
              }
            }
          }
          return deprecations;
        },
        getDeprecationsLength: function() {
          return this.getDeprecations().length;
        },
        clearDeprecations: function() {
          grim.deprecations = {};
        },
        logDeprecations: function() {
          var deprecation, deprecations, _i, _len;
          deprecations = this.getDeprecations();
          deprecations.sort(function(a, b) {
            return b.getCallCount() - a.getCallCount();
          });
          console.warn("\nCalls to deprecated functions\n-----------------------------");
          for (_i = 0, _len = deprecations.length; _i < _len; _i++) {
            deprecation = deprecations[_i];
            console.warn("(" + (deprecation.getCallCount()) + ") " + (deprecation.getOriginName()) + " : " + (deprecation.getMessage()), deprecation);
          }
        },
        deprecate: function(message, metadata) {
          var deprecation, deprecationSite, error, fileName, lineNumber, originalStackTraceLimit, packageName, stack, _base, _base1, _base2, _ref, _ref1;
          originalStackTraceLimit = Error.stackTraceLimit;
          Error.stackTraceLimit = 7;
          error = new Error;
          Error.captureStackTrace(error);
          Error.stackTraceLimit = originalStackTraceLimit;
          stack = (_ref = typeof error.getRawStack === "function" ? error.getRawStack() : void 0) != null ? _ref : getRawStack(error);
          stack = stack.slice(1);
          deprecationSite = stack[0];
          fileName = deprecationSite.getFileName();
          lineNumber = deprecationSite.getLineNumber();
          packageName = (_ref1 = metadata != null ? metadata.packageName : void 0) != null ? _ref1 : "";
          if ((_base = grim.deprecations)[fileName] == null) {
            _base[fileName] = {};
          }
          if ((_base1 = grim.deprecations[fileName])[lineNumber] == null) {
            _base1[lineNumber] = {};
          }
          if ((_base2 = grim.deprecations[fileName][lineNumber])[packageName] == null) {
            _base2[packageName] = new Deprecation(message);
          }
          deprecation = grim.deprecations[fileName][lineNumber][packageName];
          deprecation.addStack(stack, metadata);
          this.emitter.emit("updated", deprecation);
        },
        addSerializedDeprecation: function(serializedDeprecation) {
          var deprecation, fileName, lineNumber, message, packageName, stack, stacks, _base, _base1, _base2, _i, _len, _ref, _ref1, _ref2;
          deprecation = Deprecation.deserialize(serializedDeprecation);
          message = deprecation.getMessage();
          fileName = deprecation.fileName, lineNumber = deprecation.lineNumber;
          stacks = deprecation.getStacks();
          packageName = (_ref = (_ref1 = stacks[0]) != null ? (_ref2 = _ref1.metadata) != null ? _ref2.packageName : void 0 : void 0) != null ? _ref : "";
          if ((_base = grim.deprecations)[fileName] == null) {
            _base[fileName] = {};
          }
          if ((_base1 = grim.deprecations[fileName])[lineNumber] == null) {
            _base1[lineNumber] = {};
          }
          if ((_base2 = grim.deprecations[fileName][lineNumber])[packageName] == null) {
            _base2[packageName] = new Deprecation(message, fileName, lineNumber);
          }
          deprecation = grim.deprecations[fileName][lineNumber][packageName];
          for (_i = 0, _len = stacks.length; _i < _len; _i++) {
            stack = stacks[_i];
            deprecation.addStack(stack, stack.metadata);
          }
          this.emitter.emit("updated", deprecation);
        },
        on: function(eventName, callback) {
          return this.emitter.on(eventName, callback);
        }
      };
    }

    getRawStack = function(error) {
      var originalPrepareStackTrace, result;
      originalPrepareStackTrace = Error.prepareStackTrace;
      Error.prepareStackTrace = function(error, stack) {
        return stack;
      };
      result = error.stack;
      Error.prepareStackTrace = originalPrepareStackTrace;
      return result;
    };

    module.exports = global.__grim__;

  }).call(this);

}),
  "./emitter": function (exports, require, module, __filename, __dirname) {
    (function() {
      var Disposable, Emitter;

      Disposable = require('./disposable');

      module.exports = Emitter = (function() {
        Emitter.prototype.disposed = false;


        /*
        Section: Construction and Destruction
         */

        function Emitter() {
          this.clear();
        }

        Emitter.prototype.clear = function() {
          return this.handlersByEventName = {};
        };

        Emitter.prototype.dispose = function() {
          this.handlersByEventName = null;
          return this.disposed = true;
        };


        /*
        Section: Event Subscription
         */

        Emitter.prototype.on = function(eventName, handler, unshift) {
          var currentHandlers;
          if (unshift == null) {
            unshift = false;
          }
          if (this.disposed) {
            throw new Error("Emitter has been disposed");
          }
          if (typeof handler !== 'function') {
            throw new Error("Handler must be a function");
          }
          if (currentHandlers = this.handlersByEventName[eventName]) {
            if (unshift) {
              this.handlersByEventName[eventName] = [handler].concat(currentHandlers);
            } else {
              this.handlersByEventName[eventName] = currentHandlers.concat(handler);
            }
          } else {
            this.handlersByEventName[eventName] = [handler];
          }
          return new Disposable(this.off.bind(this, eventName, handler));
        };

        Emitter.prototype.preempt = function(eventName, handler) {
          return this.on(eventName, handler, true);
        };

        Emitter.prototype.off = function(eventName, handlerToRemove) {
          var handler, newHandlers, oldHandlers, _i, _len;
          if (this.disposed) {
            return;
          }
          if (oldHandlers = this.handlersByEventName[eventName]) {
            newHandlers = [];
            for (_i = 0, _len = oldHandlers.length; _i < _len; _i++) {
              handler = oldHandlers[_i];
              if (handler !== handlerToRemove) {
                newHandlers.push(handler);
              }
            }
            this.handlersByEventName[eventName] = newHandlers;
          }
        };


        /*
        Section: Event Emission
         */

        Emitter.prototype.emit = function(eventName, value) {
          var handler, handlers, _i, _len, _ref;
          if (handlers = (_ref = this.handlersByEventName) != null ? _ref[eventName] : void 0) {
            for (_i = 0, _len = handlers.length; _i < _len; _i++) {
              handler = handlers[_i];
              handler(value);
            }
          }
        };

        return Emitter;

      })();

    }).call(this);
  },
  "./disposable": function (exports, require, module, __filename, __dirname) {
    (function() {
      var Disposable;

      module.exports = Disposable = (function() {
        Disposable.prototype.disposed = false;

        Disposable.isDisposable = function(object) {
          return typeof (object != null ? object.dispose : void 0) === "function";
        };


        /*
        Section: Construction and Destruction
         */

        function Disposable(disposalAction) {
          this.disposalAction = disposalAction;
        }

        Disposable.prototype.dispose = function() {
          if (!this.disposed) {
            this.disposed = true;
            if (typeof this.disposalAction === "function") {
              this.disposalAction();
            }
            this.disposalAction = null;
          }
        };

        return Disposable;

      })();

    }).call(this);

  },
  "./composite-disposable": function (exports, require, module, __filename, __dirname) {
    (function() {
      var CompositeDisposable;

      module.exports = CompositeDisposable = (function() {
        CompositeDisposable.prototype.disposed = false;


        /*
        Section: Construction and Destruction
         */

        function CompositeDisposable() {
          var disposable, _i, _len;
          this.disposables = new Set;
          for (_i = 0, _len = arguments.length; _i < _len; _i++) {
            disposable = arguments[_i];
            this.add(disposable);
          }
        }

        CompositeDisposable.prototype.dispose = function() {
          if (!this.disposed) {
            this.disposed = true;
            this.disposables.forEach(function(disposable) {
              return disposable.dispose();
            });
            this.disposables = null;
          }
        };


        /*
        Section: Managing Disposables
         */

        CompositeDisposable.prototype.add = function() {
          var disposable, _i, _len;
          if (!this.disposed) {
            for (_i = 0, _len = arguments.length; _i < _len; _i++) {
              disposable = arguments[_i];
              this.disposables.add(disposable);
            }
          }
        };

        CompositeDisposable.prototype.remove = function(disposable) {
          if (!this.disposed) {
            this.disposables["delete"](disposable);
          }
        };

        CompositeDisposable.prototype.clear = function() {
          if (!this.disposed) {
            this.disposables.clear();
          }
        };

        return CompositeDisposable;

      })();

    }).call(this);
  },
  "event-kit": function (exports, require, module, __filename, __dirname) {
    (function() {
      exports.Emitter = require('./emitter');

      exports.Disposable = require('./disposable');

      exports.CompositeDisposable = require('./composite-disposable');
    }).call(this);
  },
  "atom-environment": function (exports, require, module, __filename, __dirname) {
    exports.DeserializerManager = require('./deserializer-manager');
    exports.Grim = require('grim');
    exports.TextBuffer = require('text-buffer');
    exports.StorageFolder = require('./storage-folder');
    exports.ViewRegistry = require('./view-registry');
    // NotificationManager = require('./notification-manager')
  },
  "./deserializer-manager": function (exports, require, module, __filename, __dirname) { (function() {
      var DeserializerManager, Disposable,
        __slice = [].slice;

      Disposable = require('event-kit').Disposable;

      module.exports = DeserializerManager = (function() {
        function DeserializerManager(atomEnvironment) {
          this.atomEnvironment = atomEnvironment;
          this.deserializers = {};
        }

        DeserializerManager.prototype.add = function() {
          var deserializer, deserializers, _i, _len;
          deserializers = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          for (_i = 0, _len = deserializers.length; _i < _len; _i++) {
            deserializer = deserializers[_i];
            this.deserializers[deserializer.name] = deserializer;
          }
          return new Disposable((function(_this) {
            return function() {
              var _j, _len1;
              for (_j = 0, _len1 = deserializers.length; _j < _len1; _j++) {
                deserializer = deserializers[_j];
                delete _this.deserializers[deserializer.name];
              }
            };
          })(this));
        };

        DeserializerManager.prototype.deserialize = function(state) {
          var deserializer, stateVersion, _ref;
          if (state == null) {
            return;
          }
          if (deserializer = this.get(state)) {
            stateVersion = (_ref = typeof state.get === "function" ? state.get('version') : void 0) != null ? _ref : state.version;
            if ((deserializer.version != null) && deserializer.version !== stateVersion) {
              return;
            }
            return deserializer.deserialize(state, this.atomEnvironment);
          } else {
            return console.warn("No deserializer found for", state);
          }
        };

        DeserializerManager.prototype.get = function(state) {
          var name, _ref;
          if (state == null) {
            return;
          }
          name = (_ref = typeof state.get === "function" ? state.get('deserializer') : void 0) != null ? _ref : state.deserializer;
          return this.deserializers[name];
        };

        DeserializerManager.prototype.clear = function() {
          return this.deserializers = {};
        };

        return DeserializerManager;

      })();

    }).call(this);
  }
};

function SnapshotModule(id, parent) {
  this.id = id;
  this.exports = {};
  this.parent = parent;
  if (parent && parent.children) {
    parent.children.push(this);
  }

  this.filename = null;
  this.loaded = false;
  this.children = [];
}

SnapshotModule._resolveFilename = function (request, parent) {
  // this should expand the filename into a full path, so that we can directly
  // fetch it from the cache.
  return request;
}

SnapshotModule._load = function(request, parent) {
  var filename = SnapshotModule._resolveFilename(request, parent);
  var snapshotModule = new SnapshotModule(filename, parent);
  snapshotModule.load(filename);
  return snapshotModule.exports;
};

// Given a file name, pass it to the proper extension handler.
SnapshotModule.prototype.load = function(filename) {
  this.filename = filename;
  this._compile(filename);
  this.loaded = true;
};

// Loads a module at the given file path. Returns that module's
// `exports` property.
SnapshotModule.prototype.require = function(path) {
  return SnapshotModule._load(path, this);
};

SnapshotModule.prototype._compile = function(filename) {
  var self = this;

  function require(path) {
    if (cachedFunctions.hasOwnProperty(path))
      return self.require(path);
    else
      return process.mainModule.require(path);
  }

  require.resolve = function(request) {
    return SnapshotModule._resolveFilename(request, self);
  };
  // var dirname = cachedFunctions[filename].dirname;
  var dirname = "";
  // we need to make sure to not use process/global inside the code we run on the snapshot.
  // here we may probably shim it and re-assign it later, when node has loaded.
  var args = [self.exports, require, self, filename, dirname, null, snapshotGlobal];
  return cachedFunctions[filename].apply(self.exports, args);
};

var snapshot = new SnapshotModule("snapshot", null);
var __AtomEnvironment__ = snapshot.require("atom-environment");
