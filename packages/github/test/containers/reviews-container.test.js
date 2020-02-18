import React from 'react';
import {shallow} from 'enzyme';
import {QueryRenderer} from 'react-relay';

import ReviewsContainer from '../../lib/containers/reviews-container';
import AggregatedReviewsContainer from '../../lib/containers/aggregated-reviews-container';
import CommentPositioningContainer from '../../lib/containers/comment-positioning-container';
import ReviewsController from '../../lib/controllers/reviews-controller';
import {InMemoryStrategy, UNAUTHENTICATED, INSUFFICIENT} from '../../lib/shared/keytar-strategy';
import GithubLoginModel from '../../lib/models/github-login-model';
import WorkdirContextPool from '../../lib/models/workdir-context-pool';
import {getEndpoint} from '../../lib/models/endpoint';
import {multiFilePatchBuilder} from '../builder/patch';
import {cloneRepository} from '../helpers';

describe('ReviewsContainer', function() {
  let atomEnv, workdirContextPool, repository, loginModel, repoData, queryData;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();

    workdirContextPool = new WorkdirContextPool();

    const workdir = await cloneRepository();
    repository = workdirContextPool.add(workdir).getRepository();
    await repository.getLoadPromise();
    loginModel = new GithubLoginModel(InMemoryStrategy);
    sinon.stub(loginModel, 'getScopes').resolves(GithubLoginModel.REQUIRED_SCOPES);

    repoData = {
      branches: await repository.getBranches(),
      remotes: await repository.getRemotes(),
      isAbsent: repository.isAbsent(),
      isLoading: repository.isLoading(),
      isPresent: repository.isPresent(),
      isMerging: await repository.isMerging(),
      isRebasing: await repository.isRebasing(),
    };

    queryData = {
      repository: {
        pullRequest: {
          headRefOid: '0000000000000000000000000000000000000000',
        },
      },
    };
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    const props = {
      endpoint: getEndpoint('github.com'),

      owner: 'atom',
      repo: 'github',
      number: 1234,
      workdir: repository.getWorkingDirectoryPath(),

      repository,
      loginModel,
      workdirContextPool,

      workspace: atomEnv.workspace,
      config: atomEnv.config,
      commands: atomEnv.commands,
      tooltips: atomEnv.tooltips,
      confirm: () => {},

      reportRelayError: () => {},

      ...override,
    };

    return <ReviewsContainer {...props} />;
  }

  it('renders a loading spinner while the token is loading', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')(null);
    assert.isTrue(tokenWrapper.exists('LoadingView'));
  });

  it('shows a login form if no token is available', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')(UNAUTHENTICATED);
    assert.isTrue(tokenWrapper.exists('GithubLoginView'));
  });

  it('shows a login form if the token is outdated', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')(INSUFFICIENT);

    assert.isTrue(tokenWrapper.exists('GithubLoginView'));
    assert.match(tokenWrapper.find('GithubLoginView > p').text(), /re-authenticate/);
  });

  it('shows a message if the network is unavailable', function() {
    sinon.spy(loginModel, 'didUpdate');

    const wrapper = shallow(buildApp());
    const e = new Error('er');
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')(e);

    assert.isTrue(tokenWrapper.exists('QueryErrorView'));
    tokenWrapper.find('QueryErrorView').prop('retry')();
    assert.isTrue(loginModel.didUpdate.called);
  });

  it('gets the token from the login model', async function() {
    await loginModel.setToken('https://github.enterprise.horse', 'neigh');

    const wrapper = shallow(buildApp({
      loginModel,
      endpoint: getEndpoint('github.enterprise.horse'),
    }));

    assert.strictEqual(wrapper.find('ObserveModel').prop('model'), loginModel);
    assert.strictEqual(await wrapper.find('ObserveModel').prop('fetchData')(loginModel), 'neigh');
  });

  it('shows a loading spinner if the patch is being fetched', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('shhh');
    const patchWrapper = tokenWrapper.find('PullRequestPatchContainer').renderProp('children')(null, null);
    const repoWrapper = patchWrapper.find('ObserveModel').renderProp('children')(repoData);
    const resultWrapper = repoWrapper.find(QueryRenderer).renderProp('render')({error: null, props: queryData, retry: () => {}});

    assert.isTrue(resultWrapper.exists('LoadingView'));
  });

  it('shows a loading spinner if the repository data is being fetched', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('shhh');
    const patchWrapper = tokenWrapper.find('PullRequestPatchContainer').renderProp('children')(null, {});
    const repoWrapper = patchWrapper.find('ObserveModel').renderProp('children')(null);
    const resultWrapper = repoWrapper.find(QueryRenderer).renderProp('render')({error: null, props: queryData, retry: () => {}});

    assert.isTrue(resultWrapper.exists('LoadingView'));
  });

  it('shows a loading spinner if the GraphQL query is still being performed', function() {
    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('shhh');
    const patchWrapper = tokenWrapper.find('PullRequestPatchContainer').renderProp('children')(null, {});
    const repoWrapper = patchWrapper.find('ObserveModel').renderProp('children')(repoData);
    const resultWrapper = repoWrapper.find(QueryRenderer).renderProp('render')({error: null, props: null, retry: () => {}});

    assert.isTrue(resultWrapper.exists('LoadingView'));
  });

  it('shows an error view if the review comment aggregation fails', function() {
    const {multiFilePatch} = multiFilePatchBuilder().build();

    const wrapper = shallow(buildApp());
    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('shhh');
    const patchWrapper = tokenWrapper.find('PullRequestPatchContainer').renderProp('children')(null, multiFilePatch);

    const repoWrapper = patchWrapper.find('ObserveModel').renderProp('children')(repoData);
    const relayWrapper = repoWrapper.find(QueryRenderer).renderProp('render')({
      error: null,
      props: queryData,
      retry: () => {},
    });

    const e0 = new Error('oh shit');
    const e1 = new Error('not again');
    const reviewsWrapper = relayWrapper.find(AggregatedReviewsContainer).renderProp('children')({
      errors: [e0, e1],
      summaries: [],
      commentThreads: [],
      refetch: () => {},
    });

    assert.deepEqual(reviewsWrapper.find('ErrorView').map(w => w.prop('descriptions')), [[e0.stack], [e1.stack]]);
  });

  it('passes the patch to the controller', function() {
    const wrapper = shallow(buildApp({
      owner: 'secret',
      repo: 'squirrel',
      number: 123,
      endpoint: getEndpoint('github.enterprise.com'),
    }));

    const {multiFilePatch} = multiFilePatchBuilder().build();

    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('shhh');

    assert.strictEqual(tokenWrapper.find('PullRequestPatchContainer').prop('owner'), 'secret');
    assert.strictEqual(tokenWrapper.find('PullRequestPatchContainer').prop('repo'), 'squirrel');
    assert.strictEqual(tokenWrapper.find('PullRequestPatchContainer').prop('number'), 123);
    assert.strictEqual(tokenWrapper.find('PullRequestPatchContainer').prop('endpoint').getHost(), 'github.enterprise.com');
    assert.strictEqual(tokenWrapper.find('PullRequestPatchContainer').prop('token'), 'shhh');
    const patchWrapper = tokenWrapper.find('PullRequestPatchContainer').renderProp('children')(null, multiFilePatch);

    const repoWrapper = patchWrapper.find('ObserveModel').renderProp('children')(repoData);
    const relayWrapper = repoWrapper.find(QueryRenderer).renderProp('render')({error: null, props: queryData, retry: () => {}});
    const reviewsWrapper = relayWrapper.find(AggregatedReviewsContainer).renderProp('children')({
      errors: [],
      summaries: [],
      commentThreads: [],
      refetch: () => {},
    });
    const positionedWrapper = reviewsWrapper.find(CommentPositioningContainer).renderProp('children')(new Map());

    assert.strictEqual(positionedWrapper.find(ReviewsController).prop('multiFilePatch'), multiFilePatch);
  });

  it('passes loaded repository data to the controller', async function() {
    const wrapper = shallow(buildApp());

    const extraRepoData = {...repoData, one: Symbol('one'), two: Symbol('two')};

    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('shhh');
    const patchWrapper = tokenWrapper.find('PullRequestPatchContainer').renderProp('children')(null, {});

    assert.strictEqual(patchWrapper.find('ObserveModel').prop('model'), repository);
    assert.deepEqual(await patchWrapper.find('ObserveModel').prop('fetchData')(repository), repoData);
    const repoWrapper = patchWrapper.find('ObserveModel').renderProp('children')(extraRepoData);

    const relayWrapper = repoWrapper.find(QueryRenderer).renderProp('render')({error: null, props: queryData, retry: () => {}});
    const reviewsWrapper = relayWrapper.find(AggregatedReviewsContainer).renderProp('children')({
      errors: [],
      summaries: [],
      commentThreads: [],
      refetch: () => {},
    });
    const positionedWrapper = reviewsWrapper.find(CommentPositioningContainer).renderProp('children')(new Map());

    assert.strictEqual(positionedWrapper.find(ReviewsController).prop('one'), extraRepoData.one);
    assert.strictEqual(positionedWrapper.find(ReviewsController).prop('two'), extraRepoData.two);
  });

  it('passes extra properties to the controller', function() {
    const extra = Symbol('extra');
    const wrapper = shallow(buildApp({extra}));

    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('shhh');
    const patchWrapper = tokenWrapper.find('PullRequestPatchContainer').renderProp('children')(null, {});

    assert.strictEqual(patchWrapper.find('ObserveModel').prop('model'), repository);
    const repoWrapper = patchWrapper.find('ObserveModel').renderProp('children')(repoData);

    const relayWrapper = repoWrapper.find(QueryRenderer).renderProp('render')({error: null, props: queryData, retry: () => {}});
    const reviewsWrapper = relayWrapper.find(AggregatedReviewsContainer).renderProp('children')({
      errors: [],
      summaries: [],
      commentThreads: [],
      refetch: () => {},
    });
    const positionedWrapper = reviewsWrapper.find(CommentPositioningContainer).renderProp('children')(new Map());

    assert.strictEqual(positionedWrapper.find(ReviewsController).prop('extra'), extra);
  });

  it('shows an error if the patch cannot be fetched', function() {
    const wrapper = shallow(buildApp());

    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('shhh');
    const patchWrapper = tokenWrapper.find('PullRequestPatchContainer').renderProp('children')('[errors intensify]', null);
    assert.deepEqual(patchWrapper.find('ErrorView').prop('descriptions'), ['[errors intensify]']);
  });

  it('shows an error if the GraphQL query fails', async function() {
    const wrapper = shallow(buildApp({
      endpoint: getEndpoint('github.enterprise.horse'),
    }));

    const err = new Error("just didn't feel like it");
    const retry = sinon.spy();

    const tokenWrapper = wrapper.find('ObserveModel').renderProp('children')('shhh');
    const patchWrapper = tokenWrapper.find('PullRequestPatchContainer').renderProp('children')(null, {});
    const repoWrapper = patchWrapper.find('ObserveModel').renderProp('children')(repoData);
    const resultWrapper = repoWrapper.find(QueryRenderer).renderProp('render')({error: err, props: null, retry});

    assert.strictEqual(resultWrapper.find('QueryErrorView').prop('error'), err);

    await resultWrapper.find('QueryErrorView').prop('login')('different');
    assert.strictEqual(await loginModel.getToken('https://github.enterprise.horse'), 'different');

    await resultWrapper.find('QueryErrorView').prop('logout')();
    assert.strictEqual(await loginModel.getToken('https://github.enterprise.horse'), UNAUTHENTICATED);

    resultWrapper.find('QueryErrorView').prop('retry')();
    assert.isTrue(retry.called);
  });
});
