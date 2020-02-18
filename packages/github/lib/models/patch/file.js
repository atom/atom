export default class File {
  static modes = {
    // Non-executable, non-symlink
    NORMAL: '100644',

    // +x bit set
    EXECUTABLE: '100755',

    // Soft link to another filesystem location
    SYMLINK: '120000',

    // Submodule mount point
    GITLINK: '160000',
  }

  constructor({path, mode, symlink}) {
    this.path = path;
    this.mode = mode;
    this.symlink = symlink;
  }

  getPath() {
    return this.path;
  }

  getMode() {
    return this.mode;
  }

  getSymlink() {
    return this.symlink;
  }

  isSymlink() {
    return this.getMode() === this.constructor.modes.SYMLINK;
  }

  isRegularFile() {
    return this.getMode() === this.constructor.modes.NORMAL || this.getMode() === this.constructor.modes.EXECUTABLE;
  }

  isExecutable() {
    return this.getMode() === this.constructor.modes.EXECUTABLE;
  }

  isPresent() {
    return true;
  }

  clone(opts = {}) {
    return new File({
      path: opts.path !== undefined ? opts.path : this.path,
      mode: opts.mode !== undefined ? opts.mode : this.mode,
      symlink: opts.symlink !== undefined ? opts.symlink : this.symlink,
    });
  }
}

export const nullFile = {
  getPath() {
    /* istanbul ignore next */
    return null;
  },

  getMode() {
    /* istanbul ignore next */
    return null;
  },

  getSymlink() {
    /* istanbul ignore next */
    return null;
  },

  isSymlink() {
    return false;
  },

  isRegularFile() {
    return false;
  },

  isExecutable() {
    return false;
  },

  isPresent() {
    return false;
  },

  clone(opts = {}) {
    if (opts.path === undefined && opts.mode === undefined && opts.symlink === undefined) {
      return this;
    } else {
      return new File({
        path: opts.path !== undefined ? opts.path : this.getPath(),
        mode: opts.mode !== undefined ? opts.mode : this.getMode(),
        symlink: opts.symlink !== undefined ? opts.symlink : this.getSymlink(),
      });
    }
  },
};
