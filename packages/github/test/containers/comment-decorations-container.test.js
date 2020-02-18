import React from 'react';
import {shallow} from 'enzyme';
import {QueryRenderer} from 'react-relay';

import {cloneRepository, buildRepository} from '../helpers';
import {queryBuilder} from '../builder/graphql/query';
import {multiFilePatchBuilder} from '../builder/patch';
import Branch, {nullBranch} from '../../lib/models/branch';
import BranchSet from '../../lib/models/branch-set';
import GithubLoginModel from '../../lib/models/github-login-model';
import ObserveModel from '../../lib/views/observe-model';
import Remote from '../../lib/models/remote';
import RemoteSet from '../../lib/models/remote-set';
import {InMemoryStrategy, UNAUTHENTICATED, INSUFFICIENT} from '../../lib/shared/keytar-strategy';
import CommentDecorationsContainer from '../../lib/containers/comment-decorations-container';
import PullRequestPatchContainer from '../../lib/containers/pr-patch-container';
import CommentPositioningContainer from '../../lib/containers/comment-positioning-container';
import AggregatedReviewsContainer from '../../lib/containers/aggregated-reviews-container';
import CommentDecorationsController from '../../lib/controllers/comment-decorations-controller';

import rootQuery from '../../lib/containers/__generated__/commentDecorationsContainerQuery.graphql.js';

