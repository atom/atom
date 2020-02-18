import React from 'react';
import {shallow} from 'enzyme';
import {QueryRenderer} from 'react-relay';

import CurrentPullRequestContainer from '../../lib/containers/current-pull-request-container';
import {queryBuilder} from '../builder/graphql/query';
import Remote from '../../lib/models/remote';
import RemoteSet from '../../lib/models/remote-set';
import Branch, {nullBranch} from '../../lib/models/branch';
import BranchSet from '../../lib/models/branch-set';
import IssueishListController, {BareIssueishListController} from '../../lib/controllers/issueish-list-controller';

import repositoryQuery from '../../lib/containers/__generated__/remoteContainerQuery.graphql.js';
import currentQuery from '../../lib/containers/__generated__/currentPullRequestContainerQuery.graphql.js';

describe('CurrentPullRequestContainer', function() {
  function buildApp(overrideProps = {}) {
    const origin = new Remote('origin', 'git@github.com:atom/github.git');
    const upstreamBranch = Branch.createRemoteTracking('refs/remotes/origin/master', 'origin', 'refs/heads/master');
    const branch = new Branch('master', upstreamBranch, upstreamBranch, true);

    const branches = new BranchSet([branch]);
    const remotes = new RemoteSet([origin]);

    const {repository} = queryBuilder(repositoryQuery).build();

    return (
      <CurrentPullRequestContainer
        repository={repository}

        token="1234"
        endpoint={origin.getEndpoint()}
        remote={origin}
        remotes={remotes}
        branches={branches}
        aheadCount={0}
        pushInProgress={false}

        onOpenIssueish={() => {}}
        onOpenReviews={() => {}}
        onCreatePr={() => {}}

        {...overrideProps}
      />
    );
  }

  it('performs no query without a head branch', function() {
    const branches = new BranchSet();
    const wrapper = shallow(buildApp({branches}));

    assert.isFalse(wrapper.find(QueryRenderer).exists());

    const list = wrapper.find(BareIssueishListController);
    assert.isFalse(list.prop('isLoading'));
    assert.strictEqual(list.prop('total'), 0);
    assert.lengthOf(list.prop('results'), 0);

    wrapper.unmount();
  });

  it('performs no query without an upstream remote', function() {
    const branch = new Branch('local', nullBranch, nullBranch, true);
    const branches = new BranchSet([branch]);

    const wrapper = shallow(buildApp({branches}));

    assert.isFalse(wrapper.find(QueryRenderer).exists());

    const list = wrapper.find(BareIssueishListController);
    assert.isTrue(list.exists());
    assert.isFalse(list.prop('isLoading'));
    assert.strictEqual(list.prop('total'), 0);
    assert.lengthOf(list.prop('results'), 0);
  });

  it('performs no query without a valid push remote', function() {
    const tracking = Branch.createRemoteTracking('remotes/nope/wat', 'nope', 'wat');
    const branch = new Branch('local', nullBranch, tracking, true);
    const branches = new BranchSet([branch]);

    const wrapper = shallow(buildApp({branches}));

    assert.isFalse(wrapper.find(QueryRenderer).exists());

    const list = wrapper.find(BareIssueishListController);
    assert.isTrue(list.exists());
    assert.isFalse(list.prop('isLoading'));
    assert.strictEqual(list.prop('total'), 0);
    assert.lengthOf(list.prop('results'), 0);
  });

  it('performs no query without a push remote on GitHub', function() {
    const tracking = Branch.createRemoteTracking('remotes/elsewhere/wat', 'elsewhere', 'wat');
    const branch = new Branch('local', nullBranch, tracking, true);
    const branches = new BranchSet([branch]);

    const remote = new Remote('elsewhere', 'git@elsewhere.wtf:atom/github.git');
    const remotes = new RemoteSet([remote]);

    const wrapper = shallow(buildApp({branches, remotes}));

    assert.isFalse(wrapper.find(QueryRenderer).exists());

    const list = wrapper.find(BareIssueishListController);
    assert.isTrue(list.exists());
    assert.isFalse(list.prop('isLoading'));
    assert.strictEqual(list.prop('total'), 0);
    assert.lengthOf(list.prop('results'), 0);
  });

  it('passes an empty result list and an isLoading prop to the controller while loading', function() {
    const wrapper = shallow(buildApp());

    const resultWrapper = wrapper.find(QueryRenderer).renderProp('render')({error: null, props: null, retry: null});
    assert.isTrue(resultWrapper.find(BareIssueishListController).prop('isLoading'));
  });

  it('passes an empty result list and an error prop to the controller when errored', function() {
    const error = new Error('oh no');
    error.rawStack = error.stack;

    const wrapper = shallow(buildApp());
    const resultWrapper = wrapper.find(QueryRenderer).renderProp('render')({error, props: null, retry: () => {}});

    assert.strictEqual(resultWrapper.find(BareIssueishListController).prop('error'), error);
    assert.isFalse(resultWrapper.find(BareIssueishListController).prop('isLoading'));
  });

  it('passes a configured pull request creation tile to the controller', function() {
    const {repository} = queryBuilder(repositoryQuery).build();
    const remote = new Remote('home', 'git@github.com:atom/atom.git');
    const upstreamBranch = Branch.createRemoteTracking('refs/remotes/home/master', 'home', 'refs/heads/master');
    const branch = new Branch('master', upstreamBranch, upstreamBranch, true);
    const branches = new BranchSet([branch]);
    const remotes = new RemoteSet([remote]);
    const onCreatePr = sinon.spy();

    const wrapper = shallow(buildApp({repository, remote, remotes, branches, aheadCount: 2, pushInProgress: false, onCreatePr}));

    const props = queryBuilder(currentQuery).build();
    const resultWrapper = wrapper.find(QueryRenderer).renderProp('render')({error: null, props, retry: () => {}});

    const emptyTileWrapper = resultWrapper.find(IssueishListController).renderProp('emptyComponent')();

    const tile = emptyTileWrapper.find('CreatePullRequestTile');
    assert.strictEqual(tile.prop('repository'), repository);
    assert.strictEqual(tile.prop('remote'), remote);
    assert.strictEqual(tile.prop('branches'), branches);
    assert.strictEqual(tile.prop('aheadCount'), 2);
    assert.isFalse(tile.prop('pushInProgress'));
    assert.strictEqual(tile.prop('onCreatePr'), onCreatePr);
  });

  it('passes no results if the repository is not found', function() {
    const wrapper = shallow(buildApp());

    const props = queryBuilder(currentQuery)
      .nullRepository()
      .build();

    const resultWrapper = wrapper.find(QueryRenderer).renderProp('render')({error: null, props, retry: () => {}});

    const controller = resultWrapper.find(BareIssueishListController);
    assert.isFalse(controller.prop('isLoading'));
    assert.strictEqual(controller.prop('total'), 0);
  });

  it('passes results to the controller', function() {
    const wrapper = shallow(buildApp());

    const props = queryBuilder(currentQuery)
      .repository(r => {
        r.ref(r0 => {
          r0.associatedPullRequests(conn => {
            conn.addNode();
            conn.addNode();
            conn.addNode();
          });
        });
      })
      .build();

    const resultWrapper = wrapper.find(QueryRenderer).renderProp('render')({error: null, props, retry: () => {}});

    const controller = resultWrapper.find(IssueishListController);
    assert.strictEqual(controller.prop('total'), 3);
  });

  it('filters out pull requests opened on different repositories', function() {
    const {repository} = queryBuilder(repositoryQuery)
      .repository(r => r.id('100'))
      .build();

    const wrapper = shallow(buildApp({repository}));

    const props = queryBuilder(currentQuery).build();
    const resultWrapper = wrapper.find(QueryRenderer).renderProp('render')({error: null, props, retry: () => {}});

    const filterFn = resultWrapper.find(IssueishListController).prop('resultFilter');
    assert.isTrue(filterFn({getHeadRepositoryID: () => '100'}));
    assert.isFalse(filterFn({getHeadRepositoryID: () => '12'}));
  });
});
