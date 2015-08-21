'use strict'

var path = require('path')
var CSON = require('season')
var fs = require('fs-plus')
var _ = require('underscore-plus')

var COMPILERS = {
  '.js': require('./babel'),
  '.ts': require('./typescript'),
  '.coffee': require('./coffee-script')
}

var cacheDirectory = null

_.each(COMPILERS, function (compiler, extension) {
  Object.defineProperty(require.extensions, extension, {
    enumerable: true,
    writable: false,
    value: function (module, filePath) {
      var code = compileFileAtPath(compiler, filePath, extension)
      return module._compile(code, filePath)
    }
  })
})

exports.setAtomHomeDirectory = function (atomHome) {
  var cacheDir = path.join(atomHome, 'compile-cache')
  if (process.env.USER === 'root' && process.env.SUDO_USER && process.env.SUDO_USER !== process.env.USER) {
    cacheDir = path.join(cacheDirectory, 'root')
  }
  this.setCacheDirectory(cacheDir)
}

exports.setCacheDirectory = function (directory) {
  cacheDirectory = directory
  CSON.setCacheDir(path.join(cacheDirectory, 'cson'));
}

exports.getCacheDirectory = function () {
  return cacheDirectory
}

exports.addPathToCache = function (filePath, atomHome) {
  this.setAtomHomeDirectory(atomHome)
  var extension = path.extname(filePath)

  if (extension === '.cson') {
    CSON.readFileSync(filePath)
  } else {
    var compiler = COMPILERS[extension]
    if (compiler) {
      compileFileAtPath(compiler, filePath, extension)
    }
  }
}

function compileFileAtPath (compiler, filePath, extension) {
  var sourceCode = fs.readFileSync(filePath, 'utf8')
  if (compiler.shouldCompile(sourceCode, filePath)) {
    var cachePath = compiler.getCachePath(sourceCode, filePath)
    var compiledCode = readCachedJavascript(cachePath)
    if (compiledCode == null) {
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

require('source-map-support').install({
  handleUncaughtExceptions: false,

  // Most of this logic is the same as the default implementation in the
  // source-map-support module, but we've overridden it to read the javascript
  // code from our cache directory.
  retrieveSourceMap: function (filePath) {
    if (!fs.isFileSync(filePath)){
      return null
    }

    var sourceCode = fs.readFileSync(filePath, 'utf8')
    var compiler = COMPILERS[path.extname(filePath)]
    var fileData = readCachedJavascript(compiler.getCachePath(sourceCode, filePath))
    if (fileData == null) {
      return null
    }

    var match, lastMatch
    INLINE_SOURCE_MAP_REGEXP.lastIndex = 0
    while ((match = INLINE_SOURCE_MAP_REGEXP.exec(fileData))) {
      lastMatch = match
    }
    if (lastMatch == null){
      return null
    }

    var sourceMappingURL = lastMatch[1]
    var rawData = sourceMappingURL.slice(sourceMappingURL.indexOf(',') + 1)
    var sourceMap = JSON.parse(new Buffer(rawData, 'base64').toString())

    return {
      map: sourceMap,
      url: null
    }
  }
})
