export default class OperationStates {
  constructor(options = {}) {
    this.didUpdate = options.didUpdate || (() => {});
    this.pushInProgress = false;
    this.pullInProgress = false;
    this.fetchInProgress = false;
    this.commitInProgress = false;
    this.checkoutInProgress = false;
  }

  isPushInProgress() {
    return this.pushInProgress;
  }

  isPullInProgress() {
    return this.pullInProgress;
  }

  isFetchInProgress() {
    return this.fetchInProgress;
  }

  isCommitInProgress() {
    return this.commitInProgress;
  }

  isCheckoutInProgress() {
    return this.checkoutInProgress;
  }

  setPushInProgress(value) {
    const oldValue = this.pushInProgress;
    this.pushInProgress = value;
    if (oldValue !== value) {
      this.didUpdate();
    }
  }

  setPullInProgress(value) {
    const oldValue = this.pullInProgress;
    this.pullInProgress = value;
    if (oldValue !== value) {
      this.didUpdate();
    }
  }

  setFetchInProgress(value) {
    const oldValue = this.fetchInProgress;
    this.fetchInProgress = value;
    if (oldValue !== value) {
      this.didUpdate();
    }
  }

  setCommitInProgress(value) {
    const oldValue = this.commitInProgress;
    this.commitInProgress = value;
    if (oldValue !== value) {
      this.didUpdate();
    }
  }

  setCheckoutInProgress(value) {
    const oldValue = this.checkoutInProgress;
    this.checkoutInProgress = value;
    if (oldValue !== value) {
      this.didUpdate();
    }
  }
}

class NullOperationStates extends OperationStates {
  setPushInProgress() {
    // do nothing
  }

  setPullInProgress() {
    // do nothing
  }

  setFetchInProgress() {
    // do nothing
  }

  setCommitInProgress() {
    // do nothing
  }

  setCheckoutInProgress() {
    // do nothing
  }
}

export const nullOperationStates = new NullOperationStates();
