'use strict'

const path = require('path')
const CSON = require('season')
const fs = require('fs-plus')

const COMPILERS = {
  '.js': require('./babel'),
  '.ts': require('./typescript'),
  '.coffee': require('./coffee-script')
}

for (let extension in COMPILERS) {
  let compiler = COMPILERS[extension]
  Object.defineProperty(require.extensions, extension, {
    enumerable: true,
    writable: false,
    value: function (module, filePath) {
      let code = compileFileAtPath(compiler, filePath)
      return module._compile(code, filePath)
    }
  })
}

let cacheDirectory = null

exports.setAtomHomeDirectory = function (atomHome) {
  let cacheDir = path.join(atomHome, 'compile-cache')
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
  extension = path.extname(filePath)
  if (extension === '.cson') {
    return CSON.readFileSync(filePath)
  }

  if (compiler = COMPILERS[extension]) {
    return compileFileAtPath(compiler, filePath)
  }
}

function compileFileAtPath (compiler, filePath) {
  let sourceCode = fs.readFileSync(filePath, 'utf8')
  if (compiler.shouldCompile(sourceCode, filePath)) {
    let cachePath = compiler.getCachePath(sourceCode, filePath)
    let compiledCode = readCachedJavascript(cachePath)
    if (compiledCode == null) {
      compiledCode = compiler.compile(sourceCode, filePath)
      writeCachedJavascript(cachePath, compiledCode)
    }
    return compiledCode
  }
  return sourceCode
}

function readCachedJavascript (relativeCachePath) {
  let cachePath = path.join(cacheDirectory, relativeCachePath)
  if (fs.isFileSync(cachePath)) {
    try {
      return fs.readFileSync(cachePath, 'utf8')
    } catch (error) {}
  }
  return null
}

function writeCachedJavascript (relativeCachePath, code) {
  let cachePath = path.join(cacheDirectory, relativeCachePath)
  fs.writeFileSync(cachePath, code, 'utf8')
}

const InlineSourceMapRegExp = /\/\/[#@]\s*sourceMappingURL=([^'"]+)\s*$/g

require('source-map-support').install({
  handleUncaughtExceptions: false,

  // Most of this logic is the same as the default implementation in the
  // source-map-support module, but we've overridden it to read the javascript
  // code from our cache directory.
  retrieveSourceMap: function (filePath) {
    if (!fs.isFileSync(filePath)){
      return null
    }

    let sourceCode = fs.readFileSync(filePath, 'utf8')
    let compiler = COMPILERS[path.extname(filePath)]
    let fileData = readCachedJavascript(compiler.getCachePath(sourceCode, filePath))
    if (fileData == null) {
      return null
    }

    let match, lastMatch
    InlineSourceMapRegExp.lastIndex = 0
    while ((match = InlineSourceMapRegExp.exec(fileData))) {
      lastMatch = match
    }
    if (lastMatch == null){
      return null
    }

    let sourceMappingURL = lastMatch[1]
    let rawData = sourceMappingURL.slice(sourceMappingURL.indexOf(',') + 1)
    let sourceMapData = new Buffer(rawData, 'base64').toString()

    return {
      map: JSON.parse(sourceMapData),
      url: null
    }
  }
})
