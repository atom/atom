#!/usr/bin/env node

'use strict'

const transpileBabelPaths = require('./lib/transpile-babel-paths')

function transpile () {
  transpileBabelPaths()
}

transpile()
