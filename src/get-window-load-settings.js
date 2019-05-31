const { remote } = require('electron');

let windowLoadSettings = null;

module.exports = () => {
  if (!windowLoadSettings) {
    windowLoadSettings = JSON.parse(remote.getCurrentWindow().loadSettingsJSON);
  }
  return windowLoadSettings;
};
