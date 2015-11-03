'use strict'

const Module = require('module')
const path = require('path')
const cachedVm = require('cached-run-in-this-context')

class NativeCompileCache {
  constructor () {
    this.cacheStore = null
    this.previousModuleCompile = null
  }

  setCacheStore (store) {
    this.cacheStore = store
  }

  install () {
    this.savePreviousModuleCompile()
    this.overrideModuleCompile()
  }

  uninstall () {
    this.restorePreviousModuleCompile()
  }

  savePreviousModuleCompile () {
    this.previousModuleCompile = Module.prototype._compile
  }

  overrideModuleCompile () {
    let cacheStore = this.cacheStore
    let resolvedArgv = null
    // Here we override Node's module.js
    // (https://github.com/atom/node/blob/atom/lib/module.js#L378), changing
    // only the bits that affect compilation in order to use the cached one.
    Module.prototype._compile = function (content, filename) {
      let self = this
      // remove shebang
      content = content.replace(/^\#\!.*/, '')
      function require (path) {
        return self.require(path)
      }
      require.resolve = function (request) {
        return Module._resolveFilename(request, self)
      }
      require.main = process.mainModule

      // Enable support to add extra extension types
      require.extensions = Module._extensions
      require.cache = Module._cache

      let dirname = path.dirname(filename)

      // create wrapper function
      let wrapper = Module.wrap(content)

      let compiledWrapper = null
      if (cacheStore.has(filename)) {
        let buffer = cacheStore.get(filename)
        let compilationResult = cachedVm.runInThisContextCached(wrapper, filename, buffer)
        compiledWrapper = compilationResult.result
        if (compilationResult.wasRejected) {
          cacheStore.delete(filename)
        }
      } else {
        let compilationResult = cachedVm.runInThisContext(wrapper, filename)
        if (compilationResult.cacheBuffer) {
          cacheStore.set(filename, compilationResult.cacheBuffer)
        }
        compiledWrapper = compilationResult.result
      }
      if (global.v8debug) {
        if (!resolvedArgv) {
          // we enter the repl if we're not given a filename argument.
          if (process.argv[1]) {
            resolvedArgv = Module._resolveFilename(process.argv[1], null)
          } else {
            resolvedArgv = 'repl'
          }
        }

        // Set breakpoint on module start
        if (filename === resolvedArgv) {
          // Installing this dummy debug event listener tells V8 to start
          // the debugger.  Without it, the setBreakPoint() fails with an
          // 'illegal access' error.
          global.v8debug.Debug.setListener(function () {})
          global.v8debug.Debug.setBreakPoint(compiledWrapper, 0, 0)
        }
      }
      let args = [self.exports, require, self, filename, dirname, process, global]
      return compiledWrapper.apply(self.exports, args)
    }
  }

  restorePreviousModuleCompile () {
    Module.prototype._compile = this.previousModuleCompile
  }
}

module.exports = new NativeCompileCache()
