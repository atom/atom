describe('assert.async', function() {
  it('allows for asynchronous assertions', async function() {
    let val = false;
    setTimeout(() => { val = true; });
    await assert.async.isTrue(val);
  });

  it('allows for setting the timeout', async function() {
    let val = false;
    setTimeout(() => { val = true; }, 100);
    let caught = false;
    try {
      await assert.async(50).isTrue(val);
    } catch (err) {
      caught = true;
    }

    assert.isTrue(caught);
  });

  it('retains the assertion message and adds the timeout', async function() {
    let val = false;
    setTimeout(() => { val = true; }, 100);
    let caught = null;
    try {
      await assert.async(50).isTrue(val);
    } catch (err) {
      caught = err;
    }

    assert.match(caught.message, /^async\(50ms\):/);
    assert.match(caught.message, /assert\.isTrue\(val\)/);
    assert.match(caught.message, /false.*true/);
  });

  it('includes the assert line in the exception, even for non-async assertions', function() {
    let caught = null;
    try {
      assert.equal(1, 2);
    } catch (err) {
      caught = err;
    }

    assert.match(caught.message, /assert\.equal\(1, 2\)/);
  });
});
