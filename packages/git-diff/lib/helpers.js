'use babel';

const { Directory } = require('atom');

export default async function(goalPath) {
  if (goalPath) {
    return atom.project.repositoryForDirectory(new Directory(goalPath));
  }
  return null;
}
