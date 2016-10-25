let windowLoadSettings;

export function getWindowLoadSettings () {
  windowLoadSettings = windowLoadSettings || JSON.parse(window.decodeURIComponent(window.location.hash.substr(1)))
  return windowLoadSettings
}

export function setWindowLoadSettings (settings) {
  windowLoadSettings = settings
  location.hash = encodeURIComponent(JSON.stringify(settings))
}
