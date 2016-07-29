#!/usr/bin/env node

'use strict'

require('coffee-script/register')
require('babel-core/register')

const cleanOutputDirectory = require('./lib/clean-output-directory')
const copyAssets = require('./lib/copy-assets')
const transpileBabelPaths = require('./lib/transpile-babel-paths')
const transpileCoffeeScriptPaths = require('./lib/transpile-coffee-script-paths')
const transpileCsonPaths = require('./lib/transpile-cson-paths')
const transpilePegJsPaths = require('./lib/transpile-peg-js-paths')
const generateModuleCache = require('./lib/generate-module-cache')
const generateMetadata = require('./lib/generate-metadata')
const packageApplication = require('./lib/package-application')

cleanOutputDirectory()
copyAssets()
transpileBabelPaths()
transpileCoffeeScriptPaths()
transpileCsonPaths()
transpilePegJsPaths()
generateModuleCache()
generateMetadata()
packageApplication()
