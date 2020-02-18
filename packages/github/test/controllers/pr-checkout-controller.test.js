import React from 'react';
import {shallow} from 'enzyme';

import {BarePullRequestCheckoutController} from '../../lib/controllers/pr-checkout-controller';
import {cloneRepository, buildRepository} from '../helpers';
import BranchSet from '../../lib/models/branch-set';
import Branch, {nullBranch} from '../../lib/models/branch';
import RemoteSet from '../../lib/models/remote-set';
import Remote from '../../lib/models/remote';
import {GitError} from '../../lib/git-shell-out-strategy';
import {repositoryBuilder} from '../builder/graphql/repository';
import {pullRequestBuilder} from '../builder/graphql/pr';
import * as reporterProxy from '../../lib/reporter-proxy';

import repositoryQuery from '../../lib/controllers/__generated__/prCheckoutController_repository.graphql';
import pullRequestQuery from '../../lib/controllers/__generated__/prCheckoutController_pullRequest.graphql';

describe('PullRequestCheckoutController', function() {
  let localRepository, children;

  beforeEach(async function() {
    localRepository = await buildRepository(await cloneRepository());
    children = sinon.spy();
  });

  function buildApp(override = {}) {
    const branches = new BranchSet([
      new Branch('master', nullBranch, nullBranch, true),
    ]);

    const remotes = new RemoteSet([
      new Remote('origin', 'git@github.com:atom/github.git'),
    ]);

    const props = {
      repository: repositoryBuilder(repositoryQuery).build(),
      pullRequest: pullRequestBuilder(pullRequestQuery).build(),

      localRepository,
      isAbsent: false,
      isLoading: false,
      isPresent: true,
      isMerging: false,
      isRebasing: false,
      branches,
      remotes,
      children,
      ...override,
    };

    return <BarePullRequestCheckoutController {...props} />;
  }

  it('is disabled if the repository is loading or absent', function() {
    const wrapper = shallow(buildApp({isAbsent: true}));
    const [op] = children.lastCall.args;
    assert.isFalse(op.isEnabled());
    assert.strictEqual(op.getMessage(), 'No repository found');

    wrapper.setProps({isAbsent: false, isLoading: true});
    const [op1] = children.lastCall.args;
    assert.isFalse(op1.isEnabled());
    assert.strictEqual(op1.getMessage(), 'Loading');

    wrapper.setProps({isAbsent: false, isLoading: false, isPresent: false});
    const [op2] = children.lastCall.args;
    assert.isFalse(op2.isEnabled());
    assert.strictEqual(op2.getMessage(), 'No repository found');
  });

  it('is disabled if the local repository is merging or rebasing', function() {
    const wrapper = shallow(buildApp({isMerging: true}));
    const [op0] = children.lastCall.args;
    assert.isFalse(op0.isEnabled());
    assert.strictEqual(op0.getMessage(), 'Merge in progress');

    wrapper.setProps({isMerging: false, isRebasing: true});
    const [op1] = children.lastCall.args;
    assert.isFalse(op1.isEnabled());
    assert.strictEqual(op1.getMessage(), 'Rebase in progress');
  });

  it('is disabled if the pullRequest has no headRepository', function() {
    shallow(buildApp({
      pullRequest: pullRequestBuilder(pullRequestQuery).nullHeadRepository().build(),
    }));

    const [op] = children.lastCall.args;
    assert.isFalse(op.isEnabled());
    assert.strictEqual(op.getMessage(), 'Pull request head repository does not exist');
  });

  it('is disabled if the current branch already corresponds to the pull request', function() {
    const upstream = Branch.createRemoteTracking('remotes/origin/feature', 'origin', 'refs/heads/feature');
    const branches = new BranchSet([
      new Branch('current', upstream, upstream, true),
    ]);
    const remotes = new RemoteSet([
      new Remote('origin', 'git@github.com:aaa/bbb.git'),
    ]);

    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .headRefName('feature')
      .headRepository(r => {
        r.owner(o => o.login('aaa'));
        r.name('bbb');
      })
      .build();

    shallow(buildApp({
      pullRequest,
      branches,
      remotes,
    }));

    const [op] = children.lastCall.args;
    assert.isFalse(op.isEnabled());
    assert.strictEqual(op.getMessage(), 'Current');
  });

  it('recognizes a current branch even if it was pulled from the refs/pull/... ref', function() {
    const upstream = Branch.createRemoteTracking('remotes/origin/pull/123/head', 'origin', 'refs/pull/123/head');
    const branches = new BranchSet([
      new Branch('current', upstream, upstream, true),
    ]);
    const remotes = new RemoteSet([
      new Remote('origin', 'git@github.com:aaa/bbb.git'),
    ]);

    const repository = repositoryBuilder(repositoryQuery)
      .owner(o => o.login('aaa'))
      .name('bbb')
      .build();

    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .number(123)
      .headRefName('feature')
      .headRepository(r => {
        r.owner(o => o.login('ccc'));
        r.name('ddd');
      })
      .build();

    shallow(buildApp({
      repository,
      pullRequest,
      branches,
      remotes,
    }));

    const [op] = children.lastCall.args;
    assert.isFalse(op.isEnabled());
    assert.strictEqual(op.getMessage(), 'Current');
  });

  it('creates a new remote, fetches a PR branch, and checks it out into a new local branch', async function() {
    const upstream = Branch.createRemoteTracking('remotes/origin/current', 'origin', 'refs/heads/current');
    const branches = new BranchSet([
      new Branch('current', upstream, upstream, true),
    ]);
    const remotes = new RemoteSet([
      new Remote('origin', 'git@github.com:aaa/bbb.git'),
    ]);

    sinon.stub(localRepository, 'addRemote').resolves(new Remote('ccc', 'git@github.com:ccc/ddd.git'));
    sinon.stub(localRepository, 'fetch').resolves();
    sinon.stub(localRepository, 'checkout').resolves();

    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .number(456)
      .headRefName('feature')
      .headRepository(r => {
        r.owner(o => o.login('ccc'));
        r.name('ddd');
      })
      .build();

    shallow(buildApp({
      pullRequest,
      branches,
      remotes,
    }));

    sinon.spy(reporterProxy, 'incrementCounter');
    const [op] = children.lastCall.args;
    await op.run();

    assert.isTrue(localRepository.addRemote.calledWith('ccc', 'git@github.com:ccc/ddd.git'));
    assert.isTrue(localRepository.fetch.calledWith('refs/heads/feature', {remoteName: 'ccc'}));
    assert.isTrue(localRepository.checkout.calledWith('pr-456/ccc/feature', {
      createNew: true,
      track: true,
      startPoint: 'refs/remotes/ccc/feature',
    }));

    assert.isTrue(reporterProxy.incrementCounter.calledWith('checkout-pr'));
  });

  it('fetches a PR branch from an existing remote and checks it out into a new local branch', async function() {
    sinon.stub(localRepository, 'fetch').resolves();
    sinon.stub(localRepository, 'checkout').resolves();

    const branches = new BranchSet([
      new Branch('current', nullBranch, nullBranch, true),
    ]);
    const remotes = new RemoteSet([
      new Remote('origin', 'git@github.com:aaa/bbb.git'),
      new Remote('existing', 'git@github.com:ccc/ddd.git'),
    ]);

    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .number(789)
      .headRefName('clever-name')
      .headRepository(r => {
        r.owner(o => o.login('ccc'));
        r.name('ddd');
      })
      .build();

    shallow(buildApp({
      pullRequest,
      branches,
      remotes,
    }));

    sinon.spy(reporterProxy, 'incrementCounter');
    const [op] = children.lastCall.args;
    await op.run();

    assert.isTrue(localRepository.fetch.calledWith('refs/heads/clever-name', {remoteName: 'existing'}));
    assert.isTrue(localRepository.checkout.calledWith('pr-789/ccc/clever-name', {
      createNew: true,
      track: true,
      startPoint: 'refs/remotes/existing/clever-name',
    }));

    assert.isTrue(reporterProxy.incrementCounter.calledWith('checkout-pr'));
  });

  it('checks out an existing local branch that corresponds to the pull request', async function() {
    sinon.stub(localRepository, 'pull').resolves();
    sinon.stub(localRepository, 'checkout').resolves();

    const currentUpstream = Branch.createRemoteTracking('remotes/origin/current', 'origin', 'refs/heads/current');
    const branches = new BranchSet([
      new Branch('current', currentUpstream, currentUpstream, true),
      new Branch('existing', Branch.createRemoteTracking('remotes/upstream/pull/123', 'upstream', 'refs/heads/yes')),
      new Branch('wrong/remote', Branch.createRemoteTracking('remotes/wrong/pull/123', 'wrong', 'refs/heads/yes')),
      new Branch('wrong/ref', Branch.createRemoteTracking('remotes/upstream/pull/123', 'upstream', 'refs/heads/no')),
    ]);
    const remotes = new RemoteSet([
      new Remote('origin', 'git@github.com:aaa/bbb.git'),
      new Remote('upstream', 'git@github.com:ccc/ddd.git'),
      new Remote('wrong', 'git@github.com:eee/fff.git'),
    ]);

    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .number(456)
      .headRefName('yes')
      .headRepository(r => {
        r.owner(o => o.login('ccc'));
        r.name('ddd');
      })
      .build();

    shallow(buildApp({
      pullRequest,
      branches,
      remotes,
    }));

    sinon.spy(reporterProxy, 'incrementCounter');
    const [op] = children.lastCall.args;
    await op.run();

    assert.isTrue(localRepository.checkout.calledWith('existing'));
    assert.isTrue(localRepository.pull.calledWith('refs/heads/yes', {remoteName: 'upstream', ffOnly: true}));
    assert.isTrue(reporterProxy.incrementCounter.calledWith('checkout-pr'));
  });

  it('squelches git errors', async function() {
    sinon.stub(localRepository, 'addRemote').rejects(new GitError('handled by the pipeline'));
    shallow(buildApp({}));

    // Should not throw
    const [op] = children.lastCall.args;
    await op.run();
    assert.isTrue(localRepository.addRemote.called);
  });

  it('propagates non-git errors', async function() {
    sinon.stub(localRepository, 'addRemote').rejects(new Error('not handled by the pipeline'));
    shallow(buildApp({}));

    const [op] = children.lastCall.args;
    await assert.isRejected(op.run(), /not handled by the pipeline/);
    assert.isTrue(localRepository.addRemote.called);
  });
});
