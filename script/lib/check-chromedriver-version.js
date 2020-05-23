'use strict';

const buildMetadata = require('../package.json');
const CONFIG = require('../config');
const semver = require('semver');

module.exports = function() {
  // Chromedriver should be at least v9.0.0
  // Mksnapshot should be at least v9.0.2
  const chromedriverVer = buildMetadata.dependencies['electron-chromedriver'];
  const mksnapshotVer = buildMetadata.dependencies['electron-mksnapshot'];
  const chromedriverActualVer = require('electron-chromedriver/package.json').version;
  const mksnapshotActualVer = require('electron-mksnapshot/package.json').version;

  // Always use caret on electron-chromedriver so that it can pick up the best minor/patch versions
  if (!chromedriverVer.startsWith('^')) {
    throw new Error(
      `electron-chromedriver version in script/package.json should start with a caret to match latest patch version.`
    );
  }

  if (!mksnapshotVer.startsWith('^')) {
    throw new Error(
      `electron-mksnapshot version in script/package.json should start with a caret to match latest patch version.`
    );
  }

  if (!semver.satisfies(chromedriverActualVer, '>=9.0.0')) {
    throw new Error(
      `electron-chromedriver should be at least v9.0.0 to support the ELECTRON_CUSTOM_VERSION environment variable.`
    );
  }

  if (!semver.satisfies(mksnapshotActualVer, '>=9.0.2')) {
    throw new Error(
      `electron-chromedriver should be at least v9.0.2 to support the ELECTRON_CUSTOM_VERSION environment variable.`
    );
  }
};
