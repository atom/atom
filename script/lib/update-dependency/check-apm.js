const fetch = require('node-fetch');
// this may be updated to use github releases instead
module.exports = async function({ dependencies, packageDependencies }) {
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
