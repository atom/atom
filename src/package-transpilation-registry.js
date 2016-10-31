var crypto = require('crypto')
var fs = require('fs')
var path = require('path')

var minimatch = require('minimatch')

var Resolve = null

function PackageTranspilationRegistry () {
  this.configByPackagePath = {}
  this.specByFilePath = {}
  this.transpilerPaths = {}
}

Object.assign(PackageTranspilationRegistry.prototype, {
  addTranspilerConfigForPath: function (packagePath, config) {
    this.configByPackagePath[packagePath] = {
      specs: config,
      path: packagePath
    }
  },

  removeTranspilerConfigForPath: function (packagePath) {
    delete this.configByPackagePath[packagePath]
  },

  // Wraps the transpiler in an object with the same interface
  // that falls back to the original transpiler implementation if and
  // only if a package hasn't registered its desire to transpile its own source.
  wrapTranspiler: function (transpiler) {
    var self = this
    return {
      getCachePath: function (sourceCode, filePath) {
        var spec = self.getPackageTranspilerSpecForFilePath(filePath)
        if (spec) {
          return self.getCachePath(sourceCode, filePath, spec)
        }

        return transpiler.getCachePath(sourceCode, filePath)
      },

      compile: function (sourceCode, filePath) {
        var spec = self.getPackageTranspilerSpecForFilePath(filePath)
        if (spec) {
          return self.transpileWithPackageTranspiler(sourceCode, filePath, spec)
        }

        return transpiler.compile(sourceCode, filePath)
      },

      shouldCompile: function (sourceCode, filePath) {
        if (self.transpilerPaths[filePath]) {
          return false
        }
        var spec = self.getPackageTranspilerSpecForFilePath(filePath)
        if (spec) {
          return true
        }

        return transpiler.shouldCompile(sourceCode, filePath)
      }
    }
  },

  getPackageTranspilerSpecForFilePath: function (filePath) {
    if (this.specByFilePath[filePath] !== undefined) return this.specByFilePath[filePath]

    // ignore node_modules
    if (filePath.indexOf(path.sep + 'node_modules' + path.sep) > -1) {
      return false
    }

    var config = null
    var spec = null
    var thisPath = filePath
    var lastPath = null
    // Iterate parents from the file path to the root, checking at each level
    // to see if a package manages transpilation for that directory.
    // This means searching for a config for `/path/to/file/here.js` only
    // only iterates four times, even if there are hundreds of configs registered.
    while (thisPath !== lastPath) { // until we reach the root
      if (config = this.configByPackagePath[thisPath]) { // eslint-disable-line no-cond-assign
        for (var i = 0; i < config.specs.length; i++) {
          spec = config.specs[i]
          if (minimatch(filePath, path.join(config.path, spec.glob))) {
            spec._config = config
            this.specByFilePath[filePath] = spec
            return spec
          }
        }
      }

      lastPath = thisPath
      thisPath = path.resolve(thisPath, '..')
    }

    this.specByFilePath[filePath] = null
    return null
  },

  getCachePath: function (sourceCode, filePath, spec) {
    var transpilerPath = this.getTranspilerPath(spec)
    var transpilerSource = spec._transpilerSource || fs.readFileSync(transpilerPath, 'utf8')
    spec._transpilerSource = transpilerSource
    var transpiler = this.getTranspiler(spec)

    var hash = crypto
      .createHash('sha1')
      .update(JSON.stringify(spec.options || {}))
      .update(transpilerSource, 'utf8')
      .update(sourceCode, 'utf8')

    var additionalCacheData
    if (transpiler && transpiler.getCacheKeyData) {
      additionalCacheData = transpiler.getCacheKeyData(sourceCode, filePath, spec.options)
      hash.update(additionalCacheData, 'utf8')
    }

    return path.join('package-transpile', hash.digest('hex'))
  },

  transpileWithPackageTranspiler: function (sourceCode, filePath, spec) {
    var transpiler = this.getTranspiler(spec)

    if (transpiler) {
      var result = transpiler.transpile(sourceCode, filePath, spec.options || {})
      if (result === undefined || (result && result.code === undefined)) {
        return sourceCode
      } else if (result.code) {
        return result.code.toString()
      } else {
        throw new Error("Could not find a property `.code` on the transpilation results of " + filePath)
      }
    } else {
      var err = new Error("Could not resolve transpiler '" + spec.transpiler + "' from '" + spec._config.path + "'")
      throw err
    }
  },

  getTranspilerPath: function (spec) {
    Resolve = Resolve || require('resolve')
    return Resolve.sync(spec.transpiler, {
      basedir: spec._config.path,
      extensions: Object.keys(require.extensions)
    })
  },

  getTranspiler: function (spec) {
    var transpilerPath = this.getTranspilerPath(spec)
    if (transpilerPath) {
      var transpiler = require(transpilerPath)
      this.transpilerPaths[transpilerPath] = true
      return transpiler
    }
  }
})

module.exports = PackageTranspilationRegistry
