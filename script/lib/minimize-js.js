'use strict'

const fs = require('fs')
const glob = require('glob')
const path = require('path')

const UglifyJS = require('uglify-es')

const CONFIG = require('../config')

module.exports = function (sourceCode) {
  var compiledResult = UglifyJS.minify(sourceCode, { mangle: true,
    compress: {
      sequences: true,
      dead_code: true,
      conditionals: true,
      booleans: true,
      unused: true,
      if_return: true,
      join_vars: true,
      drop_console: true
    } })
  if(compiledResult.code){
    return compiledResult.code;
  }else{
    return sourceCode;
  }
}

