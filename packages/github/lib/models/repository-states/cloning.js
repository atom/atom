import fs from 'fs-extra';

import State from './state';

/**
 * Git is asynchronously cloning a repository into this working directory.
 */
export default class Cloning extends State {
  constructor(repository, remoteUrl, sourceRemoteName) {
    super(repository);
    this.remoteUrl = remoteUrl;
    this.sourceRemoteName = sourceRemoteName;
  }

  async start() {
    await fs.mkdirs(this.workdir());
    await this.doClone(this.remoteUrl, {recursive: true, sourceRemoteName: this.sourceRemoteName});

    await this.transitionTo('Loading');
  }

  showGitTabLoading() {
    return true;
  }

  directClone(remoteUrl, options) {
    return this.git().clone(remoteUrl, options);
  }
}

State.register(Cloning);
