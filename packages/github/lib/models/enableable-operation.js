const DISABLEMENT = Symbol('disablement');
const ENABLED = Symbol('enabled');
const NO_REASON = Symbol('no-reason');

// Track an operation that may be either enabled or disabled with a message and a reason. EnableableOperation instances
// are immutable to aid passing them as React component props; call `.enable()` or `.disable()` to derive a new
// operation instance with the same callback.
export default class EnableableOperation {
  constructor(op, options = {}) {
    this.beforeOp = null;
    this.op = op;
    this.afterOp = null;
    this.disablement = options[DISABLEMENT] || ENABLED;
  }

  toggleState(component, stateKey) {
    this.beforeOp = () => {
      component.setState(prevState => {
        return !prevState[stateKey] ? {[stateKey]: true} : {};
      });
    };

    this.afterOp = () => {
      return new Promise(resolve => {
        component.setState(prevState => {
          return prevState[stateKey] ? {[stateKey]: false} : {};
        }, resolve);
      });
    };
  }

  isEnabled() {
    return this.disablement === ENABLED;
  }

  async run() {
    if (!this.isEnabled()) {
      throw new Error(this.disablement.message);
    }

    if (this.beforeOp) {
      this.beforeOp();
    }
    let result = undefined;
    try {
      result = await this.op();
    } finally {
      if (this.afterOp) {
        await this.afterOp();
      }
    }
    return result;
  }

  getMessage() {
    return this.disablement.message;
  }

  why() {
    return this.disablement.reason;
  }

  disable(reason = NO_REASON, message = 'disabled') {
    if (!this.isEnabled() && this.disablement.reason === reason && this.disablement.message === message) {
      return this;
    }

    return new this.constructor(this.op, {[DISABLEMENT]: {reason, message}});
  }

  enable() {
    if (this.isEnabled()) {
      return this;
    }

    return new this.constructor(this.op, {[DISABLEMENT]: ENABLED});
  }
}
