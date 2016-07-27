#!/usr/bin/env node

'use strict'

const cleanOutputDirectory = require('./lib/clean-output-directory')
const copyAssets = require('./lib/copy-assets')
const transpileBabelPaths = require('./lib/transpile-babel-paths')
const transpileCoffeeScriptPaths = require('./lib/transpile-coffee-script-paths')

cleanOutputDirectory()
copyAssets()
transpileBabelPaths()
transpileCoffeeScriptPaths()
