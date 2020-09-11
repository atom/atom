const notarize = require('electron-notarize').notarize;

const { DefaultTask } = require('./task');

module.exports = async function(packagedAppPath, task = new DefaultTask()) {
  const appBundleId = 'com.github.atom';
  const appleId = process.env.AC_USER;
  const appleIdPassword = process.env.AC_PASSWORD;
  task.start(`Notarizing application at ${packagedAppPath}`);

  try {
    await notarize({
      appBundleId: appBundleId,
      appPath: packagedAppPath,
      appleId: appleId,
      appleIdPassword: appleIdPassword
    });
  } catch (e) {
    throw new Error(e);
  }

  task.done();
};
