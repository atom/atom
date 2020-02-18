const DETACHED = Symbol('detached');
const REMOTE_TRACKING = Symbol('remote-tracking');

export default class Branch {
  constructor(name, upstream = nullBranch, push = upstream, head = false, attributes = {}) {
    this.name = name;
    this.upstream = upstream;
    this.push = push;
    this.head = head;
    this.attributes = attributes;
  }

  static createDetached(describe) {
    return new Branch(describe, nullBranch, nullBranch, true, {[DETACHED]: true});
  }

  static createRemoteTracking(refName, remoteName, remoteRef) {
    return new Branch(refName, nullBranch, nullBranch, false, {[REMOTE_TRACKING]: {remoteName, remoteRef}});
  }

  getName() {
    return this.name;
  }

  getShortRef() {
    return this.getName().replace(/^(refs\/)?((heads|remotes)\/)?/, '');
  }

  getFullRef() {
    if (this.isDetached()) {
      return '';
    }

    if (this.isRemoteTracking()) {
      if (this.name.startsWith('refs/')) {
        return this.name;
      } else if (this.name.startsWith('remotes/')) {
        return `refs/${this.name}`;
      }
      return `refs/remotes/${this.name}`;
    }

    if (this.name.startsWith('refs/')) {
      return this.name;
    } else if (this.name.startsWith('heads/')) {
      return `refs/${this.name}`;
    } else {
      return `refs/heads/${this.name}`;
    }
  }

  getRemoteName() {
    if (!this.isRemoteTracking()) {
      return '';
    }
    return this.attributes[REMOTE_TRACKING].remoteName || '';
  }

  getRemoteRef() {
    if (!this.isRemoteTracking()) {
      return '';
    }
    return this.attributes[REMOTE_TRACKING].remoteRef || '';
  }

  getShortRemoteRef() {
    return this.getRemoteRef().replace(/^(refs\/)?((heads|remotes)\/)?/, '');
  }

  getRefSpec(action) {
    if (this.isRemoteTracking()) {
      return '';
    }
    const remoteBranch = action === 'PUSH' ? this.push : this.upstream;
    const remoteBranchName = remoteBranch.getShortRemoteRef();
    const localBranchName = this.getName();
    if (remoteBranchName && remoteBranchName !== localBranchName) {
      if (action === 'PUSH') {
        return `${localBranchName}:${remoteBranchName}`;
      } else if (action === 'PULL') {
        return `${remoteBranchName}:${localBranchName}`;
      }
    }
    return localBranchName;
  }

  getSha() {
    return this.attributes.sha || '';
  }

  getUpstream() {
    return this.upstream;
  }

  getPush() {
    return this.push;
  }

  isHead() {
    return this.head;
  }

  isDetached() {
    return this.attributes[DETACHED] !== undefined;
  }

  isRemoteTracking() {
    return this.attributes[REMOTE_TRACKING] !== undefined;
  }

  isPresent() {
    return true;
  }

}

export const nullBranch = {
  getName() {
    return '';
  },

  getShortRef() {
    return '';
  },

  getFullRef() {
    return '';
  },

  getSha() {
    return '';
  },

  getUpstream() {
    return this;
  },

  getPush() {
    return this;
  },

  isHead() {
    return false;
  },

  getRemoteName() {
    return '';
  },

  getRemoteRef() {
    return '';
  },

  getShortRemoteRef() {
    return '';
  },

  isDetached() {
    return false;
  },

  isRemoteTracking() {
    return false;
  },

  isPresent() {
    return false;
  },

  inspect(depth, options) {
    return '{nullBranch}';
  },
};
