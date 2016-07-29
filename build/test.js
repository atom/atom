#!/usr/bin/env node

'use strict'

const async = require('async')
require('colors')

const path = require('path')
const childProcess = require('child_process')
const CONFIG = require('./config')

const packagedAppPath = path.resolve(__dirname, '..', 'out', 'Atom-darwin-x64')
const executablePath = path.join(packagedAppPath, 'Atom.app', 'Contents', 'MacOS', 'Atom')

const resourcePath = CONFIG.repositoryRootPath
const testPath = path.join(CONFIG.repositoryRootPath, 'spec')
const testArguments = [
  '--resource-path', resourcePath,
  '--test', testPath
]

function runCoreSpecs (callback) {
  console.log('Executing core specs...'.bold.green)
  const cp = childProcess.spawn(executablePath, testArguments, {stdio: 'inherit'})
  cp.on('error', error => { callback(error) })
  cp.on('close', exitCode => { callback(null, exitCode) })
}

async.parallelLimit([runCoreSpecs], 2, function (err, exitCodes) {
  if (err) {
    console.error(err)
    process.exit(1)
  } else {
    const testsPassed = exitCodes.every(exitCode => exitCode === 0)
    process.exit(testsPassed ? 0 : 1)
  }
})
