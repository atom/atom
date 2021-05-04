const path = require('path');
const fs = require('fs-plus');

module.exports = class StorageFolder {
  constructor(containingPath) {
    if (containingPath) {
      this.path = path.join(containingPath, 'storage');
    }
  }

  store(name, object) {
    return new Promise((resolve, reject) => {
      if (!this.path) return resolve();
      fs.writeFile(
        this.pathForKey(name),
        JSON.stringify(object),
        'utf8',
        error => (error ? reject(error) : resolve())
      );
    });
  }

  load(name) {
    return new Promise(resolve => {
      if (!this.path) return resolve(null);
      const statePath = this.pathForKey(name);
      fs.readFile(statePath, 'utf8', (error, stateString) => {
        if (error && error.code !== 'ENOENT') {
          console.warn(
            `Error reading state file: ${statePath}`,
            error.stack,
            error
          );
        }

        if (!stateString) return resolve(null);

        try {
          resolve(JSON.parse(stateString));
        } catch (error) {
          console.warn(
            `Error parsing state file: ${statePath}`,
            error.stack,
            error
          );
          resolve(null);
        }
      });
    });
  }

  pathForKey(name) {
    return path.join(this.getPath(), name);
  }

  getPath() {
    return this.path;
  }
};
