#!/usr/bin/env node

'use strict'

require('coffee-script/register')

const cleanOutputDirectory = require('./lib/clean-output-directory')
const copyAssets = require('./lib/copy-assets')
const dumpSymbols = require('./lib/dump-symbols')
const generateMetadata = require('./lib/generate-metadata')
const generateModuleCache = require('./lib/generate-module-cache')
const packageApplication = require('./lib/package-application')
const prebuildLessCache = require('./lib/prebuild-less-cache')
const transpileBabelPaths = require('./lib/transpile-babel-paths')
const transpileCoffeeScriptPaths = require('./lib/transpile-coffee-script-paths')
const transpileCsonPaths = require('./lib/transpile-cson-paths')
const transpilePegJsPaths = require('./lib/transpile-peg-js-paths')
const writeFingerprint = require('./lib/fingerprint').writeFingerprint

cleanOutputDirectory()
copyAssets()
transpileBabelPaths()
transpileCoffeeScriptPaths()
transpileCsonPaths()
transpilePegJsPaths()
generateModuleCache()
prebuildLessCache()
generateMetadata()
writeFingerprint()
dumpSymbols().then(packageApplication)
