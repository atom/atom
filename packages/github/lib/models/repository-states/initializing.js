import State from './state';

/**
 * Git is asynchronously initializing a new repository in this working directory.
 */
export default class Initializing extends State {
  async start() {
    await this.doInit(this.workdir());

    await this.transitionTo('Loading');
  }

  showGitTabLoading() {
    return true;
  }

  directInit(workdir) {
    return this.git().init(workdir);
  }
}

State.register(Initializing);
