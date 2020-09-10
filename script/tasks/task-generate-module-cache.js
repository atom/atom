'use strict';

const fs = require('fs');
const path = require('path');
const ModuleCache = require('../../src/module-cache');

const CONFIG = require('../config');

module.exports = function(task) {
  task.start(`Generating module cache for ${CONFIG.intermediateAppPath}`);

  const packageNames = Object.keys(CONFIG.appMetadata.packageDependencies);
  if (packageNames.length === 0) {
    task.warn('No packages to cache');
  } else {
    task.info(`Caching ${packageNames.length} packages`);
  }

  for (let packageName of packageNames) {
    ModuleCache.create(
      path.join(CONFIG.intermediateAppPath, 'node_modules', packageName)
    );
  }

  task.info(
    `Creating intermediate app path cache ${CONFIG.intermediateAppPath}`
  );
  ModuleCache.create(CONFIG.intermediateAppPath);
  const newMetadata = JSON.parse(
    fs.readFileSync(path.join(CONFIG.intermediateAppPath, 'package.json'))
  );

  for (let folder of newMetadata._atomModuleCache.folders) {
    if (folder.paths.indexOf('') !== -1) {
      folder.paths = [
        '',
        'exports',
        'spec',
        'src',
        'src/main-process',
        'static',
        'vendor'
      ];
    }
  }

  task.info('Writing intermediate app path metadata');
  CONFIG.appMetadata = newMetadata;
  fs.writeFileSync(
    path.join(CONFIG.intermediateAppPath, 'package.json'),
    JSON.stringify(CONFIG.appMetadata)
  );

  task.done();
};
