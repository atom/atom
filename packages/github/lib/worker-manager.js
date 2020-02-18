import path from 'path';
import querystring from 'querystring';

import {remote, ipcRenderer as ipc} from 'electron';
const {BrowserWindow} = remote;
import {Emitter, Disposable, CompositeDisposable} from 'event-kit';

import {getPackageRoot, autobind} from './helpers';

export default class WorkerManager {
  static instance = null;

  static getInstance() {
    if (!this.instance) {
      this.instance = new WorkerManager();
    }
    return this.instance;
  }

  static reset(force) {
    if (this.instance) { this.instance.destroy(force); }
    this.instance = null;
  }

  constructor() {
    autobind(this, 'onDestroyed', 'onCrashed', 'onSick');

    this.workers = new Set();
    this.activeWorker = null;
    this.createNewWorker();
  }

  isReady() {
    return this.activeWorker.isReady();
  }

  request(data) {
    if (this.destroyed) { throw new Error('Worker is destroyed'); }
    let operation;
    const requestPromise = new Promise((resolve, reject) => {
      operation = new Operation(data, resolve, reject);
      return this.activeWorker.executeOperation(operation);
    });
    operation.setPromise(requestPromise);
    return {
      cancel: () => this.activeWorker.cancelOperation(operation),
      promise: requestPromise,
    };
  }

  createNewWorker({operationCountLimit} = {operationCountLimit: 10}) {
    if (this.destroyed) { return; }
    this.activeWorker = new Worker({
      operationCountLimit,
      onDestroyed: this.onDestroyed,
      onCrashed: this.onCrashed,
      onSick: this.onSick,
    });
    this.workers.add(this.activeWorker);
  }

  onDestroyed(destroyedWorker) {
    this.workers.delete(destroyedWorker);
  }

  onCrashed(crashedWorker) {
    if (crashedWorker === this.getActiveWorker()) {
      this.createNewWorker({operationCountLimit: crashedWorker.getOperationCountLimit()});
    }
    crashedWorker.getRemainingOperations().forEach(operation => this.activeWorker.executeOperation(operation));
  }

  onSick(sickWorker) {
    if (!atom.inSpecMode()) {
      // eslint-disable-next-line no-console
      console.warn(`Sick worker detected.
        operationCountLimit: ${sickWorker.getOperationCountLimit()},
        completed operation count: ${sickWorker.getCompletedOperationCount()}`);
    }
    const operationCountLimit = this.calculateNewOperationCountLimit(sickWorker);
    return this.createNewWorker({operationCountLimit});
  }

  calculateNewOperationCountLimit(lastWorker) {
    let operationCountLimit = 10;
    if (lastWorker.getOperationCountLimit() >= lastWorker.getCompletedOperationCount()) {
      operationCountLimit = Math.min(lastWorker.getOperationCountLimit() * 2, 100);
    }
    return operationCountLimit;
  }

  getActiveWorker() {
    return this.activeWorker;
  }

  getReadyPromise() {
    return this.activeWorker.getReadyPromise();
  }

  destroy(force) {
    this.destroyed = true;
    this.workers.forEach(worker => worker.destroy(force));
  }
}


export class Worker {
  static channelName = 'github:renderer-ipc';

  constructor({operationCountLimit, onSick, onCrashed, onDestroyed}) {
    autobind(
      this,
      'handleDataReceived', 'onOperationComplete', 'handleCancelled', 'handleExecStarted', 'handleSpawnError',
      'handleStdinError', 'handleSick', 'handleCrashed',
    );

    this.operationCountLimit = operationCountLimit;
    this.onSick = onSick;
    this.onCrashed = onCrashed;
    this.onDestroyed = onDestroyed;

    this.operationsById = new Map();
    this.completedOperationCount = 0;
    this.sick = false;

    this.rendererProcess = new RendererProcess({
      loadUrl: this.getLoadUrl(operationCountLimit),
      onData: this.handleDataReceived,
      onCancelled: this.handleCancelled,
      onExecStarted: this.handleExecStarted,
      onSpawnError: this.handleSpawnError,
      onStdinError: this.handleStdinError,
      onSick: this.handleSick,
      onCrashed: this.handleCrashed,
      onDestroyed: this.destroy,
    });
  }

