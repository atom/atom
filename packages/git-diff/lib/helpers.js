const { Directory } = require('atom');

async function repositoryForPath(path) {
  if (path) {
    return atom.project.repositoryForDirectory(new Directory(path));
  }
  return null;
}

module.exports = { repositoryForPath };
