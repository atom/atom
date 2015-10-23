// We won't have access to es_natives.js here, so this means we have to provide
// them ourselves. The best way we can overcome this is to avoid using such
// functions wherever possible.
//Object.prototype.toString = function() {
//  return "[object " + typeof this + "]";
//};

var snapshotGlobal = {};
var cachedFunctions = {
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
  var args = [self.exports, require, self, filename, dirname, null, snapshotGlobal];
  return cachedFunctions[filename].apply(self.exports, args);
};

var snapshot = new SnapshotModule("snapshot", null);
var __AtomEnvironment__ = snapshot.require("atom-environment");
