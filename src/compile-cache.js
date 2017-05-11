'use strict'

// For now, we're not using babel or ES6 features like `let` and `const` in
// this file, because `apm` requires this file directly in order to pre-warm
// Atom's compile-cache when installing or updating packages, using an older
// version of node.js

var path = require('path')
var fs = require('fs-plus')
var sourceMapSupport = require('@atom/source-map-support')

var PackageTranspilationRegistry = require('./package-transpilation-registry')
var CSON = null

var packageTranspilationRegistry = new PackageTranspilationRegistry()

var COMPILERS = {
  '.js': packageTranspilationRegistry.wrapTranspiler(require('./babel')),
  '.ts': packageTranspilationRegistry.wrapTranspiler(require('./typescript')),
  '.coffee': packageTranspilationRegistry.wrapTranspiler(require('./coffee-script'))
}

exports.addTranspilerConfigForPath = function (packagePath, packageName, packageMeta, config) {
  packagePath = fs.realpathSync(packagePath)
  packageTranspilationRegistry.addTranspilerConfigForPath(packagePath, packageName, packageMeta, config)
}

exports.removeTranspilerConfigForPath = function (packagePath) {
  packagePath = fs.realpathSync(packagePath)
  packageTranspilationRegistry.removeTranspilerConfigForPath(packagePath)
}

var cacheStats = {}
var cacheDirectory = null

exports.setAtomHomeDirectory = function (atomHome) {
  var cacheDir = path.join(atomHome, 'compile-cache')
  if (process.env.USER === 'root' && process.env.SUDO_USER && process.env.SUDO_USER !== process.env.USER) {
    cacheDir = path.join(cacheDir, 'root')
  }
  this.setCacheDirectory(cacheDir)
}

exports.setCacheDirectory = function (directory) {
  cacheDirectory = directory
}

exports.getCacheDirectory = function () {
  return cacheDirectory
}

exports.addPathToCache = function (filePath, atomHome) {
  this.setAtomHomeDirectory(atomHome)
  var extension = path.extname(filePath)

  if (extension === '.cson') {
    if (!CSON) {
      CSON = require('season')
      CSON.setCacheDir(this.getCacheDirectory())
    }
    return CSON.readFileSync(filePath)
  } else {
    var compiler = COMPILERS[extension]
    if (compiler) {
      return compileFileAtPath(compiler, filePath, extension)
    }
  }
}

exports.getCacheStats = function () {
  return cacheStats
}

exports.resetCacheStats = function () {
  Object.keys(COMPILERS).forEach(function (extension) {
    cacheStats[extension] = {
      hits: 0,
      misses: 0
    }
  })
}

function compileFileAtPath (compiler, filePath, extension) {
  var sourceCode = fs.readFileSync(filePath, 'utf8')
  if (compiler.shouldCompile(sourceCode, filePath)) {
    var cachePath = compiler.getCachePath(sourceCode, filePath)
    var compiledCode = readCachedJavascript(cachePath)
    if (compiledCode != null) {
      cacheStats[extension].hits++
    } else {
      cacheStats[extension].misses++
      compiledCode = compiler.compile(sourceCode, filePath)
      writeCachedJavascript(cachePath, compiledCode)
    }
    return compiledCode
  }
  return sourceCode
}

function readCachedJavascript (relativeCachePath) {
  var cachePath = path.join(cacheDirectory, relativeCachePath)
  if (fs.isFileSync(cachePath)) {
    try {
      return fs.readFileSync(cachePath, 'utf8')
    } catch (error) {}
  }
  return null
}

function writeCachedJavascript (relativeCachePath, code) {
  var cachePath = path.join(cacheDirectory, relativeCachePath)
  fs.writeFileSync(cachePath, code, 'utf8')
}

var INLINE_SOURCE_MAP_REGEXP = /\/\/[#@]\s*sourceMappingURL=([^'"\n]+)\s*$/mg

let snapshotSourceMapConsumer
if (global.isGeneratingSnapshot) {
  // Warm up the source map consumer to efficiently translate positions when
  // generating stack traces containing a file that was snapshotted.
  const {SourceMapConsumer} = require('source-map')
  snapshotSourceMapConsumer = new SourceMapConsumer(snapshotAuxiliaryData.sourceMap) // eslint-disable-line no-undef
  snapshotSourceMapConsumer.originalPositionFor({line: 42, column: 0})
}

exports.install = function (resourcesPath, nodeRequire) {
  sourceMapSupport.install({
    handleUncaughtExceptions: false,

    // Most of this logic is the same as the default implementation in the
    // source-map-support module, but we've overridden it to read the javascript
    // code from our cache directory.
    retrieveSourceMap: function (filePath) {
      if (filePath === '<embedded>') {
        return {
          map: snapshotSourceMapConsumer,
          url: path.join(resourcesPath, 'app', 'static', 'index.js')
        }
      }

      if (!cacheDirectory || !fs.isFileSync(filePath)) {
        return null
      }

      try {
        var sourceCode = fs.readFileSync(filePath, 'utf8')
      } catch (error) {
        console.warn('Error reading source file', error.stack)
        return null
      }

      var compiler = COMPILERS[path.extname(filePath)]
      if (!compiler) compiler = COMPILERS['.js']

      try {
        var fileData = readCachedJavascript(compiler.getCachePath(sourceCode, filePath))
      } catch (error) {
        console.warn('Error reading compiled file', error.stack)
        return null
      }

      if (fileData == null) {
        return null
      }

      var match, lastMatch
      INLINE_SOURCE_MAP_REGEXP.lastIndex = 0
      while ((match = INLINE_SOURCE_MAP_REGEXP.exec(fileData))) {
        lastMatch = match
      }
      if (lastMatch == null) {
        return null
      }

      var sourceMappingURL = lastMatch[1]
      var rawData = sourceMappingURL.slice(sourceMappingURL.indexOf(',') + 1)

      try {
        var sourceMap = JSON.parse(new Buffer(rawData, 'base64'))
      } catch (error) {
        console.warn('Error parsing source map', error.stack)
        return null
      }

      return {
        map: sourceMap,
        url: null
      }
    }
  })

  var prepareStackTraceWithSourceMapping = Error.prepareStackTrace
  var prepareStackTrace = prepareStackTraceWithSourceMapping

  function prepareStackTraceWithRawStackAssignment (error, frames) {
    if (error.rawStack) { // avoid infinite recursion
      return prepareStackTraceWithSourceMapping(error, frames)
    } else {
      error.rawStack = frames
      return prepareStackTrace(error, frames)
    }
  }

  Error.stackTraceLimit = 30

  Object.defineProperty(Error, 'prepareStackTrace', {
    get: function () {
      return prepareStackTraceWithRawStackAssignment
    },

    set: function (newValue) {
      prepareStackTrace = newValue
      process.nextTick(function () {
        prepareStackTrace = prepareStackTraceWithSourceMapping
      })
    }
  })

  Error.prototype.getRawStack = function () { // eslint-disable-line no-extend-native
    // Access this.stack to ensure prepareStackTrace has been run on this error
    // because it assigns this.rawStack as a side-effect
    this.stack
    return this.rawStack
  }

  Object.keys(COMPILERS).forEach(function (extension) {
    var compiler = COMPILERS[extension]

    Object.defineProperty(nodeRequire.extensions, extension, {
      enumerable: true,
      writable: false,
      value: function (module, filePath) {
        var code = compileFileAtPath(compiler, filePath, extension)
        return module._compile(code, filePath)
      }
    })
  })
}

exports.supportedExtensions = Object.keys(COMPILERS)
exports.resetCacheStats()
