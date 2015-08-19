'use strict'

const _ = require('underscore-plus')
const crypto = require('crypto')
const path = require('path')

let TypeScriptSimple = null
let typescriptVersionDir = null

const defaultOptions = {
  target: 1,
  module: 'commonjs',
  sourceMap: true
}

exports.shouldCompile = function() {
  return true
}

exports.getCachePath = function(sourceCode) {
  if (typescriptVersionDir == null) {
    let version = require('typescript-simple/package.json').version
    typescriptVersionDir = path.join('ts', createVersionAndOptionsDigest(version, defaultOptions))
  }

  return path.join(
    typescriptVersionDir,
    crypto
      .createHash('sha1')
      .update(sourceCode, 'utf8')
      .digest('hex') + ".js"
  )
}

exports.compile = function(sourceCode, filePath) {
  if (!TypeScriptSimple) {
    TypeScriptSimple = require('typescript-simple').TypeScriptSimple
  }

  let options = _.defaults({filename: filePath}, defaultOptions)
  return new TypeScriptSimple(options, false).compile(sourceCode, filePath)
}

function createVersionAndOptionsDigest (version, options) {
  return crypto
    .createHash('sha1')
    .update('typescript', 'utf8')
    .update('\0', 'utf8')
    .update(version, 'utf8')
    .update('\0', 'utf8')
    .update(JSON.stringify(options), 'utf8')
    .digest('hex')
}
