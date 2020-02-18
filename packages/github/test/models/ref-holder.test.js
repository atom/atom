import RefHolder from '../../lib/models/ref-holder';

describe('RefHolder', function() {
  let sub;

  afterEach(function() {
    if (sub) { sub.dispose(); }
  });

  it('begins empty', function() {
    const h = new RefHolder();
    assert.isTrue(h.isEmpty());
    assert.throws(() => h.get(), /empty/);
  });

  it('does not become populated when assigned null', function() {
    const h = new RefHolder();
    h.setter(null);
    assert.isTrue(h.isEmpty());
  });

  it('provides synchronous access to its current value', function() {
    const h = new RefHolder();
    h.setter(1234);
    assert.isFalse(h.isEmpty());
    assert.strictEqual(h.get(), 1234);
  });

  describe('map', function() {
    it('returns an empty RefHolder as-is', function() {
      const h = new RefHolder();
      assert.strictEqual(h.map(() => 14), h);
    });

    it('returns a new RefHolder wrapping the value returned from its present block', function() {
      const h = new RefHolder();
      h.setter(12);
      assert.strictEqual(h.map(x => x + 1).get(), 13);
    });

    it('returns a RefHolder returned from its present block', function() {
      const h0 = new RefHolder();
      h0.setter(14);

      const o = h0.map(() => {
        const h1 = new RefHolder();
        h1.setter(12);
        return h1;
      });

      assert.notStrictEqual(0, h0);
      assert.strictEqual(o.get(), 12);
    });

    it('returns a new RefHolder wrapping the value returned from its absent block', function() {
      const h = new RefHolder();

      const o = h.map(x => 1, () => 2);
      assert.strictEqual(o.get(), 2);
    });

    it('returns a RefHolder returned from its absent block', function() {
      const h0 = new RefHolder();

      const o = h0.map(x => 1, () => {
        const h1 = new RefHolder();
        h1.setter(1);
        return h1;
      });
      assert.strictEqual(o.get(), 1);
    });
  });

  describe('getOr', function() {
    it("returns the RefHolder's value if it is non-empty", function() {
      const h = new RefHolder();
      h.setter(1234);

      assert.strictEqual(h.getOr(5678), 1234);
    });

    it('returns its argument if the RefHolder is empty', function() {
      const h = new RefHolder();

      assert.strictEqual(h.getOr(5678), 5678);
    });
  });

  it('notifies subscribers when it becomes available', function() {
    const h = new RefHolder();
    const callback = sinon.spy();
    sub = h.observe(callback);

    h.setter(1);
    assert.isTrue(callback.calledWith(1));

    h.setter(2);
    assert.isTrue(callback.calledWith(2));

    sub.dispose();

    h.setter(3);
    assert.isFalse(callback.calledWith(3));
  });

  it('immediately notifies new subscribers if it is already available', function() {
    const h = new RefHolder();
    h.setter(12);

    const callback = sinon.spy();
    sub = h.observe(callback);
    assert.isTrue(callback.calledWith(12));
  });

  it('does not notify subscribers when it is assigned the same value', function() {
    const h = new RefHolder();
    h.setter(12);

    const callback = sinon.spy();
    sub = h.observe(callback);

    callback.resetHistory();
    h.setter(12);
    assert.isFalse(callback.called);
  });

  it('does not notify subscribers when it becomes empty', function() {
    const h = new RefHolder();
    h.setter(12);
    assert.isFalse(h.isEmpty());

    const callback = sinon.spy();
    sub = h.observe(callback);

    callback.resetHistory();
    h.setter(null);
    assert.isTrue(h.isEmpty());
    assert.isFalse(callback.called);

    callback.resetHistory();
    h.setter(undefined);
    assert.isTrue(h.isEmpty());
    assert.isFalse(callback.called);
  });

  it('resolves a promise when it becomes available', async function() {
    const thing = Symbol('Thing');
    const h = new RefHolder();

    const promise = h.getPromise();

    h.setter(thing);
    assert.strictEqual(await promise, thing);
    assert.strictEqual(await h.getPromise(), thing);
  });

  describe('.on()', function() {
    it('returns an existing RefHolder as-is', function() {
      const original = new RefHolder();
      const wrapped = RefHolder.on(original);
      assert.strictEqual(original, wrapped);
    });

    it('wraps a non-RefHolder value with a RefHolder set to it', function() {
      const wrapped = RefHolder.on(9000);
      assert.isFalse(wrapped.isEmpty());
      assert.strictEqual(wrapped.get(), 9000);
    });
  });
});
