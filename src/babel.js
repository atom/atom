'use strict'

const _ = require('underscore-plus')
const crypto = require('crypto')
const path = require('path')

let babel = null
let babelVersionDirectory = null

const defaultOptions = require('../static/babelrc.json')

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
