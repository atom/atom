import {Emitter, Disposable} from 'event-kit';

export const PUSH = {
  getter(o) {
    return o.isPushInProgress();
  },
};

export const PULL = {
  getter(o) {
    return o.isPullInProgress();
  },
};

export const FETCH = {
  getter(o) {
    return o.isFetchInProgress();
  },
};

// Notify subscibers when a repository completes one or more operations of interest, as observed by its OperationState
// transitioning from `true` to `false`. For exampe, use this to perform actions when a push completes.
export default class OperationStateObserver {
  constructor(repository, ...operations) {
    this.repository = repository;
    this.operations = new Set(operations);
    this.emitter = new Emitter();

    this.lastStates = new Map();
    for (const operation of this.operations) {
      this.lastStates.set(operation, operation.getter(this.repository.getOperationStates()));
    }

    this.sub = this.repository.onDidUpdate(this.handleUpdate.bind(this));
  }

  onDidComplete(handler) {
    return this.emitter.on('did-complete', handler);
  }

  handleUpdate() {
    let fire = false;
    for (const operation of this.operations) {
      const last = this.lastStates.get(operation);
      const current = operation.getter(this.repository.getOperationStates());
      if (last && !current) {
        fire = true;
      }
      this.lastStates.set(operation, current);
    }
    if (fire) {
      this.emitter.emit('did-complete');
    }
  }

  dispose() {
    this.emitter.dispose();
    this.sub.dispose();
  }
}

export const nullOperationStateObserver = {
  onDidComplete() { return new Disposable(); },
  dispose() {},
};
