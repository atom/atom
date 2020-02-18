import React from 'react';
import {shallow} from 'enzyme';
import {QueryRenderer} from 'react-relay';

import RemoteContainer from '../../lib/containers/remote-container';
import * as reporterProxy from '../../lib/reporter-proxy';
import {queryBuilder} from '../builder/graphql/query';
import Remote from '../../lib/models/remote';
import RemoteSet from '../../lib/models/remote-set';
import Branch, {nullBranch} from '../../lib/models/branch';
import BranchSet from '../../lib/models/branch-set';
import GithubLoginModel from '../../lib/models/github-login-model';
import {getEndpoint} from '../../lib/models/endpoint';
import Refresher from '../../lib/models/refresher';
import {InMemoryStrategy, INSUFFICIENT, UNAUTHENTICATED} from '../../lib/shared/keytar-strategy';

import remoteQuery from '../../lib/containers/__generated__/remoteContainerQuery.graphql';

describe('RemoteContainer', function() {
  let atomEnv, model;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    model = new GithubLoginModel(InMemoryStrategy);
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrideProps = {}) {
    const origin = new Remote('origin', 'git@github.com:atom/github.git');
    const remotes = new RemoteSet([origin]);
    const branch = new Branch('master', nullBranch, nullBranch, true);
    const branches = new BranchSet([branch]);

    return (
      <RemoteContainer
        loginModel={model}
        endpoint={getEndpoint('github.com')}

        refresher={new Refresher()}
        workingDirectory={__dirname}
        notifications={atomEnv.notifications}
        workspace={atomEnv.workspace}
        remote={origin}
        remotes={remotes}
        branches={branches}

        aheadCount={0}
        pushInProgress={false}

        onPushBranch={() => {}}

        {...overrideProps}
      />
    );
  }

  it('renders a loading spinner while the token is being fetched', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')(null);
    assert.isTrue(tokenWrapper.exists('LoadingView'));
  });

  it('renders a loading spinner while the GraphQL query is being performed', async function() {
    model.setToken('https://api.github.com', '1234');

    sinon.spy(model, 'getToken');
    sinon.stub(model, 'getScopes').resolves(GithubLoginModel.REQUIRED_SCOPES);

    const wrapper = shallow(buildApp());

    assert.strictEqual(await wrapper.find('ObserveModel').prop('fetchData')(model), '1234');
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('1234');

    const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({
      error: null,
      props: null,
      retry: () => {},
    });

    assert.isTrue(resultWrapper.exists('LoadingView'));
  });

  it('renders a login prompt if no token is found', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')(UNAUTHENTICATED);
    assert.isTrue(tokenWrapper.exists('GithubLoginView'));
  });

  it('renders a login prompt if the token has insufficient OAuth scopes', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')(INSUFFICIENT);

    assert.match(tokenWrapper.find('GithubLoginView').find('p').text(), /sufficient/);
  });

  it('renders an offline view if the user is offline', function() {
    sinon.spy(model, 'didUpdate');

    const wrapper = shallow(buildApp());
    const e = new Error('oh no');
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')(e);
    assert.isTrue(tokenWrapper.exists('QueryErrorView'));

    tokenWrapper.find('QueryErrorView').prop('retry')();
    assert.isTrue(model.didUpdate.called);
  });

  it('renders an error message if the GraphQL query fails', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('1234');

    const error = new Error('oh shit!');
    error.rawStack = error.stack;
    const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({error, props: null, retry: () => {}});

    assert.strictEqual(resultWrapper.find('QueryErrorView').prop('error'), error);
  });

  it('increments a counter on login', function() {
    const incrementCounterStub = sinon.stub(reporterProxy, 'incrementCounter');

    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')(UNAUTHENTICATED);

    tokenWrapper.find('GithubLoginView').prop('onLogin')();
    assert.isTrue(incrementCounterStub.calledOnceWith('github-login'));
  });

  it('increments a counter on logout', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('1234');

    const error = new Error('just show the logout button');
    error.rawStack = error.stack;
    const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({error, props: null, retry: () => {}});

    const incrementCounterStub = sinon.stub(reporterProxy, 'incrementCounter');
    resultWrapper.find('QueryErrorView').prop('logout')();
    assert.isTrue(incrementCounterStub.calledOnceWith('github-logout'));
  });

  it('renders the controller once results have arrived', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('1234');

    const props = queryBuilder(remoteQuery)
      .repository(r => {
        r.id('the-repo');
        r.defaultBranchRef(dbr => {
          dbr.prefix('refs/heads/');
          dbr.name('devel');
        });
      })
      .build();
    const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({error: null, props, retry: () => {}});

    const controller = resultWrapper.find('RemoteController');
    assert.strictEqual(controller.prop('token'), '1234');
    assert.deepEqual(controller.prop('repository'), {
      id: 'the-repo',
      defaultBranchRef: {
        prefix: 'refs/heads/',
        name: 'devel',
      },
    });
  });
});
