import State from './state';

/**
 * Initial state to be used when we anticipate that the workspace will contain zero or many projects once bootstrapping
 * has completed. Presents in the UI like the Absent state, but is "sticky" during the initial package activation.
 */
export default class AbsentGuess extends State {
  isAbsentGuess() {
    return true;
  }

  isUndetermined() {
    return true;
  }

  showGitTabLoading() {
    return false;
  }

  showGitTabInit() {
    return true;
  }

  hasDirectory() {
    return false;
  }
}

State.register(AbsentGuess);
