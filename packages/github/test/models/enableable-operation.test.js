import EnableableOperation from '../../lib/models/enableable-operation';

class ComponentLike {
  constructor() {
    this.state = {inProgress: false};
    this.beforeRenderPromise = null;
  }

  simulateAsyncRender() {
    this.beforeRenderPromise = new Promise(resolve => {
      this.resolveBeforeRenderPromise = resolve;
    });
  }

  async setState(changeCb, afterCb) {
    // Simulate an asynchronous render.
    if (this.beforeRenderPromise) {
      await this.beforeRenderPromise;
    }
    const after = changeCb(this.state);
    this.state.inProgress = after.inProgress !== undefined ? after.inProgress : this.state.inProgress;
    if (afterCb) { afterCb(); }
  }
}

describe('EnableableOperation', function() {
  let callback, op;
  const REASON = Symbol('reason');

  beforeEach(function() {
    callback = sinon.stub();
    op = new EnableableOperation(callback);
  });

  it('defaults to being enabled', async function() {
    callback.resolves(123);

    assert.isTrue(op.isEnabled());
    assert.strictEqual(await op.run(), 123);
  });

  it('may be disabled with a message', async function() {
    const disabled = op.disable(REASON, "I don't want to");
    assert.notStrictEqual(disabled, op);
    assert.isFalse(disabled.isEnabled());
    assert.strictEqual(disabled.why(), REASON);
    assert.strictEqual(disabled.getMessage(), "I don't want to");
    await assert.isRejected(disabled.run(), /I don't want to/);
  });

  it('may be disabled with a different message', function() {
    const disabled0 = op.disable(REASON, 'one');
    assert.notStrictEqual(disabled0, op);
    assert.strictEqual(disabled0.why(), REASON);
    assert.strictEqual(disabled0.getMessage(), 'one');

    const disabled1 = disabled0.disable(REASON, 'two');
    assert.notStrictEqual(disabled1, disabled0);
    assert.strictEqual(disabled1.why(), REASON);
    assert.strictEqual(disabled1.getMessage(), 'two');
  });

  it('provides a default disablement message if omitted', async function() {
    const disabled = op.disable();
    assert.notStrictEqual(disabled, op);
    assert.isFalse(disabled.isEnabled());
    assert.strictEqual(disabled.getMessage(), 'disabled');
    await assert.isRejected(disabled.run(), /disabled/);
  });

  it('may be re-enabled', async function() {
    callback.resolves(123);

    const reenabled = op.disable().enable();
    assert.notStrictEqual(reenabled, op);
    assert.isTrue(op.isEnabled());
    assert.strictEqual(await op.run(), 123);
  });

  it('returns itself when transitioning to the same state', function() {
    assert.strictEqual(op, op.enable());
    const disabled = op.disable();
    assert.strictEqual(disabled, disabled.disable());
  });

  it('can be wired to toggle component state before and after its action', async function() {
    const component = new ComponentLike();
    op.toggleState(component, 'inProgress');

    assert.isFalse(component.state.inProgress);
    const promise = op.run();
    assert.isTrue(component.state.inProgress);
    await promise;
    assert.isFalse(component.state.inProgress);
  });

  it('restores the progress tracking state even if the operation fails', async function() {
    const component = new ComponentLike();
    op.toggleState(component, 'inProgress');
    callback.rejects(new Error('boom'));

    assert.isFalse(component.state.inProgress);
    const promise = op.run();
    assert.isTrue(component.state.inProgress);
    await assert.isRejected(promise, /boom/);
    assert.isFalse(component.state.inProgress);
  });

  it('does not toggle state if the state has been redundantly toggled', async function() {
    let resolveCbPromise = () => {};
    const cbPromise = new Promise(resolve => {
      resolveCbPromise = resolve;
    });
    callback.returns(resolveCbPromise);

    const component = new ComponentLike();
    component.simulateAsyncRender();
    op.toggleState(component, 'inProgress');

    assert.isFalse(component.state.inProgress);
    const opPromise = op.run();

    assert.isFalse(component.state.inProgress);
    component.state.inProgress = true;

    component.resolveBeforeRenderPromise();
    await component.beforeRenderPromise;

    assert.isTrue(component.state.inProgress);

    component.state.inProgress = false;

    resolveCbPromise();
    await Promise.all([cbPromise, opPromise]);
    assert.isFalse(component.state.inProgress);
  });
});
