import State from './state';

/**
 * The package is being cleaned up or the context is being disposed some other way.
 */
export default class Destroyed extends State {
  start() {
    this.didDestroy();
    this.repository.git.destroy && this.repository.git.destroy();
    this.repository.emitter.dispose();
  }

  isDestroyed() {
    return true;
  }

  destroy() {
    // No-op to destroy twice
  }
}

State.register(Destroyed);
