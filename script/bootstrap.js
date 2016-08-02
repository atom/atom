#!/usr/bin/env node

'use strict'

const path = require('path')

const installApm = require('./lib/install-apm')
const installAtomDependencies = require('./lib/install-atom-dependencies')
const installScriptDependencies = require('./lib/install-script-dependencies')
const verifyMachineRequirements = require('./lib/verify-machine-requirements')

verifyMachineRequirements()
installScriptDependencies()
installApm()
installAtomDependencies()
