'use strict'

const stylelint = require('stylelint')
const expandGlobPaths = require('./expand-glob-paths')
const LessCache = require('less-cache')
const path = require('path')
const {flatten} = require('underscore-plus')

const readFiles = require('./read-files')
const CONFIG = require('../config')
const LESS_CACHE_VERSION = require('less-cache/package.json').version

module.exports = function() {
  return stylelint
    .lint({
      files: path.join(CONFIG.repositoryRootPath, 'static/**/*.less'),
      configFile: path.resolve(__dirname, '..', '..', 'stylelint.config.js'),
    })
    .then(({results}) => {
      return flatten(
        results.filter(_ => _.errored).map(result => {
          const errors = result.warnings.filter(_ => _.severity === 'error')
          return errors.map(e => ({
            path: result.source,
            lineNumber: e.line,
            message: e.text,
            rule: e.rule,
          }))
        }),
      )
    })
    .catch(err => {
      console.error('There was a problem linting LESS:')
      throw err
    })
}
