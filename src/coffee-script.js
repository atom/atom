'use strict'

const crypto = require('crypto')
const path = require('path')

// The coffee-script compiler is required eagerly because:
// 1. It is always used.
// 2. It reassigns Error.prepareStackTrace, so we need to make sure that
//    the 'source-map-support' module is installed *after* it is loaded.
const CoffeeScript = require('coffee-script')

exports.shouldCompile = function() {
  return true
}

exports.getCachePath = function(sourceCode) {
  return path.join(
    "coffee",
    crypto
      .createHash('sha1')
      .update(sourceCode, 'utf8')
      .digest('hex') + ".js"
  )
}

exports.compile = function(sourceCode, filePath) {
  let output = CoffeeScript.compile(sourceCode, {
    filename: filePath,
    sourceMap: true
  })

  let js = output.js
  js += '\n'
  js += '//# sourceMappingURL=data:application/json;base64,'
  js += new Buffer(output.v3SourceMap).toString('base64')
  js += '\n'
  return js
}
