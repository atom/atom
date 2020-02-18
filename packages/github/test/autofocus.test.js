import AutoFocus from '../lib/autofocus';

describe('AutoFocus', function() {
  let clock;

  beforeEach(function() {
    clock = sinon.useFakeTimers();
  });

  afterEach(function() {
    clock.restore();
  });

  it('captures an element and focuses it on trigger', function() {
    const element = new MockElement();
    const autofocus = new AutoFocus();

    autofocus.target(element);
    autofocus.trigger();
    clock.next();

    assert.isTrue(element.wasFocused());
  });

  it('captures multiple elements by index and focuses the first on trigger', function() {
    const element0 = new MockElement();
    const element1 = new MockElement();
    const element2 = new MockElement();

    const autofocus = new AutoFocus();
    autofocus.firstTarget(0)(element0);
    autofocus.firstTarget(1)(element1);
    autofocus.firstTarget(2)(element2);

    autofocus.trigger();
    clock.next();

    assert.isTrue(element0.wasFocused());
    assert.isFalse(element1.wasFocused());
    assert.isFalse(element2.wasFocused());
  });

  it('does nothing on trigger when nothing is captured', function() {
    const autofocus = new AutoFocus();
    autofocus.trigger();
  });
});

class MockElement {
  constructor() {
    this.focused = false;
  }

  focus() {
    this.focused = true;
  }

  wasFocused() {
    return this.focused;
  }
}
