'use strict';

const stylelint = require('stylelint');
const path = require('path');

const CONFIG = require('../config');

module.exports = function() {
  return stylelint
    .lint({
      files: path.join(CONFIG.repositoryRootPath, 'static/**/*.less'),
      configBasedir: __dirname,
      configFile: path.resolve(__dirname, '..', '..', 'stylelint.config.js')
    })
    .then(({ results }) => {
      const errors = [];

      for (const result of results) {
        for (const deprecation of result.deprecations) {
          console.log('stylelint encountered deprecation:', deprecation.text);
          if (deprecation.reference != null) {
            console.log('more information at', deprecation.reference);
          }
        }

        for (const invalidOptionWarning of result.invalidOptionWarnings) {
          console.warn(
            'stylelint encountered invalid option:',
            invalidOptionWarning.text
          );
        }

        if (result.errored) {
          for (const warning of result.warnings) {
            if (warning.severity === 'error') {
              errors.push({
                path: result.source,
                lineNumber: warning.line,
                message: warning.text,
                rule: warning.rule
              });
            } else {
              console.warn(
                'stylelint encountered non-critical warning in file',
                result.source,
                'at line',
                warning.line,
                'for rule',
                warning.rule + ':',
                warning.text
              );
            }
          }
        }
      }

      return errors;
    })
    .catch(err => {
      console.error('There was a problem linting LESS:');
      throw err;
    });
};
