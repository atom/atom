import Refresher from '../../lib/models/refresher';

describe('Refresher', function() {
  let refresher;

  beforeEach(function() {
    refresher = new Refresher();
  });

  afterEach(function() {
    refresher.dispose();
  });

  it('calls the latest retry method registered per key instance when triggered', function() {
    const keyOne = Symbol('one');
    const keyTwo = Symbol('two');

    const one0 = sinon.spy();
    const one1 = sinon.spy();
    const two0 = sinon.spy();

    refresher.setRetryCallback(keyOne, one0);
    refresher.setRetryCallback(keyOne, one1);
    refresher.setRetryCallback(keyTwo, two0);

    refresher.trigger();

    assert.isFalse(one0.called);
    assert.isTrue(one1.called);
    assert.isTrue(two0.called);
  });

  it('deregisters a retry callback for a key', function() {
    const keyOne = Symbol('one');
    const keyTwo = Symbol('two');

    const one = sinon.spy();
    const two = sinon.spy();

    refresher.setRetryCallback(keyOne, one);
    refresher.setRetryCallback(keyTwo, two);

    refresher.deregister(keyOne);

    refresher.trigger();

    assert.isFalse(one.called);
    assert.isTrue(two.called);
  });

  it('deregisters all retry callbacks on dispose', function() {
    const keyOne = Symbol('one');
    const keyTwo = Symbol('two');

    const one = sinon.spy();
    const two = sinon.spy();

    refresher.setRetryCallback(keyOne, one);
    refresher.setRetryCallback(keyTwo, two);

    refresher.dispose();
    refresher.trigger();

    assert.isFalse(one.called);
    assert.isFalse(two.called);
  });
});
