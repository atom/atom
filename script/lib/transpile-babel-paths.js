'use strict'

const CompileCache = require('../../src/compile-cache')
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

module.exports = function () {
  console.log(`Transpiling Babel paths in ${CONFIG.intermediateAppPath}`)
  for (let path of getPathsToTranspile()) {
    transpileBabelPath(path)
  }
}

function getPathsToTranspile () {
  let paths = []
  paths = paths.concat(glob.sync(path.join(CONFIG.intermediateAppPath, 'benchmarks', '**', '*.js'), {nodir: true}))
  paths = paths.concat(glob.sync(path.join(CONFIG.intermediateAppPath, 'exports', '**', '*.js'), {nodir: true}))
  paths = paths.concat(glob.sync(path.join(CONFIG.intermediateAppPath, 'src', '**', '*.js'), {nodir: true}))
  for (let packageName of Object.keys(CONFIG.appMetadata.packageDependencies)) {
    paths = paths.concat(glob.sync(
      path.join(CONFIG.intermediateAppPath, 'node_modules', packageName, '**', '*.js'),
      {ignore: path.join(CONFIG.intermediateAppPath, 'node_modules', packageName, 'spec', '**', '*.js'), nodir: true}
    ))
  }
  return paths
}

function transpileBabelPath (path) {
  fs.writeFileSync(path, CompileCache.addPathToCache(path, CONFIG.atomHomeDirPath))
}
