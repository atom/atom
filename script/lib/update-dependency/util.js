const fs = require('fs');
const path = require('path');
const execa = require('execa');
const { repositoryRootPath } = require('../../config');
const packageJsonFilePath = path.join(repositoryRootPath, 'package.json');
const packageJSON = require(packageJsonFilePath);

const checkNPM = require('./check-npm');
const checkAPM = require('./check-apm');

module.exports = {
  fetchOutdatedDependencies: async function() {
    return [
      ...(await checkAPM(packageJSON)),
      ...(await checkNPM(repositoryRootPath))
    ];
  },
  updatePackageJson: async function({
    moduleName,
    installed,
    latest,
    isCorePackage = false,
    packageJson = ''
  }) {
    console.log(`Bumping ${moduleName} from ${installed} to ${latest}`);
    const updatePackageJson = JSON.parse(JSON.stringify(packageJSON));
    if (updatePackageJson.dependencies[moduleName]) {
      let searchString = installed;
      // gets the exact version installed in package json for native packages
      if (!isCorePackage) {
        if (/\^|~/.test(packageJson)) {
          searchString = new RegExp(`\\${packageJson}`);
        } else {
          searchString = packageJson;
        }
        console.log(searchString,updatePackageJson.dependencies[moduleName])
      }
      updatePackageJson.dependencies[
        moduleName
      ] = updatePackageJson.dependencies[moduleName].replace(
        searchString,
        latest
      );
    }
    if (updatePackageJson.packageDependencies[moduleName]) {
      updatePackageJson.packageDependencies[
        moduleName
      ] = updatePackageJson.packageDependencies[moduleName].replace(
        new RegExp(`${installed}`),
        latest
      );
    }
    return new Promise((resolve, reject) => {
      fs.writeFile(
        packageJsonFilePath,
        JSON.stringify(updatePackageJson, null, 2),
        function(err) {
          if (err) {
            return reject(err);
          }

          console.log(`Bumped ${moduleName} from ${installed} to ${latest}`);
          return resolve();
        }
      );
    });
  },
  runApmInstall: async function() {
    console.log('apm install');

    return execa('apm', ['install'], { cwd: repositoryRootPath })
      .then(result => result.failed)
      .catch(ex => {
        console.log(`failed to install module`);
        return false;
      });
  },
  sleep: ms => new Promise(resolve => setTimeout(resolve, ms))
};
