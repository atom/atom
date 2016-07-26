#!/usr/bin/env node

'use strict'

const cleanOutputDirectory = require('./lib/clean-output-directory')
const transpileBabelPaths = require('./lib/transpile-babel-paths')
const transpileCoffeeScriptPaths = require('./lib/transpile-coffee-script-paths')
const copyStaticAssets = require('./lib/copy-static-assets')

cleanOutputDirectory()
transpileBabelPaths()
transpileCoffeeScriptPaths()
copyStaticAssets()
