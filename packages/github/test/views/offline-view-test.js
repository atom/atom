import React from 'react';
import {shallow} from 'enzyme';

import OfflineView from '../../lib/views/offline-view';

describe('OfflineView', function() {
  let listeners;

  beforeEach(function() {
    listeners = {};

    sinon.stub(window, 'addEventListener').callsFake((eventName, callback) => {
      listeners[eventName] = callback;
    });
    sinon.stub(window, 'removeEventListener').callsFake((eventName, callback) => {
      if (listeners[eventName] === callback) {
        delete listeners[eventName];
      } else {
        throw new Error('Wrong callback');
      }
    });
  });

  it('triggers a retry callback when the retry button is clicked', function() {
    const retry = sinon.spy();
    const wrapper = shallow(<OfflineView retry={retry} />);

    wrapper.find('.btn').simulate('click');
    assert.isTrue(retry.called);
  });

  it('triggers a retry callback when the network status changes', function() {
    const retry = sinon.spy();
    shallow(<OfflineView retry={retry} />);

    listeners.online();
    assert.strictEqual(retry.callCount, 1);
  });

  it('unregisters the network status listener on unmount', function() {
    const wrapper = shallow(<OfflineView retry={() => {}} />);
    assert.isDefined(listeners.online);
    wrapper.unmount();
    assert.isUndefined(listeners.online);
  });
});
