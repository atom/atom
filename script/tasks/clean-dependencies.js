const path = require('path');

const CONFIG = require('../config');
const {taskify} = require("../lib/task");

module.exports = taskify("Clean dependencies", function() {
  // We can't require fs-extra or glob if `script/bootstrap` has never been run,
  // because they are third party modules. This is okay because cleaning
  // dependencies only makes sense if dependencies have been installed at least
  // once.

  let fs;
  let glob;

  try {
    fs = require('fs-extra');
    glob = require('glob');
  } catch(e) {
    this.error("Could not import fs and glob modules, have you run bootstrap?");
    return;
  }

  const apmDependenciesPath = path.join(CONFIG.apmRootPath, 'node_modules');
  this.update(`Cleaning ${apmDependenciesPath}`);
  fs.removeSync(apmDependenciesPath);

  const atomDependenciesPath = path.join(
    CONFIG.repositoryRootPath,
    'node_modules'
  );
  this.update(`Cleaning ${atomDependenciesPath}`);
  fs.removeSync(atomDependenciesPath);

  const scriptDependenciesPath = path.join(
    CONFIG.scriptRootPath,
    'node_modules'
  );
  this.update(`Cleaning ${scriptDependenciesPath}`);
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
}, {canFail: true});
