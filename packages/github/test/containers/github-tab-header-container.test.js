import React from 'react';
import {shallow} from 'enzyme';
import {QueryRenderer} from 'react-relay';

import GithubTabHeaderContainer from '../../lib/containers/github-tab-header-container';
import {queryBuilder} from '../builder/graphql/query';
import GithubLoginModel from '../../lib/models/github-login-model';
import {getEndpoint} from '../../lib/models/endpoint';
import {InMemoryStrategy, INSUFFICIENT, UNAUTHENTICATED} from '../../lib/shared/keytar-strategy';

import tabHeaderQuery from '../../lib/containers/__generated__/githubTabHeaderContainerQuery.graphql';

describe('GithubTabHeaderContainer', function() {
  let atomEnv, model;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    model = new GithubLoginModel(InMemoryStrategy);
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrideProps = {}) {
    return (
      <GithubTabHeaderContainer
        loginModel={model}
        endpoint={getEndpoint('github.com')}
        currentWorkDir={null}
        contextLocked={false}
        changeWorkingDirectory={() => {}}
        setContextLock={() => {}}
        getCurrentWorkDirs={() => new Set()}
        onDidChangeWorkDirs={() => {}}
        {...overrideProps}
      />
    );
  }

  it('renders a null user while the GraphQL query is being performed', async function() {
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

    assert.isFalse(resultWrapper.find('GithubTabHeaderController').prop('user').isPresent());
  });

  it('renders a null user if no token is found', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')(UNAUTHENTICATED);
    assert.isFalse(tokenWrapper.find('GithubTabHeaderController').prop('user').isPresent());
  });

  it('renders a null user if the token has insufficient OAuth scopes', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')(INSUFFICIENT);

    assert.isFalse(tokenWrapper.find('GithubTabHeaderController').prop('user').isPresent());
  });

  it('renders a null user if the user is offline', function() {
    sinon.spy(model, 'didUpdate');

    const wrapper = shallow(buildApp());
    const e = new Error('oh no');
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')(e);
    assert.isFalse(tokenWrapper.find('GithubTabHeaderController').prop('user').isPresent());
  });

  it('renders the controller once results have arrived', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('1234');

    const props = queryBuilder(tabHeaderQuery)
      .viewer(v => {
        v.name('user');
        v.email('us3r@email.com');
        v.avatarUrl('https://imageurl.com/test.jpg');
        v.login('us3rh4nd13');
      })
      .build();
    const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({error: null, props, retry: () => {}});

    const controller = resultWrapper.find('GithubTabHeaderController');
    assert.isTrue(controller.prop('user').isPresent());
    assert.strictEqual(controller.prop('user').getEmail(), 'us3r@email.com');
  });
});
