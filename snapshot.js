// We won't have access to es_natives.js here, so this means we have to provide
// them ourselves. The best way we can overcome this is to avoid using such
// functions wherever possible.

// TODO: can we load a v8 context that has all these primitives and compile the
// snapshot using that environment instead?
//Object.prototype.toString = function() {
//  return "[object " + typeof this + "]";
//};

var cachedFunctions = {
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
    // ViewRegistry = require('./view-registry')
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
    return self.require(path);
  }

  require.resolve = function(request) {
    return SnapshotModule._resolveFilename(request, self);
  };
  // var dirname = cachedFunctions[filename].dirname;
  var dirname = "";
  // we need to make sure to not use process/global inside the code we run on the snapshot.
  // here we may probably shim it and re-assign it later, when node has loaded.
  var args = [self.exports, require, self, filename, dirname];
  return cachedFunctions[filename].apply(self.exports, args);
};

var snapshot = new SnapshotModule("snapshot", null);
var __AtomEnvironment__ = snapshot.require("atom-environment");
