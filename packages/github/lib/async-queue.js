class Task {
  constructor(fn, parallel = true) {
    this.fn = fn;
    this.parallel = parallel;
    this.promise = new Promise((resolve, reject) => {
      this.resolve = resolve;
      this.reject = reject;
    });
  }

  async execute() {
    try {
      const value = await this.fn.call(undefined);
      this.resolve(value);
    } catch (err) {
      this.reject(err);
    }
  }

  runsInParallel() {
    return this.parallel;
  }

  runsInSerial() {
    return !this.parallel;
  }

  getPromise() {
    return this.promise;
  }
}

export default class AsyncQueue {
  constructor(options = {}) {
    this.parallelism = options.parallelism || 1;
    this.nonParallelizableOperation = false;
    this.tasksInProgress = 0;
    this.queue = [];
  }

  push(fn, {parallel} = {parallel: true}) {
    const task = new Task(fn, parallel);
    this.queue.push(task);
    this.processQueue();
    return task.getPromise();
  }

  processQueue() {
    if (!this.queue.length || this.nonParallelizableOperation || this.disposed) { return; }

    const task = this.queue[0];
    const canRunParallelOp = task.runsInParallel() && this.tasksInProgress < this.parallelism;
    const canRunSerialOp = task.runsInSerial() && this.tasksInProgress === 0;
    if (canRunSerialOp || canRunParallelOp) {
      this.processTask(task, task.runsInParallel());
      this.queue.shift();
      this.processQueue();
    }
  }

  async processTask(task, runsInParallel) {
    if (this.disposed) { return; }

    this.tasksInProgress++;
    if (!runsInParallel) {
      this.nonParallelizableOperation = true;
    }

    try {
      await task.execute();
    } finally {
      this.tasksInProgress--;
      this.nonParallelizableOperation = false;
      this.processQueue();
    }
  }

  dispose() {
    this.queue = [];
    this.disposed = true;
  }
}
