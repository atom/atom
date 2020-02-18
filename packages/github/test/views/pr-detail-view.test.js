import React from 'react';
import {shallow} from 'enzyme';
import {Tab, Tabs, TabList, TabPanel} from 'react-tabs';

import {BarePullRequestDetailView} from '../../lib/views/pr-detail-view';
import {checkoutStates} from '../../lib/controllers/pr-checkout-controller';
import EmojiReactionsController from '../../lib/controllers/emoji-reactions-controller';
import PullRequestCommitsView from '../../lib/views/pr-commits-view';
import PullRequestStatusesView from '../../lib/views/pr-statuses-view';
import PullRequestTimelineController from '../../lib/controllers/pr-timeline-controller';
import IssueishDetailItem from '../../lib/items/issueish-detail-item';
import EnableableOperation from '../../lib/models/enableable-operation';
import RefHolder from '../../lib/models/ref-holder';
import {getEndpoint} from '../../lib/models/endpoint';
import * as reporterProxy from '../../lib/reporter-proxy';
import {repositoryBuilder} from '../builder/graphql/repository';
import {pullRequestBuilder} from '../builder/graphql/pr';
import {cloneRepository, buildRepository} from '../helpers';
import {GHOST_USER} from '../../lib/helpers';

import repositoryQuery from '../../lib/views/__generated__/prDetailView_repository.graphql';
import pullRequestQuery from '../../lib/views/__generated__/prDetailView_pullRequest.graphql';

