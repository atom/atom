const fs = require('fs-plus');
const path = require('path');

const hasWriteAccess = dir => {
  const testFilePath = path.join(dir, 'write.test');
  try {
    fs.writeFileSync(testFilePath, new Date().toISOString(), { flag: 'w+' });
    fs.unlinkSync(testFilePath);
    return true;
  } catch (err) {
    return false;
  }
};

const getAppDirectory = () => {
  switch (process.platform) {
    case 'darwin':
      return process.execPath.substring(
        0,
        process.execPath.indexOf('.app') + 4
      );
    case 'linux':
    case 'win32':
      return path.join(process.execPath, '..');
  }
};

module.exports = {
  setAtomHome: homePath => {
    // When a read-writeable .atom folder exists above app use that
    const portableHomePath = path.join(getAppDirectory(), '..', '.atom');
    if (fs.existsSync(portableHomePath)) {
      if (hasWriteAccess(portableHomePath)) {
        process.env.ATOM_HOME = portableHomePath;
      } else {
        // A path exists so it was intended to be used but we didn't have rights, so warn.
        console.log(
          `Insufficient permission to portable Atom home "${portableHomePath}".`
        );
      }
    }

    // Check ATOM_HOME environment variable next
    if (process.env.ATOM_HOME !== undefined) {
      return;
    }

    // Fall back to default .atom folder in users home folder
    process.env.ATOM_HOME = path.join(homePath, '.atom');
  },

  setUserData: app => {
    const electronUserDataPath = path.join(
      process.env.ATOM_HOME,
      'electronUserData'
    );
    if (fs.existsSync(electronUserDataPath)) {
      if (hasWriteAccess(electronUserDataPath)) {
        app.setPath('userData', electronUserDataPath);
      } else {
        // A path exists so it was intended to be used but we didn't have rights, so warn.
        console.log(
          `Insufficient permission to Electron user data "${electronUserDataPath}".`
        );
      }
    }
  },

  getAppDirectory: getAppDirectory
};
