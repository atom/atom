import React from 'react';
import {QueryRenderer} from 'react-relay';
import {shallow} from 'enzyme';

import CreateDialogContainer from '../../lib/containers/create-dialog-container';
import CreateDialogController from '../../lib/controllers/create-dialog-controller';
import {dialogRequests} from '../../lib/controllers/dialogs-controller';
import {InMemoryStrategy} from '../../lib/shared/keytar-strategy';
import GithubLoginModel from '../../lib/models/github-login-model';
import {getEndpoint} from '../../lib/models/endpoint';
import {queryBuilder} from '../builder/graphql/query';

import query from '../../lib/containers/__generated__/createDialogContainerQuery.graphql';

const DOTCOM = getEndpoint('github.com');

describe('CreateDialogContainer', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    return (
      <CreateDialogContainer
        loginModel={new GithubLoginModel(InMemoryStrategy)}
        request={dialogRequests.create()}
        inProgress={false}
        currentWindow={atomEnv.getCurrentWindow()}
        workspace={atomEnv.workspace}
        commands={atomEnv.commands}
        config={atomEnv.config}
        {...override}
      />
    );
  }

  it('renders nothing before the token is provided', function() {
    const loginModel = new GithubLoginModel(InMemoryStrategy);
    loginModel.setToken('https://api.github.com', 'good-token');

    const wrapper = shallow(buildApp({loginModel}));
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')(null);

    assert.isTrue(tokenWrapper.isEmptyRender());
  });

  it('fetches the login token from the login model', async function() {
    const loginModel = new GithubLoginModel(InMemoryStrategy);
    loginModel.setToken(DOTCOM.getLoginAccount(), 'good-token');

    const wrapper = shallow(buildApp({loginModel}));
    const observer = wrapper.find('ObserveModel');
    assert.strictEqual(observer.prop('model'), loginModel);
    assert.strictEqual(await observer.prop('fetchData')(loginModel), 'good-token');
  });

  it('renders the dialog controller in a loading state before the GraphQL query completes', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('good-token');
    const queryWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({error: null, props: null});

    assert.isNull(queryWrapper.find(CreateDialogController).prop('user'));
    assert.isTrue(queryWrapper.find(CreateDialogController).prop('isLoading'));
  });

  it('passes GraphQL errors to the dialog controller', function() {
    const error = new Error('AAHHHHHHH');

    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('good-token');
    const queryWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({error, props: null});

    assert.isNull(queryWrapper.find(CreateDialogController).prop('user'));
    assert.strictEqual(queryWrapper.find(CreateDialogController).prop('error'), error);
  });

  it('passes GraphQL query results to the dialog controller', function() {
    const props = queryBuilder(query).build();

    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('good-token');
    const queryWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({error: null, props});

    assert.strictEqual(queryWrapper.find(CreateDialogController).prop('user'), props.viewer);
  });
});
