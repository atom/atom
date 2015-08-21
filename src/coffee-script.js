'use strict'

var crypto = require('crypto')
var path = require('path')
var CoffeeScript = null

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
  if (!CoffeeScript) {
    CoffeeScript = require('coffee-script')
  }

  var output = CoffeeScript.compile(sourceCode, {
    filename: filePath,
    sourceFiles: [filePath],
    sourceMap: true
  })

  var js = output.js
  js += '\n'
  js += '//# sourceMappingURL=data:application/json;base64,'
  js += new Buffer(output.v3SourceMap).toString('base64')
  js += '\n'
  return js
}
