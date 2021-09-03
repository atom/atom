const fs = require('fs-plus');

// Converts a query string parameter for a line or column number
// to a zero-based line or column number for the Atom API.
function getLineColNumber(numStr) {
  const num = parseInt(numStr || 0, 10);
  return Math.max(num - 1, 0);
}

function openFile(atom, { query }) {
  const { filename, line, column } = query;

  atom.workspace.open(filename, {
    initialLine: getLineColNumber(line),
    initialColumn: getLineColNumber(column),
    searchAllPanes: true
  });
}

function windowShouldOpenFile({ query }) {
  const { filename } = query;
  const stat = fs.statSyncNoException(filename);

  return win =>
    win.containsLocation({
      pathToOpen: filename,
      exists: Boolean(stat),
      isFile: stat.isFile(),
      isDirectory: stat.isDirectory()
    });
}

const ROUTER = {
  '/open/file': { handler: openFile, getWindowPredicate: windowShouldOpenFile }
};

module.exports = {
  create(atomEnv) {
    return function coreURIHandler(parsed) {
      const config = ROUTER[parsed.pathname];
      if (config) {
        config.handler(atomEnv, parsed);
      }
    };
  },

  windowPredicate(parsed) {
    const config = ROUTER[parsed.pathname];
    if (config && config.getWindowPredicate) {
      return config.getWindowPredicate(parsed);
    } else {
      return () => true;
    }
  }
};
