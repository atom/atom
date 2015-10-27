var Module = require('module')
var fs = require('fs-plus')
var path = require('path')
var cachedVm = require('cached-run-in-this-context')

NativeCompileCache = (function() {
  function NativeCompileCache() {}

  NativeCompileCache.prototype.setCacheStorage = function(storage) {
    this.cacheStorage = storage;
  };

  NativeCompileCache.prototype.getCacheStorage = function() {
    return this.cacheStorage;
  };

  NativeCompileCache.prototype.install = function() {
    this.savePreviousModuleCompile();
    this.overrideModuleCompile();
  };

  NativeCompileCache.prototype.uninstall = function() {
    this.restorePreviousModuleCompile();
  };

  NativeCompileCache.prototype.savePreviousModuleCompile = function() {
    this.previousModuleCompile = Module.prototype._compile;
  };

  NativeCompileCache.prototype.restorePreviousModuleCompile = function() {
    Module.prototype._compile = this.previousModuleCompile;
  };

  NativeCompileCache.prototype.overrideModuleCompile = function() {
    var cacheStorage = this.cacheStorage;
    Module.prototype._compile = function(content, filename) {
      var self = this;
      // remove shebang
      content = content.replace(/^\#\!.*/, '');
      function require(path) {
        return self.require(path);
      }
      require.resolve = function(request) {
        return Module._resolveFilename(request, self);
      };
      require.main = process.mainModule;

      // Enable support to add extra extension types
      require.extensions = Module._extensions;
      require.cache = Module._cache;

      var dirname = path.dirname(filename);

      // create wrapper function
      var wrapper = Module.wrap(content);

      var compiledWrapper = null;
      if (cacheStorage.has(filename)) {
        var buffer = cacheStorage.get(filename);
        compiledWrapper =
          cachedVm.runInThisContextCached(wrapper, filename, buffer).result;
      } else {
        var compilationResult = cachedVm.runInThisContext(wrapper, filename);
        if (compilationResult.cacheBuffer) {
          cacheStorage.set(filename, compilationResult.cacheBuffer);
        }
        compiledWrapper = compilationResult.result;
      }
      if (global.v8debug) {
        if (!resolvedArgv) {
          // we enter the repl if we're not given a filename argument.
          if (process.argv[1]) {
            resolvedArgv = Module._resolveFilename(process.argv[1], null);
          } else {
            resolvedArgv = 'repl';
          }
        }

        // Set breakpoint on module start
        if (filename === resolvedArgv) {
          // Installing this dummy debug event listener tells V8 to start
          // the debugger.  Without it, the setBreakPoint() fails with an
          // 'illegal access' error.
          global.v8debug.Debug.setListener(function() {});
          global.v8debug.Debug.setBreakPoint(compiledWrapper, 0, 0);
        }
      }
      var args = [self.exports, require, self, filename, dirname, process, global];
      return compiledWrapper.apply(self.exports, args);
    };
  };

  return NativeCompileCache;

})();

module.exports = new NativeCompileCache;
