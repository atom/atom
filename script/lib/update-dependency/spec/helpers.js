const latestPackageJSON = require('./fixtures/latest-package.json');
const packageJSON = require('./fixtures/dummy/package.json');
module.exports = {
  coreDependencies: Object.keys(packageJSON.packageDependencies).map(
    dependency => {
      return {
        latest: latestPackageJSON.packageDependencies[dependency],
        installed: packageJSON.packageDependencies[dependency],
        moduleName: dependency,
        isCorePackage: true
      };
    }
  ),
  nativeDependencies: Object.keys(packageJSON.dependencies)
    .filter(
      dependency =>
        !packageJSON.dependencies[dependency].match(new RegExp('^https?://'))
    )
    .map(dependency => {
      return {
        latest: latestPackageJSON.dependencies[dependency],
        packageJson: packageJSON.dependencies[dependency],
        installed: packageJSON.dependencies[dependency],
        moduleName: dependency,
        isCorePackage: false
      };
    })
};