describe('PullRequestDetailView', function() {
  let atomEnv, localRepository;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    localRepository = await buildRepository(await cloneRepository());
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrides = {}) {
    const props = {
      relay: {refetch() {}},
      repository: repositoryBuilder(repositoryQuery).build(),
      pullRequest: pullRequestBuilder(pullRequestQuery).build(),

      localRepository,
      checkoutOp: new EnableableOperation(() => {}),

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

      openCommit: () => {},
      openReviews: () => {},
      switchToIssueish: () => {},
      destroy: () => {},
      reportRelayError: () => {},

      itemType: IssueishDetailItem,
      refEditor: new RefHolder(),

      selectedTab: 0,
      onTabSelected: () => {},
      onOpenFilesTab: () => {},

      ...overrides,
    };

    return <BarePullRequestDetailView {...props} />;
  }

  function findTabIndex(wrapper, tabText) {
    let finalIndex;
    let tempIndex = 0;
    wrapper.find('Tab').forEach(t => {
      t.children().forEach(child => {
        if (child.text() === tabText) {
          finalIndex = tempIndex;
        }
      });
      tempIndex++;
    });
    return finalIndex;
  }

  it('renders pull request information', function() {
    const repository = repositoryBuilder(repositoryQuery)
      .name('repo')
      .owner(o => o.login('user0'))
      .build();

    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .number(100)
      .title('PR title')
      .state('MERGED')
      .bodyHTML('<code>stuff</code>')
      .baseRefName('master')
      .headRefName('tt/heck-yes')
      .url('https://github.com/user0/repo/pull/100')
      .author(a => a.login('author0').avatarUrl('https://avatars3.githubusercontent.com/u/1'))
      .build();

    const wrapper = shallow(buildApp({repository, pullRequest}));

    const badge = wrapper.find('IssueishBadge');
    assert.strictEqual(badge.prop('type'), 'PullRequest');
    assert.strictEqual(badge.prop('state'), 'MERGED');

    const link = wrapper.find('a.github-IssueishDetailView-headerLink');
    assert.strictEqual(link.text(), 'user0/repo#100');
    assert.strictEqual(link.prop('href'), 'https://github.com/user0/repo/pull/100');

    assert.isTrue(wrapper.find('CheckoutButton').exists());

    assert.isDefined(wrapper.find(PullRequestStatusesView).find('[displayType="check"]').prop('pullRequest'));

    const avatarLink = wrapper.find('.github-IssueishDetailView-avatar');
    assert.strictEqual(avatarLink.prop('href'), 'https://github.com/author0');
    const avatar = avatarLink.find('img');
    assert.strictEqual(avatar.prop('src'), 'https://avatars3.githubusercontent.com/u/1');
    assert.strictEqual(avatar.prop('title'), 'author0');

    assert.strictEqual(wrapper.find('.github-IssueishDetailView-title').text(), 'PR title');

    assert.isTrue(wrapper.find('GithubDotcomMarkdown').someWhere(n => n.prop('html') === '<code>stuff</code>'));

    assert.lengthOf(wrapper.find(EmojiReactionsController), 1);

    assert.notOk(wrapper.find(PullRequestTimelineController).prop('issue'));
    assert.isNotNull(wrapper.find(PullRequestTimelineController).prop('pullRequest'));
    assert.isNotNull(wrapper.find(PullRequestStatusesView).find('[displayType="full"]').prop('pullRequest'));

    assert.strictEqual(wrapper.find('.github-IssueishDetailView-baseRefName').text(), 'master');
    assert.strictEqual(wrapper.find('.github-IssueishDetailView-headRefName').text(), 'tt/heck-yes');
  });

  it('renders ghost user if author is null', function() {
    const wrapper = shallow(buildApp({}));

    assert.strictEqual(wrapper.find('.github-IssueishDetailView-avatar').prop('href'), GHOST_USER.url);
    assert.strictEqual(wrapper.find('.github-IssueishDetailView-avatarImage').prop('src'), GHOST_USER.avatarUrl);
    assert.strictEqual(wrapper.find('.github-IssueishDetailView-avatarImage').prop('alt'), GHOST_USER.login);
  });

  it('renders footer and passes review thread props through', function() {
    const openReviews = sinon.spy();

    const wrapper = shallow(buildApp({
      reviewCommentsLoading: false,
      reviewCommentsTotalCount: 10,
      reviewCommentsResolvedCount: 5,
      openReviews,
    }));

    const footer = wrapper.find('ReviewsFooterView');

    assert.strictEqual(footer.prop('commentsResolved'), 5);
    assert.strictEqual(footer.prop('totalComments'), 10);

    footer.prop('openReviews')();
    assert.isTrue(openReviews.called);
  });

  it('renders tabs', function() {
    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .changedFiles(22)
      .countedCommits(conn => conn.totalCount(11))
      .build();

    const wrapper = shallow(buildApp({pullRequest}));

    assert.lengthOf(wrapper.find(Tabs), 1);
    assert.lengthOf(wrapper.find(TabList), 1);

    const tabs = wrapper.find(Tab).getElements();
    assert.lengthOf(tabs, 4);

    const tab0Children = tabs[0].props.children;
    assert.deepEqual(tab0Children[0].props, {icon: 'info', className: 'github-tab-icon'});
    assert.deepEqual(tab0Children[1], 'Overview');

    const tab1Children = tabs[1].props.children;
    assert.deepEqual(tab1Children[0].props, {icon: 'checklist', className: 'github-tab-icon'});
    assert.deepEqual(tab1Children[1], 'Build Status');

    const tab2Children = tabs[2].props.children;
    assert.deepEqual(tab2Children[0].props, {icon: 'git-commit', className: 'github-tab-icon'});
    assert.deepEqual(tab2Children[1], 'Commits');

    const tab3Children = tabs[3].props.children;
    assert.deepEqual(tab3Children[0].props, {icon: 'diff', className: 'github-tab-icon'});
    assert.deepEqual(tab3Children[1], 'Files');

    const tabCounts = wrapper.find('.github-tab-count');
    assert.lengthOf(tabCounts, 2);
    assert.strictEqual(tabCounts.at(0).text(), '11');
    assert.strictEqual(tabCounts.at(1).text(), '22');

    assert.lengthOf(wrapper.find(TabPanel), 4);
  });

  it('passes selected tab index to tabs', function() {
    const onTabSelected = sinon.spy();

    const wrapper = shallow(buildApp({selectedTab: 0, onTabSelected}));
    assert.strictEqual(wrapper.find('Tabs').prop('selectedIndex'), 0);

    const index = findTabIndex(wrapper, 'Commits');
    wrapper.find('Tabs').prop('onSelect')(index);
    assert.isTrue(onTabSelected.calledWith(index));
  });

  it('tells its tabs when the pull request is currently checked out', function() {
    const wrapper = shallow(buildApp({
      checkoutOp: new EnableableOperation(() => {}).disable(checkoutStates.CURRENT),
    }));

    assert.isTrue(wrapper.find(PullRequestTimelineController).prop('onBranch'));
    assert.isTrue(wrapper.find(PullRequestCommitsView).prop('onBranch'));
  });

  it('tells its tabs when the pull request is not checked out', function() {
    const checkoutOp = new EnableableOperation(() => {});

    const wrapper = shallow(buildApp({checkoutOp}));
    assert.isFalse(wrapper.find(PullRequestTimelineController).prop('onBranch'));
    assert.isFalse(wrapper.find(PullRequestCommitsView).prop('onBranch'));

    wrapper.setProps({checkoutOp: checkoutOp.disable(checkoutStates.HIDDEN, 'message')});
    assert.isFalse(wrapper.find(PullRequestTimelineController).prop('onBranch'));
    assert.isFalse(wrapper.find(PullRequestCommitsView).prop('onBranch'));

    wrapper.setProps({checkoutOp: checkoutOp.disable(checkoutStates.DISABLED, 'message')});
    assert.isFalse(wrapper.find(PullRequestTimelineController).prop('onBranch'));
    assert.isFalse(wrapper.find(PullRequestCommitsView).prop('onBranch'));

    wrapper.setProps({checkoutOp: checkoutOp.disable(checkoutStates.BUSY, 'message')});
    assert.isFalse(wrapper.find(PullRequestTimelineController).prop('onBranch'));
    assert.isFalse(wrapper.find(PullRequestCommitsView).prop('onBranch'));
  });

  it('renders pull request information for a cross repository PR', function() {
    const repository = repositoryBuilder(repositoryQuery)
      .owner(o => o.login('user0'))
      .build();

    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .isCrossRepository(true)
      .author(a => a.login('author0'))
      .baseRefName('master')
      .headRefName('tt-heck-yes')
      .build();

    const wrapper = shallow(buildApp({repository, pullRequest}));

    assert.strictEqual(wrapper.find('.github-IssueishDetailView-baseRefName').text(), 'user0/master');
    assert.strictEqual(wrapper.find('.github-IssueishDetailView-headRefName').text(), 'author0/tt-heck-yes');
  });

  it('renders a placeholder issueish body', function() {
    const pullRequest = pullRequestBuilder(pullRequestQuery)
      .nullBodyHTML()
      .build();
    const wrapper = shallow(buildApp({pullRequest}));

    assert.isTrue(wrapper.find('GithubDotcomMarkdown').someWhere(n => /No description/.test(n.prop('html'))));
  });

  it('refreshes on click', function() {
    let callback = null;
    const refetch = sinon.stub().callsFake((_0, _1, cb) => {
      callback = cb;
    });
    const wrapper = shallow(buildApp({relay: {refetch}}));

    wrapper.find('Octicon[icon="repo-sync"]').simulate('click', {preventDefault: () => {}});
    assert.isTrue(wrapper.find('Octicon[icon="repo-sync"]').hasClass('refreshing'));

    callback();
    wrapper.update();

    assert.isFalse(wrapper.find('Octicon[icon="repo-sync"]').hasClass('refreshing'));
  });

  it('reports errors encountered during refetch', function() {
    let callback = null;
    const refetch = sinon.stub().callsFake((_0, _1, cb) => {
      callback = cb;
    });
    const reportRelayError = sinon.spy();
    const wrapper = shallow(buildApp({relay: {refetch}, reportRelayError}));

    wrapper.find('Octicon[icon="repo-sync"]').simulate('click', {preventDefault: () => {}});
    assert.isTrue(wrapper.find('Octicon[icon="repo-sync"]').hasClass('refreshing'));

    const e = new Error('nope');
    callback(e);
    assert.isTrue(reportRelayError.calledWith(sinon.match.string, e));

    wrapper.update();
    assert.isFalse(wrapper.find('Octicon[icon="repo-sync"]').hasClass('refreshing'));
  });

  it('disregards a double refresh', function() {
    let callback = null;
    const refetch = sinon.stub().callsFake((_0, _1, cb) => {
      callback = cb;
    });
    const wrapper = shallow(buildApp({relay: {refetch}}));

    wrapper.find('Octicon[icon="repo-sync"]').simulate('click', {preventDefault: () => {}});
    assert.strictEqual(refetch.callCount, 1);

    wrapper.find('Octicon[icon="repo-sync"]').simulate('click', {preventDefault: () => {}});
    assert.strictEqual(refetch.callCount, 1);

    callback();
    wrapper.update();

    wrapper.find('Octicon[icon="repo-sync"]').simulate('click', {preventDefault: () => {}});
    assert.strictEqual(refetch.callCount, 2);
  });

  it('configures the refresher with a 5 minute polling interval', function() {
    const wrapper = shallow(buildApp({}));

    assert.strictEqual(wrapper.instance().refresher.options.interval(), 5 * 60 * 1000);
  });

  it('destroys its refresher on unmount', function() {
    const wrapper = shallow(buildApp({}));

    const refresher = wrapper.instance().refresher;
    sinon.spy(refresher, 'destroy');

    wrapper.unmount();

    assert.isTrue(refresher.destroy.called);
  });

  describe('metrics', function() {
    beforeEach(function() {
      sinon.stub(reporterProxy, 'addEvent');
    });

    it('records clicking the link to view an issueish', function() {
      const repository = repositoryBuilder(repositoryQuery)
        .name('repo')
        .owner(o => o.login('user0'))
        .build();

      const pullRequest = pullRequestBuilder(pullRequestQuery)
        .number(100)
        .url('https://github.com/user0/repo/pull/100')
        .build();

      const wrapper = shallow(buildApp({repository, pullRequest}));

      const link = wrapper.find('a.github-IssueishDetailView-headerLink');
      assert.strictEqual(link.text(), 'user0/repo#100');
      assert.strictEqual(link.prop('href'), 'https://github.com/user0/repo/pull/100');
      link.simulate('click');

      assert.isTrue(reporterProxy.addEvent.calledWith(
        'open-pull-request-in-browser',
        {package: 'github', component: 'BarePullRequestDetailView'},
      ));
    });

    it('records opening the Overview tab', function() {
      const wrapper = shallow(buildApp());
      const index = findTabIndex(wrapper, 'Overview');

      wrapper.find('Tabs').prop('onSelect')(index);

      assert.isTrue(reporterProxy.addEvent.calledWith(
        'open-pr-tab-overview',
        {package: 'github', component: 'BarePullRequestDetailView'},
      ));
    });

    it('records opening the Build Status tab', function() {
      const wrapper = shallow(buildApp());
      const index = findTabIndex(wrapper, 'Build Status');

      wrapper.find('Tabs').prop('onSelect')(index);

      assert.isTrue(reporterProxy.addEvent.calledWith(
        'open-pr-tab-build-status',
        {package: 'github', component: 'BarePullRequestDetailView'},
      ));
    });

    it('records opening the Commits tab', function() {
      const wrapper = shallow(buildApp());
      const index = findTabIndex(wrapper, 'Commits');

      wrapper.find('Tabs').prop('onSelect')(index);

      assert.isTrue(reporterProxy.addEvent.calledWith(
        'open-pr-tab-commits',
        {package: 'github', component: 'BarePullRequestDetailView'},
      ));
    });

    it('records opening the "Files Changed" tab', function() {
      const wrapper = shallow(buildApp());
      const index = findTabIndex(wrapper, 'Files');

      wrapper.find('Tabs').prop('onSelect')(index);

      assert.isTrue(reporterProxy.addEvent.calledWith(
        'open-pr-tab-files-changed',
        {package: 'github', component: 'BarePullRequestDetailView'},
      ));
    });
  });
});
