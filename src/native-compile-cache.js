const Module = require('module')
const path = require('path')
const cachedVm = require('cached-run-in-this-context')
const crypto = require('crypto')

function computeHash (contents) {
  return crypto.createHash('sha1').update(contents, 'utf8').digest('hex')
}

class NativeCompileCache {
  constructor () {
    this.cacheStore = null
    this.previousModuleCompile = null
  }

  setCacheStore (store) {
    this.cacheStore = store
  }

  setV8Version (v8Version) {
    this.v8Version = v8Version.toString()
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
    let self = this
    // Here we override Node's module.js
    // (https://github.com/atom/node/blob/atom/lib/module.js#L378), changing
    // only the bits that affect compilation in order to use the cached one.
    Module.prototype._compile = function (content, filename) {
      let moduleSelf = this
      // remove shebang
      content = content.replace(/^#!.*/, '')
      function require (path) {
        return moduleSelf.require(path)
      }
      require.resolve = function (request) {
        return Module._resolveFilename(request, moduleSelf)
      }
      require.main = process.mainModule

      // Enable support to add extra extension types
      require.extensions = Module._extensions
      require.cache = Module._cache

      let dirname = path.dirname(filename)

      // create wrapper function
      let wrapper = Module.wrap(content)

      let cacheKey = computeHash(wrapper + self.v8Version)
      let compiledWrapper = null
      if (self.cacheStore.has(cacheKey)) {
        let buffer = self.cacheStore.get(cacheKey)
        let compilationResult = cachedVm.runInThisContextCached(wrapper, filename, buffer)
        compiledWrapper = compilationResult.result
        if (compilationResult.wasRejected) {
          self.cacheStore.delete(cacheKey)
        }
      } else {
        let compilationResult
        try {
          compilationResult = cachedVm.runInThisContext(wrapper, filename)
        } catch (err) {
          console.error(`Error running script ${filename}`)
          throw err
        }
        if (compilationResult.cacheBuffer) {
          self.cacheStore.set(cacheKey, compilationResult.cacheBuffer)
        }
        compiledWrapper = compilationResult.result
      }

      let args = [moduleSelf.exports, require, moduleSelf, filename, dirname, process, global, Buffer]
      return compiledWrapper.apply(moduleSelf.exports, args)
    }
  }

  restorePreviousModuleCompile () {
    Module.prototype._compile = this.previousModuleCompile
  }
}

module.exports = new NativeCompileCache()
