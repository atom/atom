const path = require('path');

const CONFIG = require('../config');

module.exports = function() {
  // We can't require fs-extra or glob if `script/bootstrap` has never been run,
  // because they are third party modules. This is okay because cleaning
  // dependencies only makes sense if dependencies have been installed at least
  // once.
  const fs = require('fs-extra');
  const glob = require('glob');

  const apmDependenciesPath = path.join(CONFIG.apmRootPath, 'node_modules');
  console.log(`Cleaning ${apmDependenciesPath}`);
  fs.removeSync(apmDependenciesPath);

  const atomDependenciesPath = path.join(
    CONFIG.repositoryRootPath,
    'node_modules'
  );
  console.log(`Cleaning ${atomDependenciesPath}`);
  fs.removeSync(atomDependenciesPath);

  const scriptDependenciesPath = path.join(
    CONFIG.scriptRootPath,
    'node_modules'
  );
  console.log(`Cleaning ${scriptDependenciesPath}`);
  fs.removeSync(scriptDependenciesPath);

  const bundledPackageDependenciesPaths = path.join(
    CONFIG.repositoryRootPath,
    'packages',
    '**',
    'node_modules'
  );
  for (const bundledPackageDependencyPath of glob.sync(
    bundledPackageDependenciesPaths
  )) {
    fs.removeSync(bundledPackageDependencyPath);
  }
};