  isReady() {
    return this.rendererProcess.isReady();
  }

  getLoadUrl(operationCountLimit) {
    const htmlPath = path.join(getPackageRoot(), 'lib', 'renderer.html');
    const rendererJsPath = path.join(getPackageRoot(), 'lib', 'worker.js');
    const qs = querystring.stringify({
      js: rendererJsPath,
      managerWebContentsId: this.getWebContentsId(),
      operationCountLimit,
      channelName: Worker.channelName,
    });
    return `file://${htmlPath}?${qs}`;
  }

  getWebContentsId() {
    return remote.getCurrentWebContents().id;
  }

  executeOperation(operation) {
    this.operationsById.set(operation.id, operation);
    operation.onComplete(this.onOperationComplete);
    return this.rendererProcess.executeOperation(operation);
  }

  cancelOperation(operation) {
    return this.rendererProcess.cancelOperation(operation);
  }

  handleDataReceived({id, results}) {
    const operation = this.operationsById.get(id);
    operation.complete(results, data => {
      const {timing} = data;
      const totalInternalTime = timing.execTime + timing.spawnTime;
      const ipcTime = operation.getExecutionTime() - totalInternalTime;
      data.timing.ipcTime = ipcTime;
      return data;
    });
  }

  onOperationComplete(operation) {
    this.completedOperationCount++;
    this.operationsById.delete(operation.id);

    if (this.sick && this.operationsById.size === 0) {
      this.destroy();
    }
  }

  handleCancelled({id}) {
    const operation = this.operationsById.get(id);
    if (operation) {
      // handleDataReceived() can be received before handleCancelled()
      operation.wasCancelled();
    }
  }

  handleExecStarted({id}) {
    const operation = this.operationsById.get(id);
    operation.setInProgress();
  }

  handleSpawnError({id, err}) {
    const operation = this.operationsById.get(id);
    operation.error(err);
  }

  handleStdinError({id, stdin, err}) {
    const operation = this.operationsById.get(id);
    operation.error(err);
  }

  handleSick() {
    this.sick = true;
    this.onSick(this);
  }

  handleCrashed() {
    this.onCrashed(this);
    this.destroy();
  }

  getOperationCountLimit() {
    return this.operationCountLimit;
  }

  getCompletedOperationCount() {
    return this.completedOperationCount;
  }

  getRemainingOperations() {
    return Array.from(this.operationsById.values());
  }

  getPid() {
    return this.rendererProcess.getPid();
  }

  getReadyPromise() {
    return this.rendererProcess.getReadyPromise();
  }

  async destroy(force) {
    this.onDestroyed(this);
    if (this.operationsById.size > 0 && !force) {
      const remainingOperationPromises = this.getRemainingOperations()
        .map(operation => operation.getPromise().catch(() => null));
      await Promise.all(remainingOperationPromises);
    }
    this.rendererProcess.destroy();
  }
}


/*
Sends operations to renderer processes
*/
export class RendererProcess {
  constructor({loadUrl,
    onDestroyed, onCrashed, onSick, onData, onCancelled, onSpawnError, onStdinError, onExecStarted}) {
    autobind(this, 'handleDestroy');
    this.onDestroyed = onDestroyed;
    this.onCrashed = onCrashed;
    this.onSick = onSick;
    this.onData = onData;
    this.onCancelled = onCancelled;
    this.onSpawnError = onSpawnError;
    this.onStdinError = onStdinError;
    this.onExecStarted = onExecStarted;

    this.win = new BrowserWindow({show: !!process.env.ATOM_GITHUB_SHOW_RENDERER_WINDOW});
    this.webContents = this.win.webContents;
    // this.webContents.openDevTools();

    this.emitter = new Emitter();
    this.subscriptions = new CompositeDisposable();
    this.registerListeners();

    this.win.loadURL(loadUrl);
    this.win.webContents.on('crashed', this.handleDestroy);
    this.win.webContents.on('destroyed', this.handleDestroy);
    this.subscriptions.add(
      new Disposable(() => {
        if (!this.win.isDestroyed()) {
          this.win.webContents.removeListener('crashed', this.handleDestroy);
          this.win.webContents.removeListener('destroyed', this.handleDestroy);
          this.win.destroy();
        }
      }),
      this.emitter,
    );

    this.ready = false;
    this.readyPromise = new Promise(resolve => { this.resolveReady = resolve; });
  }

