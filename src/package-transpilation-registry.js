var crypto = require('crypto')
var fs = require('fs')
var path = require('path')

var Resolve = null

function PackageTranspilationRegistry () {
  this.configByPackagePath = {}
  this.configByFilePath = {}
  this.transpilerPaths = {}
  this.transpilerHashes = {}
}

PackageTranspilationRegistry.prototype.addTranspilerConfigForPath = function (packagePath, config) {
  packagePath = fs.realpathSync(packagePath)
  this.configByPackagePath[packagePath] = Object.assign({}, config, {
    path: packagePath
  })
}

PackageTranspilationRegistry.prototype.removeTranspilerConfigForPath = function (packagePath) {
  packagePath = fs.realpathSync(packagePath)
  delete this.configByPackagePath[path]
}

// Wraps the transpiler in an object with the same interface
// that falls back to the original transpiler implementation if and
// only if a package hasn't registered its desire to transpile its own source.
PackageTranspilationRegistry.prototype.wrapTranspiler = function (transpiler) {
  var self = this
  return {
    getCachePath: function (sourceCode, filePath) {
      var config = self.getPackageTranspilerConfigForFilePath(filePath)
      if (config) {
        return self.getCachePath(sourceCode, filePath, config)
      }

      return transpiler.getCachePath(sourceCode, filePath)
    },

    compile: function (sourceCode, filePath) {
      var config = self.getPackageTranspilerConfigForFilePath(filePath)
      if (config) {
        return self.transpileWithPackageTranspiler(sourceCode, filePath, config)
      }

      return transpiler.compile(sourceCode, filePath)
    },

    shouldCompile: function (sourceCode, filePath) {
      if (self.transpilerPaths[filePath]) {
        return false
      }
      var config = self.getPackageTranspilerConfigForFilePath(filePath)
      if (config) {
        return true
      }

      return transpiler.shouldCompile(sourceCode, filePath)
    }
  }
}

PackageTranspilationRegistry.prototype.getPackageTranspilerConfigForFilePath = function (filePath) {
  if (this.configByFilePath[filePath] !== undefined) return this.configByFilePath[filePath]

  var config = null
  var thisPath = filePath
  var lastPath = null
  // Iterate parents from the file path to the root, checking at each level
  // to see if a package manages transpilation for that directory.
  // This means searching for a config for `/path/to/file/here.js` only
  // only iterates four times, even if there are hundreds of configs registered.
  while (thisPath !== lastPath) { // until we reach the root
    if (config = this.configByPackagePath[thisPath]) {
      this.configByFilePath[filePath] = config
      return config
    }

    lastPath = thisPath
    thisPath = path.resolve(thisPath, '..')
  }

  this.configByFilePath[filePath] = null
  return null
}

PackageTranspilationRegistry.prototype.getCachePath = function (sourceCode, filePath, config) {
  var transpilerPath = path.join(config.path, config.transpiler)
  var transpilerSource = config._transpilerSource || fs.readFileSync(transpilerPath, 'utf8')
  config._transpilerSource = transpilerSource
  return path.join(
    "package-transpile",
    crypto
      .createHash('sha1')
      .update(transpilerSource, 'utf8')
      .update(sourceCode, 'utf8')
      .digest('hex')
  )
}

PackageTranspilationRegistry.prototype.transpileWithPackageTranspiler = function (sourceCode, filePath) {
  var config = this.configByFilePath[filePath]

  Resolve = Resolve || require('resolve')
  var transpilerPath = Resolve.sync(config.transpiler, {basedir: config.path, extensions: Object.keys(require.extensions)})
  if (transpilerPath) {
    this.transpilerPaths[transpilerPath] = true
    var transpiler = require(transpilerPath)
    var result = transpiler.compile(sourceCode, filePath, config.options || {})
    if (result === undefined) {
      return sourceCode
    } else {
      return result
    }
  } else {
    var err = new Error("Could not find transpiler '" + config.transpiler + "' from '" + config.path + "'")
    console.error(err)
  }
}

module.exports = PackageTranspilationRegistry
