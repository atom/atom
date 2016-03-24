// This module exports a function that transpiles all .coffee files into the
// appropriate location in the build output directory.

'use strict'

const coffee = require('coffee-script')
const fs = require('fs')
const glob = require('glob')
const mkdirp = require('mkdirp')
const path = require('path')

const CONFIG = require('../config')
const computeDestinationPath = require('./compute-destination-path')

const GLOBS = [
  'src/**/*.coffee,spec/*.coffee',
  '!spec/*-spec.coffee',
  'exports/**/*.coffee',
  'static/**/*.coffee'
]

module.exports =
function transpileCoffeeScriptPaths () {
  console.log('Transpiling CoffeeScript paths...');
  for (let srcPath of getPathsToTranspile()) {
    transpileCoffeeScriptPath(srcPath, computeDestinationPath(srcPath).replace(/coffee$/, 'js'))
  }
}

function getPathsToTranspile () {
  let paths = []
  paths = paths.concat(glob.sync(`${CONFIG.repositoryRootPath}/src/**/*.coffee`))
  paths = paths.concat(glob.sync(`${CONFIG.repositoryRootPath}/spec/*.coffee`, {ignore: '**/*-spec.coffee'}))
  paths = paths.concat(glob.sync(`${CONFIG.repositoryRootPath}/exports/**/*.coffee`))
  return paths
}

function transpileCoffeeScriptPath (srcPath, destPath) {
  const inputCode = fs.readFileSync(srcPath, 'utf8')
  let outputCode = coffee.compile(inputCode)
  mkdirp.sync(path.dirname(destPath))
  fs.writeFileSync(destPath, outputCode)
}
