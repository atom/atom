// a require function with both ES5 and ES6 default export support
function requireModule(path) {
  const modul = require(path);
  if (modul === null || modul === undefined) {
    // if null do not bother
    return modul;
  } else {
    if (
      modul.__esModule === true &&
      (modul.default !== undefined && modul.default !== null)
    ) {
      // __esModule flag is true and default is exported, which means that
      // an object containing the main functions (e.g. activate, etc) is default exported
      return modul.default;
    } else {
      return modul;
    }
  }
}

exports.requireModule = requireModule;
