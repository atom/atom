'use strict';

const coffeelint = require('coffeelint');
const expandGlobPaths = require('./expand-glob-paths');
const path = require('path');
const readFiles = require('./read-files');

const CONFIG = require('../config');

module.exports = function() {
  const globPathsToLint = [
    path.join(CONFIG.repositoryRootPath, 'dot-atom/**/*.coffee'),
    path.join(CONFIG.repositoryRootPath, 'src/**/*.coffee'),
    path.join(CONFIG.repositoryRootPath, 'spec/*.coffee')
  ];
  return expandGlobPaths(globPathsToLint)
    .then(readFiles)
    .then(files => {
      const errors = [];
      const lintConfiguration = require(path.join(
        CONFIG.repositoryRootPath,
        'coffeelint.json'
      ));
      for (let file of files) {
        const lintErrors = coffeelint.lint(
          file.content,
          lintConfiguration,
          false
        );
        for (let error of lintErrors) {
          errors.push({
            path: file.path,
            lineNumber: error.lineNumber,
            message: error.message,
            rule: error.rule
          });
        }
      }
      return errors;
    });
};