describe('CommentDecorationsContainer', function() {
  let atomEnv, workspace, localRepository, loginModel;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    workspace = atomEnv.workspace;
    localRepository = await buildRepository(await cloneRepository());
    loginModel = new GithubLoginModel(InMemoryStrategy);
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrideProps = {}) {
    return (
      <CommentDecorationsContainer
        workspace={workspace}
        localRepository={localRepository}
        loginModel={loginModel}
        reportRelayError={() => {}}
        commands={atomEnv.commands}
        children={() => <div />}
        {...overrideProps}
      />
    );
  }

  it('renders nothing while repository data is being fetched', function() {
    const wrapper = shallow(buildApp());
    const localRepoWrapper = wrapper.find(ObserveModel).renderProp('children')(null);
    assert.isTrue(localRepoWrapper.isEmptyRender());
  });

  it('renders nothing if no GitHub remotes exist', async function() {
    const wrapper = shallow(buildApp());

    const localRepoData = await wrapper.find(ObserveModel).prop('fetchData')(localRepository);
    const localRepoWrapper = wrapper.find(ObserveModel).renderProp('children')(localRepoData);

    const token = await localRepoWrapper.find(ObserveModel).prop('fetchData')(loginModel, localRepoData);
    assert.isNull(token);

    const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')(null);
    assert.isTrue(tokenWrapper.isEmptyRender());
  });

  it('renders nothing if no head branch is present', async function() {
    const wrapper = shallow(buildApp({localRepository, loginModel}));

    const origin = new Remote('origin', 'git@somewhere.com:atom/github.git');

    const repoData = {
      branches: new BranchSet(),
      remotes: new RemoteSet([origin]),
      currentRemote: origin,
      workingDirectoryPath: 'path/path',
    };
    const localRepoWrapper = wrapper.find(ObserveModel).renderProp('children')(repoData);
    const token = await localRepoWrapper.find(ObserveModel).prop('fetchData')(loginModel, repoData);
    assert.isNull(token);

    const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
    assert.isTrue(tokenWrapper.isEmptyRender());
  });

  it('renders nothing if the head branch has no push upstream', function() {
    const wrapper = shallow(buildApp({localRepository, loginModel}));

    const origin = new Remote('origin', 'git@github.com:atom/github.git');
    const upstreamBranch = Branch.createRemoteTracking('refs/remotes/origin/master', 'origin', 'refs/heads/master');
    const branch = new Branch('master', upstreamBranch, nullBranch, true);

    const repoData = {
      branches: new BranchSet([branch]),
      remotes: new RemoteSet([origin]),
      currentRemote: origin,
      workingDirectoryPath: 'path/path',
    };
    const localRepoWrapper = wrapper.find(ObserveModel).renderProp('children')(repoData);
    const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
    assert.isTrue(tokenWrapper.isEmptyRender());
  });

  it('renders nothing if the push remote is invalid', function() {
    const wrapper = shallow(buildApp({localRepository, loginModel}));

    const origin = new Remote('origin', 'git@github.com:atom/github.git');
    const upstreamBranch = Branch.createRemoteTracking('refs/remotes/nope/master', 'nope', 'refs/heads/master');
    const branch = new Branch('master', upstreamBranch, upstreamBranch, true);

    const repoData = {
      branches: new BranchSet([branch]),
      remotes: new RemoteSet([origin]),
      currentRemote: origin,
      workingDirectoryPath: 'path/path',
    };
    const localRepoWrapper = wrapper.find(ObserveModel).renderProp('children')(repoData);
    const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
    assert.isTrue(tokenWrapper.isEmptyRender());
  });

  it('renders nothing if the push remote is not a GitHub remote', function() {
    const wrapper = shallow(buildApp({localRepository, loginModel}));

    const origin = new Remote('origin', 'git@elsewhere.com:atom/github.git');
    const upstreamBranch = Branch.createRemoteTracking('refs/remotes/origin/master', 'origin', 'refs/heads/master');
    const branch = new Branch('master', upstreamBranch, upstreamBranch, true);

    const repoData = {
      branches: new BranchSet([branch]),
      remotes: new RemoteSet([origin]),
      currentRemote: origin,
      workingDirectoryPath: 'path/path',
    };
    const localRepoWrapper = wrapper.find(ObserveModel).renderProp('children')(repoData);
    const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
    assert.isTrue(tokenWrapper.isEmptyRender());
  });

  describe('when GitHub remote exists', function() {
    let localRepo, repoData, wrapper, localRepoWrapper;

    beforeEach(async function() {
      await loginModel.setToken('https://api.github.com', '1234');
      sinon.stub(loginModel, 'getScopes').resolves(GithubLoginModel.REQUIRED_SCOPES);

      localRepo = await buildRepository(await cloneRepository());

      wrapper = shallow(buildApp({localRepository: localRepo, loginModel}));

      const origin = new Remote('origin', 'git@github.com:atom/github.git');
      const upstreamBranch = Branch.createRemoteTracking('refs/remotes/origin/master', 'origin', 'refs/heads/master');
      const branch = new Branch('master', upstreamBranch, upstreamBranch, true);

      repoData = {
        branches: new BranchSet([branch]),
        remotes: new RemoteSet([origin]),
        currentRemote: origin,
        workingDirectoryPath: 'path/path',
      };
      localRepoWrapper = wrapper.find(ObserveModel).renderProp('children')(repoData);
    });

    it('renders nothing if token is UNAUTHENTICATED', function() {
      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')(UNAUTHENTICATED);
      assert.isTrue(tokenWrapper.isEmptyRender());
    });

    it('renders nothing if token is INSUFFICIENT', function() {
      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')(INSUFFICIENT);
      assert.isTrue(tokenWrapper.isEmptyRender());
    });

    it('makes a relay query if token works', async function() {
      const token = await localRepoWrapper.find(ObserveModel).prop('fetchData')(loginModel, repoData);
      assert.strictEqual(token, '1234');

      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
      assert.lengthOf(tokenWrapper.find(QueryRenderer), 1);
    });

    it('renders nothing if query errors', function() {
      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
      const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({
        error: 'oh noes', props: null, retry: () => {}});
      assert.isTrue(resultWrapper.isEmptyRender());
    });

    it('renders nothing if query is loading', function() {
      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
      const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({
        error: null, props: null, retry: () => {}});
      assert.isTrue(resultWrapper.isEmptyRender());
    });

    it('renders nothing if query result does not include repository', function() {
      const props = queryBuilder(rootQuery)
        .nullRepository()
        .build();

      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
      const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({
        error: null, props, retry: () => {}});
      assert.isTrue(resultWrapper.isEmptyRender());
    });

    it('renders nothing if query result does not include repository ref', function() {
      const props = queryBuilder(rootQuery)
        .repository(r => r.nullRef())
        .build();

      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
      const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({
        error: null, props, retry: () => {},
      });
      assert.isTrue(resultWrapper.isEmptyRender());
    });

    it('renders the AggregatedReviewsContainerContainer if result includes repository and ref', function() {
      const props = queryBuilder(rootQuery)
        .repository(r => {
          r.ref(r0 => {
            r0.associatedPullRequests(conn => {
              conn.totalCount(1);
              conn.addNode();
            });
          });
        })
        .build();

      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
      const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({
        error: null, props, retry: () => {},
      });
      assert.lengthOf(resultWrapper.find(AggregatedReviewsContainer), 1);
    });

    it("renders nothing if there's an error aggregating reviews", function() {
      const props = queryBuilder(rootQuery)
        .repository(r => {
          r.ref(r0 => {
            r0.associatedPullRequests(conn => {
              conn.totalCount(1);
              conn.addNode();
            });
          });
        })
        .build();

      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
      const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({
        error: null, props, retry: () => {},
      });
      const reviewsWrapper = resultWrapper.find(AggregatedReviewsContainer).renderProp('children')({
        errors: [new Error('ahhhh')],
        summaries: [],
        commentThreads: [],
      });

      assert.isTrue(reviewsWrapper.isEmptyRender());
    });

    it('renders nothing if there are no review comment threads', function() {
      const props = queryBuilder(rootQuery)
        .repository(r => {
          r.ref(r0 => {
            r0.associatedPullRequests(conn => {
              conn.totalCount(1);
              conn.addNode();
            });
          });
        })
        .build();

      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
      const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({
        error: null, props, retry: () => {},
      });
      const reviewsWrapper = resultWrapper.find(AggregatedReviewsContainer).renderProp('children')({
        errors: [],
        summaries: [],
        commentThreads: [],
      });

      assert.isTrue(reviewsWrapper.isEmptyRender());
    });

    it('loads the patch once there is at least one loaded review comment thread', function() {
      const props = queryBuilder(rootQuery)
        .repository(r => {
          r.ref(r0 => {
            r0.associatedPullRequests(conn => {
              conn.totalCount(1);
              conn.addNode();
            });
          });
        })
        .build();

      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
      const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({
        error: null, props, retry: () => {},
      });
      const reviewsWrapper = resultWrapper.find(AggregatedReviewsContainer).renderProp('children')({
        errors: [],
        summaries: [],
        commentThreads: [
          {thread: {id: 'thread0'}, comments: [{id: 'comment0', path: 'a.txt'}, {id: 'comment1', path: 'a.txt'}]},
        ],
      });
      const patchWrapper = reviewsWrapper.find(PullRequestPatchContainer).renderProp('children')(
        null, null,
      );

      assert.isTrue(patchWrapper.isEmptyRender());
    });

    it('renders nothing if patch cannot be fetched', function() {
      const props = queryBuilder(rootQuery)
        .repository(r => {
          r.ref(r0 => {
            r0.associatedPullRequests(conn => {
              conn.totalCount(1);
              conn.addNode();
            });
          });
        })
        .build();

      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
      const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({
        error: null, props, retry: () => {},
      });
      const reviewsWrapper = resultWrapper.find(AggregatedReviewsContainer).renderProp('children')({
        errors: [],
        summaries: [],
        commentThreads: [
          {thread: {id: 'thread0'}, comments: [{id: 'comment0', path: 'a.txt'}, {id: 'comment1', path: 'a.txt'}]},
        ],
      });
      const patchWrapper = reviewsWrapper.find(PullRequestPatchContainer).renderProp('children')(
        new Error('oops'), null,
      );
      assert.isTrue(patchWrapper.isEmptyRender());
    });

    it('renders a CommentPositioningContainer when the patch and reviews arrive', function() {
      const props = queryBuilder(rootQuery)
        .repository(r => {
          r.ref(r0 => {
            r0.associatedPullRequests(conn => {
              conn.totalCount(1);
              conn.addNode();
            });
          });
        })
        .build();
      const patch = multiFilePatchBuilder().build();

      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
      const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({
        error: null, props, retry: () => {},
      });
      const reviewsWrapper = resultWrapper.find(AggregatedReviewsContainer).renderProp('children')({
        errors: [],
        summaries: [],
        commentThreads: [
          {thread: {id: 'thread0'}, comments: [{id: 'comment0', path: 'a.txt'}, {id: 'comment1', path: 'a.txt'}]},
        ],
      });
      const patchWrapper = reviewsWrapper.find(PullRequestPatchContainer).renderProp('children')(null, patch);

      assert.isTrue(patchWrapper.find(CommentPositioningContainer).exists());
    });

    it('renders nothing while the comment positions are being calculated', function() {
      const props = queryBuilder(rootQuery)
        .repository(r => {
          r.ref(r0 => {
            r0.associatedPullRequests(conn => {
              conn.totalCount(1);
              conn.addNode();
            });
          });
        })
        .build();
      const patch = multiFilePatchBuilder().build();

      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
      const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({
        error: null, props, retry: () => {},
      });
      const reviewsWrapper = resultWrapper.find(AggregatedReviewsContainer).renderProp('children')({
        errors: [],
        summaries: [],
        commentThreads: [
          {thread: {id: 'thread0'}, comments: [{id: 'comment0', path: 'a.txt'}, {id: 'comment1', path: 'a.txt'}]},
        ],
      });
      const patchWrapper = reviewsWrapper.find(PullRequestPatchContainer).renderProp('children')(null, patch);

      const positionedWrapper = patchWrapper.find(CommentPositioningContainer).renderProp('children')(null);
      assert.isTrue(positionedWrapper.isEmptyRender());
    });

    it('renders a CommentDecorationsController with all of the results once comment positions arrive', function() {
      const props = queryBuilder(rootQuery)
        .repository(r => {
          r.ref(r0 => {
            r0.associatedPullRequests(conn => {
              conn.totalCount(1);
              conn.addNode();
            });
          });
        })
        .build();
      const patch = multiFilePatchBuilder().build();

      const tokenWrapper = localRepoWrapper.find(ObserveModel).renderProp('children')('1234');
      const resultWrapper = tokenWrapper.find(QueryRenderer).renderProp('render')({
        error: null, props, retry: () => {},
      });
      const reviewsWrapper = resultWrapper.find(AggregatedReviewsContainer).renderProp('children')({
        errors: [],
        summaries: [],
        commentThreads: [
          {thread: {id: 'thread0'}, comments: [{id: 'comment0', path: 'a.txt'}, {id: 'comment1', path: 'a.txt'}]},
        ],
      });
      const patchWrapper = reviewsWrapper.find(PullRequestPatchContainer).renderProp('children')(null, patch);

      const translations = new Map();
      const positionedWrapper = patchWrapper.find(CommentPositioningContainer).renderProp('children')(translations);

      const controller = positionedWrapper.find(CommentDecorationsController);
      assert.strictEqual(controller.prop('commentTranslations'), translations);
      assert.strictEqual(controller.prop('pullRequests'), props.repository.ref.associatedPullRequests.nodes);
    });
  });
});
