/** @babel */

let clipboard

// Using clipboard in renderer process is not safe on Linux.
if (process.platform === 'linux' && process.type === 'renderer') {
  clipboard = require('electron').remote.clipboard
} else {
  clipboard = require('electron').clipboard;
}

export default clipboard
