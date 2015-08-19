'use strict'

const _ = require('underscore-plus')
const crypto = require('crypto')
const path = require('path')

let babel = null
let babelVersionDirectory = null

// This field is used by the Gruntfile for compiling babel in bundled packages.
exports.defaultOptions = {

  // Currently, the cache key is a function of:
  // * The version of Babel used to transpile the .js file.
  // * The contents of this defaultOptions object.
  // * The contents of the .js file.
  // That means that we cannot allow information from an unknown source
  // to affect the cache key for the output of transpilation, which means
  // we cannot allow users to override these default options via a .babelrc
  // file, because the contents of that .babelrc file will not make it into
  // the cache key. It would be great to support .babelrc files once we
  // have a way to do so that is safe with respect to caching.
  breakConfig: true,

  sourceMap: 'inline',
  blacklist: ['es6.forOf', 'useStrict'],
  optional: ['asyncToGenerator'],
  stage: 0
}

exports.shouldCompile = function(sourceCode) {
  return sourceCode.startsWith('/** use babel */') ||
    sourceCode.startsWith('"use babel"') ||
    sourceCode.startsWith("'use babel'")
}

exports.getCachePath = function(sourceCode) {
  if (babelVersionDirectory == null) {
    let babelVersion = require('babel-core/package.json').version
    babelVersionDirectory = path.join('js', 'babel', createVersionAndOptionsDigest(babelVersion, defaultOptions))
  }

  return path.join(
    babelVersionDirectory,
    crypto
      .createHash('sha1')
      .update(sourceCode, 'utf8')
      .digest('hex') + ".js"
  )
}

exports.compile = function(sourceCode, filePath) {
  if (!babel) {
    babel = require('babel-core')
  }

  let options = _.defaults({filename: filePath}, defaultOptions)
  return babel.transform(sourceCode, options).code
}

function createVersionAndOptionsDigest (version, options) {
  return crypto
    .createHash('sha1')
    .update('babel-core', 'utf8')
    .update('\0', 'utf8')
    .update(version, 'utf8')
    .update('\0', 'utf8')
    .update(JSON.stringify(options), 'utf8')
    .digest('hex')
}
