const { remote } = require('electron');

let windowLoadSettings = null;

module.exports = () => {
  windowLoadSettings ??= JSON.parse(remote.getCurrentWindow().loadSettingsJSON);
  return windowLoadSettings;
};
