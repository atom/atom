const fs = require('fs');
const path = require('path');

const util = repositoryRootPath => {
  const packageJsonFilePath = path.join(repositoryRootPath, 'package.json');
  const packageJSON = require(packageJsonFilePath);
  return {
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
          new RegExp(installed),
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
    sleep: ms => new Promise(resolve => setTimeout(resolve, ms))
  };
};

module.exports = util;
