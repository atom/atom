import React from 'react';
import {shallow} from 'enzyme';

import IssueishSearchesController from '../../lib/controllers/issueish-searches-controller';
import {queryBuilder} from '../builder/graphql/query';
import Remote from '../../lib/models/remote';
import RemoteSet from '../../lib/models/remote-set';
import Branch from '../../lib/models/branch';
import BranchSet from '../../lib/models/branch-set';
import Issueish from '../../lib/models/issueish';
import {getEndpoint} from '../../lib/models/endpoint';
import * as reporterProxy from '../../lib/reporter-proxy';

import remoteContainerQuery from '../../lib/containers/__generated__/remoteContainerQuery.graphql';

describe('IssueishSearchesController', function() {
  let atomEnv;
  const origin = new Remote('origin', 'git@github.com:atom/github.git');
  const upstreamMaster = Branch.createRemoteTracking('origin/master', 'origin', 'refs/heads/master');
  const master = new Branch('master', upstreamMaster);

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overloadProps = {}) {
    const branches = new BranchSet();
    branches.add(master);

    return (
      <IssueishSearchesController
        token="1234"
        endpoint={getEndpoint('github.com')}
        repository={queryBuilder(remoteContainerQuery).build().repository}

        workingDirectory={__dirname}
        workspace={atomEnv.workspace}
        remote={origin}
        remotes={new RemoteSet([origin])}
        branches={branches}
        aheadCount={0}
        pushInProgress={false}

        onCreatePr={() => {}}

        {...overloadProps}
      />
    );
  }

  it('renders a CurrentPullRequestContainer', function() {
    const branches = new BranchSet();
    branches.add(master);

    const p = {
      token: '4321',
      endpoint: getEndpoint('mygithub.com'),
      repository: queryBuilder(remoteContainerQuery).build().repository,
      remote: origin,
      remotes: new RemoteSet([origin]),
      branches,
      aheadCount: 4,
      pushInProgress: true,
    };

    const wrapper = shallow(buildApp(p));
    const container = wrapper.find('CurrentPullRequestContainer');
    assert.isTrue(container.exists());

    for (const key in p) {
      assert.strictEqual(container.prop(key), p[key], `expected prop ${key} to be passed`);
    }
  });

  it('renders an IssueishSearchContainer for each Search', function() {
    const wrapper = shallow(buildApp());
    assert.isTrue(wrapper.state('searches').length > 0);

    for (const search of wrapper.state('searches')) {
      const list = wrapper.find('IssueishSearchContainer').filterWhere(w => w.prop('search') === search);
      assert.isTrue(list.exists());
      assert.strictEqual(list.prop('token'), '1234');
      assert.strictEqual(list.prop('endpoint').getHost(), 'github.com');
    }
  });

  it('passes a handler to open an issueish pane and reports an event', async function() {
    sinon.spy(atomEnv.workspace, 'open');

    const wrapper = shallow(buildApp());
    const container = wrapper.find('IssueishSearchContainer').at(0);

    const issueish = new Issueish({
      number: 123,
      url: 'https://github.com/atom/github/issue/123',
      author: {login: 'smashwilson', avatarUrl: 'https://avatars0.githubusercontent.com/u/17565?s=40&v=4'},
      createdAt: '2019-04-01T10:00:00',
      repository: {id: '0'},
      commits: {nodes: []},
    });

    sinon.stub(reporterProxy, 'addEvent');
    await container.prop('onOpenIssueish')(issueish);
    assert.isTrue(
      atomEnv.workspace.open.calledWith(
        `atom-github://issueish/github.com/atom/github/123?workdir=${encodeURIComponent(__dirname)}`,
        {pending: true, searchAllPanes: true},
      ),
    );
    assert.isTrue(reporterProxy.addEvent.calledWith('open-issueish-in-pane', {package: 'github', from: 'issueish-list'}));
  });

  it('passes a handler to open reviews and reports an event', async function() {
    sinon.spy(atomEnv.workspace, 'open');

    const wrapper = shallow(buildApp());
    const container = wrapper.find('IssueishSearchContainer').at(0);

    const issueish = new Issueish({
      number: 2084,
      url: 'https://github.com/atom/github/pull/2084',
      author: {login: 'kuychaco', avatarUrl: 'https://avatars3.githubusercontent.com/u/7910250?v=4'},
      createdAt: '2019-04-01T10:00:00',
      repository: {id: '0'},
      commits: {nodes: []},
    });

    sinon.stub(reporterProxy, 'addEvent');
    await container.prop('onOpenReviews')(issueish);
    assert.isTrue(
      atomEnv.workspace.open.calledWith(
        `atom-github://reviews/github.com/atom/github/2084?workdir=${encodeURIComponent(__dirname)}`,
      ),
    );
    assert.isTrue(reporterProxy.addEvent.calledWith('open-reviews-tab', {package: 'github', from: 'IssueishSearchesController'}));
  });
});
