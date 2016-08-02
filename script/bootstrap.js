#!/usr/bin/env node

'use strict'

const path = require('path')

const cleanDependencies = require('./lib/clean-dependencies')
const dependenciesFingerprint = require('./lib/dependencies-fingerprint')
const installApm = require('./lib/install-apm')
const installAtomDependencies = require('./lib/install-atom-dependencies')
const installScriptDependencies = require('./lib/install-script-dependencies')
const verifyMachineRequirements = require('./lib/verify-machine-requirements')

verifyMachineRequirements()

if (dependenciesFingerprint.isOutdated()) {
  cleanDependencies()
}

installScriptDependencies()
installApm()
installAtomDependencies()

dependenciesFingerprint.write()
