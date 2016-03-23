#!/usr/bin/env node

'use strict'

const transpileBabelPaths = require('./lib/transpile-babel-paths')
const transpileCoffeeScriptPaths = require('./lib/transpile-coffee-script-paths')

function transpile () {
  // transpileBabelPaths()
  transpileCoffeeScriptPaths()
}

transpile()
