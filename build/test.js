#!/usr/bin/env node

'use strict'

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

console.log('Executing core specs...'.bold.green)
childProcess.spawnSync(executablePath, testArguments, {stdio: 'inherit'})
