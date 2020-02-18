import State from './state';

/**
 * Initial state to be used when we anticipate that the workspace will contain a single project once bootstrapping
 * has completed. Presents in the UI like the Loading state.
 */
export default class LoadingGuess extends State {
  isLoadingGuess() {
    return true;
  }

  isUndetermined() {
    return true;
  }

  showGitTabLoading() {
    return true;
  }

  showGitTabInit() {
    return false;
  }

  hasDirectory() {
    return false;
  }
}

State.register(LoadingGuess);
