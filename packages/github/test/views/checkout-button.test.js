import React from 'react';
import {shallow} from 'enzyme';
import EnableableOperation from '../../lib/models/enableable-operation';
import {checkoutStates} from '../../lib/controllers/pr-checkout-controller';
import CheckoutButton from '../../lib/views/checkout-button';

describe('Checkout button', function() {

  function buildApp(overrideProps = {}) {
    return (
      <CheckoutButton
        checkoutOp={new EnableableOperation(() => {}).disable(checkoutStates.CURRENT)}
        classNamePrefix=""
        {...overrideProps}
      />
    );
  }

  it('renders checkout button with proper class names', function() {
    const button = shallow(buildApp({
      classNames: ['not', 'necessary'],
      classNamePrefix: 'prefix--',
    })).find('.checkoutButton');
    assert.isTrue(button.hasClass('prefix--current'));
    assert.isTrue(button.hasClass('not'));
    assert.isTrue(button.hasClass('necessary'));
  });

  it('triggers its operation callback on click', function() {
    const cb = sinon.spy();
    const checkoutOp = new EnableableOperation(cb);
    const wrapper = shallow(buildApp({checkoutOp}));

    const button = wrapper.find('.checkoutButton');
    assert.strictEqual(button.text(), 'Checkout');
    button.simulate('click');
    assert.isTrue(cb.called);
  });

  it('renders as disabled with hover text set to the disablement message', function() {
    const checkoutOp = new EnableableOperation(() => {}).disable(checkoutStates.DISABLED, 'message');
    const wrapper = shallow(buildApp({checkoutOp}));

    const button = wrapper.find('.checkoutButton');
    assert.isTrue(button.prop('disabled'));
    assert.strictEqual(button.text(), 'Checkout');
    assert.strictEqual(button.prop('title'), 'message');
  });

  it('changes the button text when disabled because the PR is the current branch', function() {
    const checkoutOp = new EnableableOperation(() => {}).disable(checkoutStates.CURRENT, 'message');
    const wrapper = shallow(buildApp({checkoutOp}));

    const button = wrapper.find('.checkoutButton');
    assert.isTrue(button.prop('disabled'));
    assert.strictEqual(button.text(), 'Checked out');
    assert.strictEqual(button.prop('title'), 'message');
  });

  it('renders hidden', function() {
    const checkoutOp = new EnableableOperation(() => {}).disable(checkoutStates.HIDDEN, 'message');
    const wrapper = shallow(buildApp({checkoutOp}));

    assert.isFalse(wrapper.find('.checkoutButton').exists());
  });
});
