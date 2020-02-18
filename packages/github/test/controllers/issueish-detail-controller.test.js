import React from 'react';
import {shallow} from 'enzyme';

import * as reporterProxy from '../../lib/reporter-proxy';
import CommitDetailItem from '../../lib/items/commit-detail-item';
import {BareIssueishDetailController} from '../../lib/controllers/issueish-detail-controller';
import PullRequestCheckoutController from '../../lib/controllers/pr-checkout-controller';
import PullRequestDetailView from '../../lib/views/pr-detail-view';
import IssueishDetailItem from '../../lib/items/issueish-detail-item';
import ReviewsItem from '../../lib/items/reviews-item';
import RefHolder from '../../lib/models/ref-holder';
import EnableableOperation from '../../lib/models/enableable-operation';
import BranchSet from '../../lib/models/branch-set';
import RemoteSet from '../../lib/models/remote-set';
import {getEndpoint} from '../../lib/models/endpoint';
import {cloneRepository, buildRepository, registerGitHubOpener} from '../helpers';
import {repositoryBuilder} from '../builder/graphql/repository';

import repositoryQuery from '../../lib/controllers/__generated__/issueishDetailController_repository.graphql';

describe('IssueishDetailController', function() {
  let atomEnv, localRepository;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    registerGitHubOpener(atomEnv);
    localRepository = await buildRepository(await cloneRepository());
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    const props = {
      relay: {},
      repository: repositoryBuilder(repositoryQuery).build(),

      localRepository,
      branches: new BranchSet(),
      remotes: new RemoteSet(),
      isMerging: false,
      isRebasing: false,
      isAbsent: false,
      isLoading: false,
      isPresent: true,
      workdirPath: localRepository.getWorkingDirectoryPath(),
      issueishNumber: 100,

      reviewCommentsLoading: false,
      reviewCommentsTotalCount: 0,
      reviewCommentsResolvedCount: 0,
      reviewCommentThreads: [],

      endpoint: getEndpoint('github.com'),
      token: '1234',

      workspace: atomEnv.workspace,
      commands: atomEnv.commands,
      keymaps: atomEnv.keymaps,
      tooltips: atomEnv.tooltips,
      config: atomEnv.config,

      onTitleChange: () => {},
      switchToIssueish: () => {},
      destroy: () => {},
      reportRelayError: () => {},

      itemType: IssueishDetailItem,
      refEditor: new RefHolder(),

      selectedTab: 0,
      onTabSelected: () => {},
      onOpenFilesTab: () => {},

      ...override,
    };

    return <BareIssueishDetailController {...props} />;
  }

  it('updates the pane title for a pull request on mount', function() {
    const onTitleChange = sinon.stub();
    const repository = repositoryBuilder(repositoryQuery)
      .name('reponame')
      .owner(u => u.login('ownername'))
      .issue(i => i.__typename('PullRequest'))
      .pullRequest(pr => pr.number(12).title('the title'))
      .build();

    shallow(buildApp({repository, onTitleChange}));

    assert.isTrue(onTitleChange.calledWith('PR: ownername/reponame#12 — the title'));
  });

  it('updates the pane title for an issue on mount', function() {
    const onTitleChange = sinon.stub();
    const repository = repositoryBuilder(repositoryQuery)
      .name('reponame')
      .owner(u => u.login('ownername'))
      .issue(i => i.number(34).title('the title'))
      .pullRequest(pr => pr.__typename('Issue'))
      .build();

    shallow(buildApp({repository, onTitleChange}));

    assert.isTrue(onTitleChange.calledWith('Issue: ownername/reponame#34 — the title'));
  });

  it('updates the pane title on update', function() {
    const onTitleChange = sinon.stub();
    const repository0 = repositoryBuilder(repositoryQuery)
      .name('reponame')
      .owner(u => u.login('ownername'))
      .issue(i => i.__typename('PullRequest'))
      .pullRequest(pr => pr.number(12).title('the title'))
      .build();

    const wrapper = shallow(buildApp({repository: repository0, onTitleChange}));

    assert.isTrue(onTitleChange.calledWith('PR: ownername/reponame#12 — the title'));

    const repository1 = repositoryBuilder(repositoryQuery)
      .name('different')
      .owner(u => u.login('new'))
      .issue(i => i.__typename('PullRequest'))
      .pullRequest(pr => pr.number(34).title('the title'))
      .build();

    wrapper.setProps({repository: repository1});

    assert.isTrue(onTitleChange.calledWith('PR: new/different#34 — the title'));
  });

  it('leaves the title alone and renders a message if no repository was found', function() {
    const onTitleChange = sinon.stub();

    const wrapper = shallow(buildApp({onTitleChange, repository: null, issueishNumber: 123}));

    assert.isFalse(onTitleChange.called);
    assert.match(wrapper.find('div').text(), /#123 not found/);
  });

  it('leaves the title alone and renders a message if no issueish was found', function() {
    const onTitleChange = sinon.stub();
    const repository = repositoryBuilder(repositoryQuery)
      .nullPullRequest()
      .nullIssue()
      .build();

    const wrapper = shallow(buildApp({onTitleChange, issueishNumber: 123, repository}));
    assert.isFalse(onTitleChange.called);
    assert.match(wrapper.find('div').text(), /#123 not found/);
  });

  describe('openCommit', function() {
    beforeEach(async function() {
      sinon.stub(reporterProxy, 'addEvent');

      const checkoutOp = new EnableableOperation(() => {}).disable("I don't feel like it");

      const wrapper = shallow(buildApp({workdirPath: __dirname}));
      const checkoutWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(checkoutOp);
      await checkoutWrapper.find(PullRequestDetailView).prop('openCommit')({sha: '1234'});
    });

    it('opens a CommitDetailItem in the workspace', function() {
      assert.include(
        atomEnv.workspace.getPaneItems().map(item => item.getURI()),
        CommitDetailItem.buildURI(__dirname, '1234'),
      );
    });

    it('reports an event', function() {
      assert.isTrue(
        reporterProxy.addEvent.calledWith(
          'open-commit-in-pane', {package: 'github', from: 'BareIssueishDetailController'},
        ),
      );
    });
  });

  describe('openReviews', function() {
    it('opens a ReviewsItem corresponding to our pull request', async function() {
      const repository = repositoryBuilder(repositoryQuery)
        .owner(o => o.login('me'))
        .name('my-bullshit')
        .issue(i => i.__typename('PullRequest'))
        .build();

      const wrapper = shallow(buildApp({
        repository,
        endpoint: getEndpoint('github.enterprise.horse'),
        issueishNumber: 100,
        workdirPath: __dirname,
      }));
      const checkoutWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(
        new EnableableOperation(() => {}),
      );
      await checkoutWrapper.find(PullRequestDetailView).prop('openReviews')();

      assert.include(
        atomEnv.workspace.getPaneItems().map(item => item.getURI()),
        ReviewsItem.buildURI({
          host: 'github.enterprise.horse',
          owner: 'me',
          repo: 'my-bullshit',
          number: 100,
          workdir: __dirname,
        }),
      );
    });

    it('opens a ReviewsItem for a pull request that has no local workdir', async function() {
      const repository = repositoryBuilder(repositoryQuery)
        .owner(o => o.login('me'))
        .name('my-bullshit')
        .issue(i => i.__typename('PullRequest'))
        .build();

      const wrapper = shallow(buildApp({
        repository,
        endpoint: getEndpoint('github.enterprise.horse'),
        issueishNumber: 100,
        workdirPath: null,
      }));
      const checkoutWrapper = wrapper.find(PullRequestCheckoutController).renderProp('children')(
        new EnableableOperation(() => {}),
      );
      await checkoutWrapper.find(PullRequestDetailView).prop('openReviews')();

      assert.include(
        atomEnv.workspace.getPaneItems().map(item => item.getURI()),
        ReviewsItem.buildURI({
          host: 'github.enterprise.horse',
          owner: 'me',
          repo: 'my-bullshit',
          number: 100,
        }),
      );
    });
  });
});
