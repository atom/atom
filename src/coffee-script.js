'use strict'

var crypto = require('crypto')
var path = require('path')
var CoffeeScript = null

exports.shouldCompile = function () {
  return true
}

exports.getCachePath = function (sourceCode) {
  return path.join(
    'coffee',
    crypto
      .createHash('sha1')
      .update(sourceCode, 'utf8')
      .digest('hex') + '.js'
  )
}

exports.compile = function (sourceCode, filePath) {
  if (!CoffeeScript) {
    var previousPrepareStackTrace = Error.prepareStackTrace
    CoffeeScript = require('coffee-script')

    // When it loads, coffee-script reassigns Error.prepareStackTrace. We have
    // already reassigned it via the 'source-map-support' module, so we need
    // to set it back.
    Error.prepareStackTrace = previousPrepareStackTrace
  }

  if (process.platform === 'win32') {
    filePath = 'file:///' + path.resolve(filePath).replace(/\\/g, '/')
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
