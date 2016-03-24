// This module exports a function that transpiles all files with a babel prefix
// into the appropriate location in the build output directory.

'use strict'

module.exports = transpileBabelPaths

const babel = require('babel-core')
const fs = require('fs')
const glob = require('glob')
const mkdirp = require('mkdirp')
const path = require('path')
const computeDestinationPath = require('./compute-destination-path')

const CONFIG = require('../config')
const BABEL_OPTIONS = require('../../static/babelrc.json')
const BABEL_PREFIXES = [
  "'use babel'",
  '"use babel"',
  '/** @babel */',
  '/* @flow */'
]
const PREFIX_LENGTH = Math.max.apply(null, BABEL_PREFIXES.map(prefix => prefix.length))
const BUFFER = Buffer(PREFIX_LENGTH)

function transpileBabelPaths () {
  console.log('Transpiling Babel paths...');
  for (let srcPath of glob.sync(`${CONFIG.repositoryRootPath}/src/**/*.js`)) {
    if (usesBabel(srcPath)) {
      transpileBabelPath(srcPath, computeDestinationPath(srcPath))
    }
  }
}

function usesBabel (path) {
  const file = fs.openSync(path, 'r')
  fs.readSync(file, BUFFER, 0, PREFIX_LENGTH)
  fs.closeSync(file)
  const filePrefix = BUFFER.toString('utf8', 0, PREFIX_LENGTH).trim()
  return BABEL_PREFIXES.indexOf(filePrefix) !== -1
}

function transpileBabelPath (srcPath, destPath) {
  const options = Object.assign({}, BABEL_OPTIONS)
  options.sourceFileName = path.relative(path.dirname(destPath), srcPath)
  if (process.platform === 'win32') {
    options.sourceFileName = options.sourceFileName.replace(/\\/g, '/')
  }
  options.sourceMapTarget = path.basename(destPath)

  let result = babel.transformFileSync(srcPath, options)

  mkdirp.sync(path.dirname(destPath))
  fs.writeFileSync(destPath, result.code)
}
