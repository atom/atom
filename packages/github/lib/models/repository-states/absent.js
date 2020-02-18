import State from './state';

/**
 * No working directory is available in the workspace.
 */
export default class Absent extends State {
  isAbsent() {
    return true;
  }

  showGitTabInit() {
    return true;
  }

  hasDirectory() {
    return false;
  }
}

State.register(Absent);
