const npmCheck = require('npm-check');

module.exports = async function(cwd) {
  try {
    console.log('Checking npm registry...');

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
