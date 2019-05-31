'use strict';

const donna = require('donna');
const tello = require('tello');
const joanna = require('joanna');
const glob = require('glob');
const fs = require('fs-extra');
const path = require('path');

const CONFIG = require('../config');

module.exports = function() {
  const generatedJSONPath = path.join(CONFIG.docsOutputPath, 'atom-api.json');
  console.log(`Generating API docs at ${generatedJSONPath}`);

  // Unfortunately, correct relative paths depend on a specific working
  // directory, but this script should be able to run from anywhere, so we
  // muck with the cwd temporarily.
  const oldWorkingDirectoryPath = process.cwd();
  process.chdir(CONFIG.repositoryRootPath);
  const coffeeMetadata = donna.generateMetadata(['.'])[0];
  const jsMetadata = joanna(glob.sync(`src/**/*.js`));
  process.chdir(oldWorkingDirectoryPath);

  const metadata = {
    repository: coffeeMetadata.repository,
    version: coffeeMetadata.version,
    files: Object.assign(coffeeMetadata.files, jsMetadata.files)
  };

  const api = tello.digest([metadata]);
  Object.assign(api.classes, getAPIDocsForDependencies());
  api.classes = sortObjectByKey(api.classes);

  fs.mkdirpSync(CONFIG.docsOutputPath);
  fs.writeFileSync(generatedJSONPath, JSON.stringify(api, null, 2));
};

function getAPIDocsForDependencies() {
  const classes = {};
  for (let apiJSONPath of glob.sync(
    `${CONFIG.repositoryRootPath}/node_modules/*/api.json`
  )) {
    Object.assign(classes, require(apiJSONPath).classes);
  }
  return classes;
}

function sortObjectByKey(object) {
  const sortedObject = {};
  for (let keyName of Object.keys(object).sort()) {
    sortedObject[keyName] = object[keyName];
  }
  return sortedObject;
}
