const { remote } = require('electron');

let windowLoadSettings = null;

module.exports = () => {
  iwindowLoadSettings ??= JSON.parse(remote.getCurrentWindow().loadSettingsJSON);
  return windowLoadSettings;
};
