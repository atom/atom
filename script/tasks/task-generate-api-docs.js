'use strict';

const donna = require('donna');
const tello = require('tello');
const joanna = require('joanna');
const glob = require('glob');
const fs = require('fs-extra');
const path = require('path');

const CONFIG = require('../config');

module.exports = function(task) {
  const generatedJSONPath = path.join(CONFIG.docsOutputPath, 'atom-api.json');
  task.start(`Generating API docs at ${generatedJSONPath}`);

  // Unfortunately, correct relative paths depend on a specific working
  // directory, but this script should be able to run from anywhere, so we
  // muck with the cwd temporarily.
  const oldWorkingDirectoryPath = process.cwd();
  process.chdir(CONFIG.repositoryRootPath);
  task.verbose(
    `Updated cwd from ${oldWorkingDirectoryPath} to ${process.cwd()}`
  );

  task.info('Generating CS metadata with donna');
  const coffeeMetadata = donna.generateMetadata(['.'])[0];
  const numCsMetadataFiles = Object.entries(coffeeMetadata.files).length;
  task.info(`Generated ${numCsMetadataFiles} CS metadata files`);

  task.info('Generating JS metadata with joanna');
  const jsMetadata = joanna(glob.sync(`src/**/*.js`));
  const numJsMetadataFiles = Object.entries(jsMetadata.files).length;
  task.info(`Generated ${numJsMetadataFiles} JS metadata files`);

  process.chdir(oldWorkingDirectoryPath);
  task.verbose(
    `Restored cwd from ${CONFIG.repositoryRootPath} to ${process.cwd()}`
  );

  const metadata = {
    repository: coffeeMetadata.repository,
    version: coffeeMetadata.version,
    files: Object.assign(coffeeMetadata.files, jsMetadata.files)
  };

  if (
    numCsMetadataFiles + numJsMetadataFiles !==
    Object.entries(metadata.files).length
  ) {
    task.warn('Overlap between CS and JS metadata files');
  }

  task.info('Digesting metadata with tello');
  const api = tello.digest([metadata]);
  Object.assign(api.classes, getAPIDocsForDependencies());
  api.classes = sortObjectByKey(api.classes);

  task.info('Writing api data');
  fs.mkdirpSync(CONFIG.docsOutputPath);
  fs.writeFileSync(generatedJSONPath, JSON.stringify(api, null, 2));

  task.done();
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
