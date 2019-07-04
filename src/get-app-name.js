const { app } = require('electron');
const getReleaseChannel = require('./get-release-channel');

module.exports = function getAppName() {
  if (process.type === 'renderer') {
    return atom.getAppName();
  }

  const releaseChannel = getReleaseChannel(app.getVersion());
  const appNameParts = [app.getName()];

  if (releaseChannel !== 'stable') {
    appNameParts.push(
      releaseChannel.charAt(0).toUpperCase() + releaseChannel.slice(1)
    );
  }

  return appNameParts.join(' ');
};
