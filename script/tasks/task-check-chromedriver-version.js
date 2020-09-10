'use strict';

const semver = require('semver');
const chromedriverMetadataPath = require('electron-chromedriver/package.json');
const mksnapshotMetadataPath = require('electron-mksnapshot/package.json');

const buildMetadata = require('../package.json');
const { DefaultTask } = require('../lib/task');

module.exports = function(task = new DefaultTask()) {
  task.start('Check chromedriver version');

  // Chromedriver should be at least v9.0.0
  // Mksnapshot should be at least v9.0.2
  const chromedriverVer = buildMetadata.dependencies['electron-chromedriver'];
  const mksnapshotVer = buildMetadata.dependencies['electron-mksnapshot'];
  const chromedriverActualVer = chromedriverMetadataPath.version;
  const mksnapshotActualVer = mksnapshotMetadataPath.version;

  task.info(`chromedriver target version: ${chromedriverVer}`);
  task.info(`chromedriver actual version: ${chromedriverActualVer}`);

  task.info(`mksnapshot target version: ${mksnapshotVer}`);
  task.info(`mksnapshot actual version: ${mksnapshotActualVer}`);

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
      `electron-mksnapshot should be at least v9.0.2 to support the ELECTRON_CUSTOM_VERSION environment variable.`
    );
  }

  task.done();
};
