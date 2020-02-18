import React from 'react';
import {shallow} from 'enzyme';

import QueryErrorView from '../../lib/views/query-error-view';

describe('QueryErrorView', function() {
  function buildApp(overrideProps = {}) {
    return (
      <QueryErrorView
        error={new Error('wat')}
        login={() => {}}
        openDevTools={() => {}}
        {...overrideProps}
      />
    );
  }

  it('renders a GithubLoginView for a 401', function() {
    const error = new Error('Unauthorized');
    error.response = {status: 401, text: () => ''};
    error.rawStack = error.stack;
    const login = sinon.stub();

    const wrapper = shallow(buildApp({error, login}));
    assert.isTrue(wrapper.find('GithubLoginView').exists());
    assert.strictEqual(wrapper.find('GithubLoginView').prop('onLogin'), login);
  });

  it('renders GraphQL error messages', function() {
    const error = new Error('GraphQL error');
    error.response = {status: 200, text: () => ''};
    error.errors = [
      {message: 'first error'},
      {message: 'second error'},
    ];
    error.rawStack = error.stack;

    const wrapper = shallow(buildApp({error}));
    assert.isTrue(wrapper.find('ErrorView').someWhere(n => {
      const ds = n.prop('descriptions');
      return ds.includes('first error') && ds.includes('second error');
    }));
  });

  it('recognizes network errors', function() {
    const error = new Error('network error');
    error.network = true;
    error.rawStack = error.stack;
    const retry = sinon.spy();

    const wrapper = shallow(buildApp({error, retry}));
    const ev = wrapper.find('OfflineView');
    ev.prop('retry')();
    assert.isTrue(retry.called);
  });

  it('renders the error response directly for an unrecognized error status', function() {
    const error = new Error('GraphQL error');
    error.response = {
      status: 500,
    };
    error.responseText = 'response text';
    error.rawStack = error.stack;

    const wrapper = shallow(buildApp({error}));

    assert.isTrue(wrapper.find('ErrorView').someWhere(n => {
      return n.prop('descriptions').includes('response text') && n.prop('preformatted');
    }));
  });

  it('falls back to rendering the message and stack', function() {
    const error = new Error('the message');
    error.rawStack = error.stack;

    const wrapper = shallow(buildApp({error}));
    const ev = wrapper.find('ErrorView');
    assert.strictEqual(ev.prop('title'), 'the message');
    assert.deepEqual(ev.prop('descriptions'), [error.stack]);
    assert.isTrue(ev.prop('preformatted'));
  });
});
