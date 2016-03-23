// This module exports a function that transpiles all .coffee files into the
// appropriate location in the build output directory.

'use strict'

const glob = require('glob')
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
  for (let srcPath of getPathsToTranspile()) {
    transpileCoffeeScriptPath(srcPath, computeDestinationPath(srcPath))
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
  console.log(srcPath);
}
