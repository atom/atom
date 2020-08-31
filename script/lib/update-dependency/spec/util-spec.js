const path = require('path');
const fs = require('fs');
const repositoryRootPath = path.resolve('.', 'fixtures', 'dummy');
const packageJsonFilePath = path.join(repositoryRootPath, 'package.json');
const { updatePackageJson } = require('../util')(repositoryRootPath);
const { coreDependencies, nativeDependencies } = require('./helpers');

describe('Update-dependency', function() {
  const oldPackageJson = JSON.parse(
    JSON.stringify(require(packageJsonFilePath))
  );
  var packageJson;

  it('bumps package.json properly', async function() {
    const dependencies = [...coreDependencies, ...nativeDependencies];
    for (const dependency of dependencies) {
      await updatePackageJson(dependency);
      packageJson = JSON.parse(fs.readFileSync(packageJsonFilePath, 'utf-8'));
      if (dependency.isCorePackage) {
        expect(packageJson.packageDependencies[dependency.moduleName]).toBe(
          dependency.latest
        );
        expect(packageJson.dependencies[dependency.moduleName]).toContain(
          dependency.latest
        );
      } else {
        expect(packageJson.dependencies[dependency.moduleName]).toBe(
          dependency.latest
        );
      }
    }

    fs.writeFileSync(
      packageJsonFilePath,
      JSON.stringify(oldPackageJson, null, 2)
    );
  });
});
