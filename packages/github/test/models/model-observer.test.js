import {Emitter} from 'event-kit';
import ModelObserver from '../../lib/models/model-observer';

class Model {
  constructor(a, b) {
    this.a = a;
    this.b = b;
    this.emitter = new Emitter();

    sinon.spy(this, 'fetchA');
    sinon.spy(this, 'fetchB');
  }

  fetchA() {
    return new Promise(res => res(this.a));
  }

  fetchB() {
    return new Promise(res => res(this.b));
  }

  onDidUpdate(cb) { return this.emitter.on('did-update', cb); }
  didUpdate(cb) { return this.emitter.emit('did-update'); }
  destroy() { this.emitter.dispose(); }
}

describe('ModelObserver', function() {
  let model1, model2, observer, fetchDataStub, didUpdateStub;

  beforeEach(function() {
    model1 = new Model('a', 'b');
    model2 = new Model('A', 'B');
    didUpdateStub = sinon.stub();
    fetchDataStub = sinon.spy(async model => ({a: await model.fetchA(), b: await model.fetchB()}));
    observer = new ModelObserver({
      fetchData: fetchDataStub,
      didUpdate: didUpdateStub,
    });
  });

  afterEach(function() {
    model1.destroy();
    model2.destroy();
  });

  it('fetches data asynchronously when the active model is set', async function() {
    observer.setActiveModel(model1);
    assert.equal(didUpdateStub.callCount, 1);
    assert.equal(observer.getActiveModel(), model1);
    assert.isTrue(didUpdateStub.getCall(0).calledWith(model1));
    assert.isNull(observer.getActiveModelData());

    await observer.lastFetchDataPromise;
    assert.equal(model1.fetchA.callCount, 1);
    assert.equal(model1.fetchB.callCount, 1);
    assert.equal(didUpdateStub.callCount, 2);
    assert.isTrue(didUpdateStub.getCall(1).calledWith(model1));
    assert.deepEqual(observer.getActiveModelData(), {a: 'a', b: 'b'});

    observer.setActiveModel(model2);
    assert.equal(observer.getActiveModel(), model2);
    assert.equal(didUpdateStub.callCount, 3);
    assert.isTrue(didUpdateStub.getCall(2).calledWith(model2));
    assert.isNull(observer.getActiveModelData());

    await observer.lastFetchDataPromise;
    assert.equal(model2.fetchA.callCount, 1);
    assert.equal(model2.fetchB.callCount, 1);
    assert.equal(didUpdateStub.callCount, 4);
    assert.deepEqual(observer.getActiveModelData(), {a: 'A', b: 'B'});

    observer.setActiveModel(null);
    assert.isNull(observer.getActiveModel());
    assert.isNull(observer.getActiveModelData());
    assert.equal(didUpdateStub.callCount, 5);
    assert.isTrue(didUpdateStub.getCall(4).calledWith(null));
  });

  it('fetches data asynchronously when the model is updated', async function() {
    observer.setActiveModel(model1);
    await observer.lastFetchDataPromise;
    assert.equal(model1.fetchA.callCount, 1);
    assert.equal(model1.fetchB.callCount, 1);
    assert.equal(didUpdateStub.callCount, 2);
    assert.deepEqual(observer.getActiveModelData(), {a: 'a', b: 'b'});

    model1.a = 'Ayy';
    model1.b = 'Bee';
    model1.didUpdate();

    await observer.lastFetchDataPromise;
    assert.equal(model1.fetchA.callCount, 2);
    assert.equal(model1.fetchB.callCount, 2);
    assert.equal(didUpdateStub.callCount, 3);
    assert.deepEqual(observer.getActiveModelData(), {a: 'Ayy', b: 'Bee'});
  });

  it('enqueues a fetch if the model changes during a fetch', async function() {
    observer.setActiveModel(model1);
    await observer.lastFetchDataPromise;
    assert.equal(model1.fetchA.callCount, 1);
    assert.equal(model1.fetchB.callCount, 1);
    assert.equal(didUpdateStub.callCount, 2);
    assert.deepEqual(observer.getActiveModelData(), {a: 'a', b: 'b'});

    fetchDataStub.resetHistory();
    didUpdateStub.resetHistory();
    // Update once...
    model1.didUpdate();
    // fetchData called immediately
    assert.equal(fetchDataStub.callCount, 1);

    // Update again on same tick
    model1.didUpdate();
    // second fetchData not yet called
    assert.equal(fetchDataStub.callCount, 1);

    assert.equal(didUpdateStub.callCount, 0);
    await observer.lastFetchDataPromise;
    assert.equal(didUpdateStub.callCount, 1);
    // second fetchData started immediatelay after previous one ends
    assert.equal(fetchDataStub.callCount, 2);

    await observer.lastFetchDataPromise;
    assert.equal(didUpdateStub.callCount, 2);
  });

  it('enqueues at most one pending fetch', async function() {
    observer.setActiveModel(model1);
    await observer.lastFetchDataPromise;
    assert.equal(model1.fetchA.callCount, 1);
    assert.equal(model1.fetchB.callCount, 1);
    assert.equal(didUpdateStub.callCount, 2);
    assert.deepEqual(observer.getActiveModelData(), {a: 'a', b: 'b'});

    fetchDataStub.resetHistory();
    didUpdateStub.resetHistory();
    // Update once...
    model1.didUpdate();
    // fetchData called immediately
    assert.equal(fetchDataStub.callCount, 1);

    for (let i = 0; i < 10; i++) {
      model1.didUpdate();
    }

    // no updates triggered immediate fetches
    assert.equal(fetchDataStub.callCount, 1);

    assert.equal(didUpdateStub.callCount, 0);
    await observer.lastFetchDataPromise;
    assert.equal(didUpdateStub.callCount, 1);
    // Second fetchData started immediatelay after previous one ends
    assert.equal(fetchDataStub.callCount, 2);

    await observer.lastFetchDataPromise;
    assert.equal(didUpdateStub.callCount, 2);
    // None of the other 9 updates trigger, as they were essentially duplicates.
    assert.equal(fetchDataStub.callCount, 2);
  });

  it('clears any pending update and fetches immediately when the active model is set', async function() {
    observer.setActiveModel(model1);
    await observer.lastFetchDataPromise;
    assert.equal(model1.fetchA.callCount, 1);
    assert.equal(model1.fetchB.callCount, 1);
    assert.equal(didUpdateStub.callCount, 2);
    assert.deepEqual(observer.getActiveModelData(), {a: 'a', b: 'b'});

    fetchDataStub.resetHistory();
    didUpdateStub.resetHistory();
    // Update once...
    model1.didUpdate();
    // fetchData called immediately
    assert.equal(fetchDataStub.callCount, 1);
    // Update again ...
    model1.didUpdate();
    const originalFetchPromise = observer.lastFetchDataPromise;

    observer.setActiveModel(model2);
    // Model changed, so we fetch new data immediately
    assert.equal(fetchDataStub.callCount, 2);
    assert.isTrue(fetchDataStub.getCall(1).calledWith(model2));
    await originalFetchPromise;
    // Original fetch data has been discarded as it is now stale
    assert.isNull(observer.getActiveModelData());
    await observer.lastFetchDataPromise;
    // The previously pending fetch does not occur
    assert.equal(fetchDataStub.callCount, 2);
    assert.deepEqual(observer.getActiveModelData(), {a: 'A', b: 'B'});
  });
});
