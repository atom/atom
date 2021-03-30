'use strict';

const fs = require('fs');
const path = require('path');
const legalEagle = require('legal-eagle');

const licenseOverrides = require('../license-overrides');
const CONFIG = require('../config');

module.exports = function() {
  return new Promise((resolve, reject) => {
    legalEagle(
      { path: CONFIG.repositoryRootPath, overrides: licenseOverrides },
      (err, packagesLicenses) => {
        if (err) {
          reject(err);
          throw new Error(err);
        } else {
          let text =
            fs.readFileSync(
              path.join(CONFIG.repositoryRootPath, 'LICENSE.md'),
              'utf8'
            ) +
            '\n\n' +
            'This application bundles the following third-party packages in accordance\n' +
            'with the following licenses:\n\n';
          for (const packageName of Object.keys(packagesLicenses).sort()) {
            const packageLicense = packagesLicenses[packageName];
            text +=
              '-------------------------------------------------------------------------\n\n' +
              `Package: ${packageName}\n` +
              `License: ${packageLicense.license}\n`;

            // Could possibly use the `in` operator
            if (packageLicense.source) {
              text += `License Source: ${packageLicense.source}\n`;
            }
            if (packageLicense.sourceText) {
              text += `Source Text:\n\n${packageLicense.sourceText}`;
            }
            text += '\n';
          }
          resolve(text);
        }
      }
    );
  });
};
