const fetch = require('node-fetch');
const npmCheck = require('npm-check');

// this may be updated to use github releases instead
const apm = async function({ dependencies, packageDependencies }) {
  try {
    console.log('Checking apm registry...');
    const coreDependencies = Object.keys(dependencies).filter(dependency => {
      // all core packages point to a remote url
      return dependencies[dependency].match(new RegExp('^https?://'));
    });

    const promises = coreDependencies.map(async dependency => {
      return fetch(`https://atom.io/api/packages/${dependency}`)
        .then(res => res.json())
        .then(res => res)
        .catch(ex => console.log(ex.message));
    });

    const packages = await Promise.all(promises);
    const outdatedPackages = [];
    packages.map(dependency => {
      if (dependency.hasOwnProperty('name')) {
        const latestVersion = dependency.releases.latest;
        const installed = packageDependencies[dependency.name];
        if (latestVersion > installed) {
          outdatedPackages.push({
            moduleName: dependency.name,
            latest: dependency.releases.latest,
            isCorePackage: true,
            installed
          });
        }
      }
    });

    console.log(`${outdatedPackages.length} outdated package(s) found`);

    return outdatedPackages;
  } catch (ex) {
    console.error(`An error occured: ${ex.message}`);
  }
};

const npm = async function(cwd) {
  try {
    console.log('Checking npm registry...', cwd);

    const currentState = await npmCheck({
      cwd,
      ignoreDev: true,
      skipUnused: true
    });

    const outdatedPackages = currentState
      .get('packages')
      .filter(p => {
        if (p.packageJson && p.latest && p.installed) {
          return p.latest > p.installed;
        }
      })
      .map(({ packageJson, installed, moduleName, latest }) => ({
        packageJson,
        installed,
        moduleName,
        latest,
        isCorePackage: false
      }));

    console.log(`${outdatedPackages.length} outdated package(s) found`);

    return outdatedPackages;
  } catch (ex) {
    console.error(`An error occured: ${ex.message}`);
  }
};

module.exports = {
  apm,
  npm
};
