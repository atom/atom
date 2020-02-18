import {remote} from 'electron';
const {BrowserWindow} = remote;

import WorkerManager, {Operation, Worker} from '../lib/worker-manager';
import {isProcessAlive} from './helpers';

describe('WorkerManager', function() {
  let workerManager;
  beforeEach(function() {
    if (process.env.ATOM_GITHUB_INLINE_GIT_EXEC) {
      this.skip();
      return;
    }

    workerManager = new WorkerManager();
  });

  afterEach(function() {
    workerManager.destroy(true);
  });

  describe('isReady()', function() {
    it('returns true if its worker is ready', async function() {
      assert.isFalse(workerManager.isReady());
      await workerManager.getReadyPromise();
      assert.isTrue(workerManager.isReady());

      workerManager.onSick(workerManager.getActiveWorker());
      assert.isFalse(workerManager.isReady());
      await workerManager.getReadyPromise();
      assert.isTrue(workerManager.isReady());
    });
  });

  describe('when a worker process crashes', function() {
    it('creates a new worker process (with the same operation count limit) and executes remaining operations', async function() {
      workerManager.createNewWorker({operationCountLimit: 40});
      sinon.stub(Operation.prototype, 'execute');

      const worker1 = workerManager.getActiveWorker();
      await worker1.getReadyPromise();
      workerManager.request();
      workerManager.request();
      workerManager.request();
      const worker1OperationsInFlight = worker1.getRemainingOperations();
      assert.lengthOf(worker1OperationsInFlight, 3);

      const worker1Pid = worker1.getPid();
      process.kill(worker1Pid, 'SIGKILL');

      await assert.async.notEqual(worker1, workerManager.getActiveWorker());
      const worker2 = workerManager.getActiveWorker();
      await worker2.getReadyPromise();
      assert.notEqual(worker2.getPid(), worker1Pid);
      assert.equal(worker2.getOperationCountLimit(), worker1.getOperationCountLimit());
      assert.deepEqual(worker2.getRemainingOperations(), worker1OperationsInFlight);
    });
  });

  describe('when a worker process is sick', function() {
    it('creates a new worker with a new operation count limit that is based on the limit and completed operation count of the last worker', function() {

      function createSickWorker(operationCountLimit, completedOperationCount) {
        const sickWorker = workerManager.getActiveWorker();
        sinon.stub(sickWorker, 'getOperationCountLimit').returns(operationCountLimit);
        sinon.stub(sickWorker, 'getCompletedOperationCount').returns(completedOperationCount);
        return sickWorker;
      }

      // when the last worker operation count limit was greater than or equal to the completed operation count
      // this means that the average spawn time for the first operationCountLimit operations was already higher than the threshold
      // the system is likely just slow, so we should increase the operationCountLimit so next time we do more operations before creating a new process
      const sickWorker1 = createSickWorker(10, 9);
      workerManager.onSick(sickWorker1);
      assert.notEqual(sickWorker1, workerManager.getActiveWorker());
      assert.equal(workerManager.getActiveWorker().getOperationCountLimit(), 20);

      const sickWorker2 = createSickWorker(50, 50);
      workerManager.onSick(sickWorker2);
      assert.notEqual(sickWorker2, workerManager.getActiveWorker());
      assert.equal(workerManager.getActiveWorker().getOperationCountLimit(), 100);

      const sickWorker3 = createSickWorker(100, 100);
      workerManager.onSick(sickWorker3);
      assert.notEqual(sickWorker3, workerManager.getActiveWorker());
      assert.equal(workerManager.getActiveWorker().getOperationCountLimit(), 100);

      // when the last worker operation count limit was less than the completed operation count
      // this means that the system is performing better and we can drop the operationCountLimit back down to the base limit
      const sickWorker4 = createSickWorker(100, 150);
      workerManager.onSick(sickWorker4);
      assert.notEqual(sickWorker4, workerManager.getActiveWorker());
      assert.equal(workerManager.getActiveWorker().getOperationCountLimit(), 10);
    });

    describe('when the sick process crashes', function() {
      it('completes remaining operations in existing active process', function() {
        const sickWorker = workerManager.getActiveWorker();

        sinon.stub(Operation.prototype, 'execute');
        workerManager.request();
        workerManager.request();
        workerManager.request();

        const operationsInFlight = sickWorker.getRemainingOperations();
        assert.equal(operationsInFlight.length, 3);

        workerManager.onSick(sickWorker);
        assert.notEqual(sickWorker, workerManager.getActiveWorker());
        const newWorker = workerManager.getActiveWorker();
        assert.equal(newWorker.getRemainingOperations(), 0);

        workerManager.onCrashed(sickWorker);
        assert.equal(workerManager.getActiveWorker(), newWorker);
        assert.equal(newWorker.getRemainingOperations().length, 3);
      });
    });
  });

  describe('destroy', function() {
    it('destroys the renderer processes created after they have completed their operations', async function() {
      const worker1 = workerManager.getActiveWorker();
      await worker1.getReadyPromise();

      sinon.stub(Operation.prototype, 'execute');
      workerManager.request();
      workerManager.request();
      workerManager.request();
      const worker1Operations = worker1.getRemainingOperations();
      assert.equal(worker1Operations.length, 3);

      workerManager.onSick(worker1);
      const worker2 = workerManager.getActiveWorker();
      await worker2.getReadyPromise();
      workerManager.request();
      workerManager.request();
      const worker2Operations = worker2.getRemainingOperations();
      assert.equal(worker2Operations.length, 2);

      workerManager.destroy();
      assert.isTrue(isProcessAlive(worker1.getPid()));
      assert.isTrue(isProcessAlive(worker2.getPid()));

      [...worker1Operations, ...worker2Operations].forEach(operation => operation.complete());
      await assert.async.isFalse(isProcessAlive(worker1.getPid()));
      await assert.async.isFalse(isProcessAlive(worker2.getPid()));
    });
  });

  describe('when the manager process is destroyed', function() {
    it('destroys all the renderer processes that were created', async function() {
      this.retries(5); // FLAKE

      const browserWindow = new BrowserWindow({show: !!process.env.ATOM_GITHUB_SHOW_RENDERER_WINDOW});
      browserWindow.loadURL('about:blank');
      sinon.stub(Worker.prototype, 'getWebContentsId').returns(browserWindow.webContents.id);

      const script = `
      const ipc = require('electron').ipcRenderer;
      ipc.on('${Worker.channelName}', function() {
        const args = Array.prototype.slice.apply(arguments)
        args.shift();

        args.unshift('${Worker.channelName}');
        args.unshift(${remote.getCurrentWebContents().id})
        ipc.sendTo.apply(ipc, args);
      });
      `;

      await new Promise(resolve => browserWindow.webContents.executeJavaScript(script, resolve));

      workerManager.destroy(true);
      workerManager = new WorkerManager();

      const worker1 = workerManager.getActiveWorker();
      await worker1.getReadyPromise();
      workerManager.onSick(worker1);
      const worker2 = workerManager.getActiveWorker();
      await worker2.getReadyPromise();

      browserWindow.destroy();
      await assert.async.isFalse(isProcessAlive(worker1.getPid()));
      await assert.async.isFalse(isProcessAlive(worker2.getPid()));
    });
  });
});
