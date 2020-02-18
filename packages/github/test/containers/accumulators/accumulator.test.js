import React from 'react';
import {shallow} from 'enzyme';
import {Disposable} from 'event-kit';

import Accumulator from '../../../lib/containers/accumulators/accumulator';

describe('Accumulator', function() {
  function buildApp(override = {}) {
    const props = {
      resultBatch: [],
      pageSize: 10,
      waitTimeMs: 0,
      onDidRefetch: () => new Disposable(),
      children: () => {},
      ...override,
      relay: {
        hasMore: () => false,
        loadMore: (_pageSize, cb) => {
          cb(null);
          return new Disposable();
        },
        isLoading: () => false,
        ...(override.relay || {}),
      },
    };

    return <Accumulator {...props} />;
  }

  it('accepts an already-loaded single page of results', function() {
    const fn = sinon.spy();
    shallow(buildApp({
      relay: {
        hasMore: () => false,
        isLoading: () => false,
      },
      resultBatch: [1, 2, 3],
      children: fn,
    }));

    assert.isTrue(fn.calledWith(null, [1, 2, 3], false));
  });

  it('continues to paginate and accumulate results', function() {
    const fn = sinon.spy();
    let hasMore = true;
    let loadMoreCallback = null;

    const relay = {
      hasMore: () => hasMore,
      loadMore: (pageSize, callback) => {
        assert.strictEqual(pageSize, 10);
        loadMoreCallback = () => {
          loadMoreCallback = null;
          callback(null);
        };
        return new Disposable();
      },
      isLoading: () => false,
    };

    const wrapper = shallow(buildApp({relay, resultBatch: [1, 2, 3], children: fn}));
    assert.isTrue(fn.calledWith(null, [1, 2, 3], true));

    wrapper.setProps({resultBatch: [1, 2, 3, 4, 5, 6]});
    loadMoreCallback();
    assert.isTrue(fn.calledWith(null, [1, 2, 3, 4, 5, 6], true));

    hasMore = false;
    wrapper.setProps({resultBatch: [1, 2, 3, 4, 5, 6, 7, 8, 9]});
    loadMoreCallback();
    assert.isTrue(fn.calledWith(null, [1, 2, 3, 4, 5, 6, 7, 8, 9], false));
    assert.isNull(loadMoreCallback);
  });

  it('reports an error to its render prop', function() {
    const fn = sinon.spy();
    const error = Symbol('the error');

    const relay = {
      hasMore: () => true,
      loadMore: (pageSize, callback) => {
        assert.strictEqual(pageSize, 10);
        callback(error);
        return new Disposable();
      },
    };

    shallow(buildApp({relay, children: fn}));
    assert.isTrue(fn.calledWith(error, [], true));
  });

  it('terminates a loadMore call when unmounting', function() {
    const disposable = {dispose: sinon.spy()};
    const relay = {
      hasMore: () => true,
      loadMore: sinon.stub().returns(disposable),
      isLoading: () => false,
    };

    const wrapper = shallow(buildApp({relay}));
    assert.isTrue(relay.loadMore.called);

    wrapper.unmount();
    assert.isTrue(disposable.dispose.called);
  });

  it('cancels a delayed accumulate call when unmounting', function() {
    const setTimeoutStub = sinon.stub(window, 'setTimeout').returns(123);
    const clearTimeoutStub = sinon.stub(window, 'clearTimeout');

    const relay = {
      hasMore: () => true,
    };

    const wrapper = shallow(buildApp({relay, waitTimeMs: 1000}));
    assert.isTrue(setTimeoutStub.called);

    wrapper.unmount();
    assert.isTrue(clearTimeoutStub.calledWith(123));
  });
});
