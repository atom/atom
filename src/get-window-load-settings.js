const {remote} = require('electron')

let windowLoadSettings = null

module.exports = () => {
  if (!windowLoadSettings) {
    windowLoadSettings = remote.getCurrentWindow().loadSettings
  }
  return windowLoadSettings
}
