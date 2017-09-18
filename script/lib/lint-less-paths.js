'use strict'

const csslint = require('csslint').CSSLint
const expandGlobPaths = require('./expand-glob-paths')
const LessCache = require('less-cache')
const path = require('path')
const readFiles = require('./read-files')

const CONFIG = require('../config')
const LESS_CACHE_VERSION = require('less-cache/package.json').version

module.exports = function () {
  const globPathsToLint = [
    path.join(CONFIG.repositoryRootPath, 'static/**/*.less')
  ]
  const lintOptions = {
    'adjoining-classes': false,
    'duplicate-background-images': false,
    'box-model': false,
    'box-sizing': false,
    'bulletproof-font-face': false,
    'compatible-vendor-prefixes': false,
    'display-property-grouping': false,
    'duplicate-properties': false,
    'fallback-colors': false,
    'font-sizes': false,
    'gradients': false,
    'ids': false,
    'important': false,
    'known-properties': false,
    'order-alphabetical': false,
    'outline-none': false,
    'overqualified-elements': false,
    'regex-selectors': false,
    'qualified-headings': false,
    'unique-headings': false,
    'universal-selector': false,
    'vendor-prefix': false
  }
  for (let rule of csslint.getRules()) {
    if (!lintOptions.hasOwnProperty(rule.id)) lintOptions[rule.id] = true
  }
  const lessCache = new LessCache({
    cacheDir: path.join(CONFIG.intermediateAppPath, 'less-compile-cache'),
    fallbackDir: path.join(CONFIG.atomHomeDirPath, 'compile-cache', 'prebuild-less', LESS_CACHE_VERSION),
    syncCaches: true,
    resourcePath: CONFIG.repositoryRootPath,
    importPaths: [
      path.join(CONFIG.intermediateAppPath, 'static', 'variables'),
      path.join(CONFIG.intermediateAppPath, 'static')
    ]
  })
  return expandGlobPaths(globPathsToLint).then(readFiles).then((files) => {
    const errors = []
    for (let file of files) {
      const css = lessCache.cssForFile(file.path, file.content)
      const result = csslint.verify(css, lintOptions)
      for (let message of result.messages) {
        errors.push({path: file.path.replace(/\.less$/, '.css'), lineNumber: message.line, message: message.message, rule: message.rule.id})
      }
    }
    return errors
  })
}
