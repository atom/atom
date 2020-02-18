const path = require('path');

const ROOT = path.resolve(__dirname, '../..');

function projectPath(...parts) {
  return path.join(ROOT, ...parts);
}

module.exports = {
  ROOT,
  projectPath,
};
