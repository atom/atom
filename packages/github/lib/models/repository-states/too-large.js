import State from './state';

/**
 * The repository is too large for Atom to handle
 */
export default class TooLarge extends State {
  isTooLarge() {
    return true;
  }
}

State.register(TooLarge);
