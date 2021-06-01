'use strict';

const crypto = require('crypto');
const path = require('path');
let CoffeeScript = null;

exports.shouldCompile = function() {
  return true;
};

exports.getCachePath = function(sourceCode) {
  return path.join(
    'coffee',
    crypto
      .createHash('sha1')
      .update(sourceCode, 'utf8')
      .digest('hex') + '.js'
  );
};

exports.compile = function(sourceCode, filePath) {
  if (!CoffeeScript) {
    const previousPrepareStackTrace = Error.prepareStackTrace;
    CoffeeScript = require('coffee-script');

    // When it loads, coffee-script reassigns Error.prepareStackTrace. We have
    // already reassigned it via the 'source-map-support' module, so we need
    // to set it back.
    Error.prepareStackTrace = previousPrepareStackTrace;
  }

  if (process.platform === 'win32') {
    filePath = 'file:///' + path.resolve(filePath).replace(/\\/g, '/');
  }

  const output = CoffeeScript.compile(sourceCode, {
    filename: filePath,
    sourceFiles: [filePath],
    inlineMap: true
  });

  // Strip sourceURL from output so there wouldn't be duplicate entries
  // in devtools.
  return output.replace(/\/\/# sourceURL=[^'"\n]+\s*$/, '');
};
