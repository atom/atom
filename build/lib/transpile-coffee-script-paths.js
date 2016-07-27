// This module exports a function that transpiles all .coffee files into the
// appropriate location in the build output directory.

'use strict'

const coffee = require('coffee-script')
const fs = require('fs')
const glob = require('glob')
const mkdirp = require('mkdirp')
const path = require('path')

const CONFIG = require('../config')

module.exports =
function transpileCoffeeScriptPaths () {
  console.log('Transpiling CoffeeScript paths...');
  for (let path of getPathsToTranspile()) {
    transpileCoffeeScriptPath(path)
  }
}

function getPathsToTranspile () {
  let paths = []
  paths = paths.concat(glob.sync(`${CONFIG.electronAppPath}/src/**/*.coffee`))
  paths = paths.concat(glob.sync(`${CONFIG.electronAppPath}/spec/*.coffee`, {ignore: '**/*-spec.coffee'}))
  paths = paths.concat(glob.sync(`${CONFIG.electronAppPath}/exports/**/*.coffee`))
  return paths
}

function transpileCoffeeScriptPath (coffeePath) {
  const inputCode = fs.readFileSync(coffeePath, 'utf8')
  const jsPath = coffeePath.replace(/coffee$/g, 'js')
  fs.writeFileSync(jsPath, coffee.compile(inputCode))
  fs.unlinkSync(coffeePath)
}
