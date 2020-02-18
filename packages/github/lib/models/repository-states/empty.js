import State from './state';

/**
 * The working directory exists, but contains no git repository yet.
 */
export default class Empty extends State {
  isEmpty() {
    return true;
  }

  init() {
    return this.transitionTo('Initializing');
  }

  clone(remoteUrl, sourceRemoteName) {
    return this.transitionTo('Cloning', remoteUrl, sourceRemoteName);
  }

  showGitTabInit() {
    return true;
  }
}

State.register(Empty);
