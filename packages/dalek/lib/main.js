/** @babel */

const dalek = require('./dalek');
const Grim = require('grim');

module.exports = {
  activate() {
    atom.packages.onDidActivateInitialPackages(async () => {
      const duplicates = await dalek.enumerate();
      for (let i = 0; i < duplicates.length; i++) {
        const duplicate = duplicates[i];
        Grim.deprecate(
          `You have the core package "${duplicate}" installed as a community package. See https://github.com/atom/atom/blob/master/packages/dalek/README.md for how this causes problems and instructions on how to correct the situation.`,
          { packageName: duplicate }
        );
      }
    });
  }
};