  isReady() {
    return this.ready;
  }

  handleDestroy(...args) {
    this.destroy();
    this.onCrashed(...args);
  }

  registerListeners() {
    const handleMessages = (event, {sourceWebContentsId, type, data}) => {
      if (sourceWebContentsId === this.win.webContents.id) {
        this.emitter.emit(type, data);
      }
    };

    ipc.on(Worker.channelName, handleMessages);
    this.emitter.on('renderer-ready', ({pid}) => {
      this.pid = pid;
      this.ready = true;
      this.resolveReady();
    });
    this.emitter.on('git-data', this.onData);
    this.emitter.on('git-cancelled', this.onCancelled);
    this.emitter.on('git-spawn-error', this.onSpawnError);
    this.emitter.on('git-stdin-error', this.onStdinError);
    this.emitter.on('slow-spawns', this.onSick);

    // not currently used to avoid clogging up ipc channel
    // keeping it around as it's potentially useful for avoiding duplicate write operations upon renderer crashing
    this.emitter.on('exec-started', this.onExecStarted);

    this.subscriptions.add(
      new Disposable(() => ipc.removeListener(Worker.channelName, handleMessages)),
    );
  }

  executeOperation(operation) {
    return operation.execute(payload => {
      if (this.destroyed) { return null; }
      return this.webContents.send(Worker.channelName, {
        type: 'git-exec',
        data: payload,
      });
    });
  }

  cancelOperation(operation) {
    return operation.cancel(payload => {
      if (this.destroyed) { return null; }
      return this.webContents.send(Worker.channelName, {
        type: 'git-cancel',
        data: payload,
      });
    });
  }

  getPid() {
    return this.pid;
  }

  getReadyPromise() {
    return this.readyPromise;
  }

  destroy() {
    this.destroyed = true;
    this.subscriptions.dispose();
  }
}


export class Operation {
  static status = {
    PENDING: Symbol('pending'),
    INPROGRESS: Symbol('in-progress'),
    COMPLETE: Symbol('complete'),
    CANCELLING: Symbol('cancelling'),
    CANCELLED: Symbol('canceled'),
  }

  static id = 0;

  constructor(data, resolve, reject) {
    this.id = Operation.id++;
    this.data = data;
    this.resolve = resolve;
    this.reject = reject;
    this.promise = null;
    this.cancellationResolve = () => {};
    this.startTime = null;
    this.endTime = null;
    this.status = Operation.status.PENDING;
    this.results = null;
    this.emitter = new Emitter();
  }

  onComplete(cb) {
    return this.emitter.on('complete', cb);
  }

  setPromise(promise) {
    this.promise = promise;
  }

  getPromise() {
    return this.promise;
  }

  setInProgress() {
    // after exec has been called but before results a received
    this.status = Operation.status.INPROGRESS;
  }

  getExecutionTime() {
    if (!this.startTime || !this.endTime) {
      return NaN;
    } else {
      return this.endTime - this.startTime;
    }
  }

  complete(results, mutate = data => data) {
    this.endTime = performance.now();
    this.results = results;
    this.resolve(mutate(results));
    this.cancellationResolve();
    this.status = Operation.status.COMPLETE;
    this.emitter.emit('complete', this);
    this.emitter.dispose();
  }

  wasCancelled() {
    this.status = Operation.status.CANCELLED;
    this.cancellationResolve();
  }

  error(results) {
    this.endTime = performance.now();
    const err = new Error(results.message, results.fileName, results.lineNumber);
    err.stack = results.stack;
    this.reject(err);
  }

  execute(execFn) {
    this.startTime = performance.now();
    return execFn({...this.data, id: this.id});
  }

  cancel(execFn) {
    return new Promise(resolve => {
      this.status = Operation.status.CANCELLING;
      this.cancellationResolve = resolve;
      execFn({id: this.id});
    });
  }
}
