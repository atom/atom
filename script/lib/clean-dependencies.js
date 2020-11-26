const path = require('path');

const CONFIG = require('../config');

module.exports = function() {
  // We can't require fs-extra or glob if `script/bootstrap` has never been run,
  // because they are third party modules. This is okay because cleaning
  // dependencies only makes sense if dependencies have been installed at least
  // once.
  const fs = require('fs-extra');
  const glob = require('glob');

  const rmPromises = [];

  const apmDependenciesPath = path.join(CONFIG.apmRootPath, 'node_modules');
  console.log(`Cleaning ${apmDependenciesPath}`);
  rmPromises.push(fs.remove(apmDependenciesPath));

  const atomDependenciesPath = path.join(
    CONFIG.repositoryRootPath,
    'node_modules'
  );
  console.log(`Cleaning ${atomDependenciesPath}`);
  rmPromises.push(fs.remove(atomDependenciesPath));

  const scriptDependenciesPath = path.join(
    CONFIG.scriptRootPath,
    'node_modules'
  );
  console.log(`Cleaning ${scriptDependenciesPath}`);
  rmPromises.push(fs.remove(scriptDependenciesPath));

  const bundledPackageDependenciesPaths = path.join(
    CONFIG.repositoryRootPath,
    'packages',
    '**',
    'node_modules'
  );
  for (const bundledPackageDependencyPath of glob.sync(
    bundledPackageDependenciesPaths
  )) {
    rmPromises.push(fs.remove(bundledPackageDependencyPath));
  }

  return Promise.all(rmPromises);
};
