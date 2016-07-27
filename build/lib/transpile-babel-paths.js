// This module exports a function that transpiles all files with a babel prefix
// into the appropriate location in the build output directory.

'use strict'

module.exports = transpileBabelPaths

const babel = require('babel-core')
const fs = require('fs')
const glob = require('glob')
const path = require('path')

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
  for (let path of getPathsToTranspile()) {
    if (usesBabel(path)) {
      transpileBabelPath(path)
    }
  }
}

function getPathsToTranspile () {
  let paths = []
  paths = paths.concat(glob.sync(`${CONFIG.electronAppPath}/src/**/*.js`))
  for (let packageName of Object.keys(CONFIG.appMetadata.packageDependencies)) {
    paths = paths.concat(glob.sync(`${CONFIG.electronAppPath}/node_modules/${packageName}/**/*.js`))
  }
  return paths
}

function usesBabel (path) {
  const file = fs.openSync(path, 'r')
  fs.readSync(file, BUFFER, 0, PREFIX_LENGTH)
  fs.closeSync(file)
  const filePrefix = BUFFER.toString('utf8', 0, PREFIX_LENGTH).trim()
  return BABEL_PREFIXES.indexOf(filePrefix) !== -1
}

function transpileBabelPath (path) {
  const options = Object.assign({}, BABEL_OPTIONS)
  options.sourceMap = null
  fs.writeFileSync(path, babel.transformFileSync(path, options).code)
}
