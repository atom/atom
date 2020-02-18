import React from 'react';
import {shallow} from 'enzyme';

import {BareIssueDetailView} from '../../lib/views/issue-detail-view';
import EmojiReactionsController from '../../lib/controllers/emoji-reactions-controller';
import IssueTimelineController from '../../lib/controllers/issue-timeline-controller';
import {issueDetailViewProps} from '../fixtures/props/issueish-pane-props';
import * as reporterProxy from '../../lib/reporter-proxy';
import {GHOST_USER} from '../../lib/helpers';

describe('IssueDetailView', function() {
  function buildApp(opts, overrideProps = {}) {
    return <BareIssueDetailView {...issueDetailViewProps(opts, overrideProps)} />;
  }

  it('renders issue information', function() {
    const wrapper = shallow(buildApp({
      repositoryName: 'repo',
      ownerLogin: 'user1',

      issueKind: 'Issue',
      issueTitle: 'Issue title',
      issueBodyHTML: '<code>nope</code>',
      issueAuthorLogin: 'author1',
      issueAuthorAvatarURL: 'https://avatars3.githubusercontent.com/u/2',
      issueishNumber: 200,
      issueState: 'CLOSED',
      issueReactions: [{content: 'THUMBS_UP', count: 6}, {content: 'THUMBS_DOWN', count: 0}, {content: 'LAUGH', count: 2}],
    }, {}));

    const badge = wrapper.find('IssueishBadge');
    assert.strictEqual(badge.prop('type'), 'Issue');
    assert.strictEqual(badge.prop('state'), 'CLOSED');

    const link = wrapper.find('a.github-IssueishDetailView-headerLink');
    assert.strictEqual(link.text(), 'user1/repo#200');
    assert.strictEqual(link.prop('href'), 'https://github.com/user1/repo/issues/200');

    assert.isFalse(wrapper.find('ForwardRef(Relay(PrStatuses))').exists());
    assert.isFalse(wrapper.find('.github-IssueishDetailView-checkoutButton').exists());

    const avatarLink = wrapper.find('.github-IssueishDetailView-avatar');
    assert.strictEqual(avatarLink.prop('href'), 'https://github.com/author1');
    const avatar = avatarLink.find('img');
    assert.strictEqual(avatar.prop('src'), 'https://avatars3.githubusercontent.com/u/2');
    assert.strictEqual(avatar.prop('title'), 'author1');

    assert.strictEqual(wrapper.find('.github-IssueishDetailView-title').text(), 'Issue title');

    assert.isTrue(wrapper.find('GithubDotcomMarkdown').someWhere(n => n.prop('html') === '<code>nope</code>'));

    assert.lengthOf(wrapper.find(EmojiReactionsController), 1);

    assert.isNotNull(wrapper.find(IssueTimelineController).prop('issue'));
    assert.notOk(wrapper.find(IssueTimelineController).prop('pullRequest'));
  });

  it('displays ghost author if author is null', function() {
    const wrapper = shallow(buildApp({includeAuthor: false}));

    assert.strictEqual(wrapper.find('.github-IssueishDetailView-avatar').prop('href'), GHOST_USER.url);
    assert.strictEqual(wrapper.find('.github-IssueishDetailView-avatarImage').prop('src'), GHOST_USER.avatarUrl);
    assert.strictEqual(wrapper.find('.github-IssueishDetailView-avatarImage').prop('alt'), GHOST_USER.login);
  });

  it('renders a placeholder issue body', function() {
    const wrapper = shallow(buildApp({issueBodyHTML: null}));
    assert.isTrue(wrapper.find('GithubDotcomMarkdown').someWhere(n => /No description/.test(n.prop('html'))));
  });

  it('refreshes on click', function() {
    let callback = null;
    const relayRefetch = sinon.stub().callsFake((_0, _1, cb) => {
      callback = cb;
    });
    const wrapper = shallow(buildApp({relayRefetch}, {}));

    wrapper.find('Octicon[icon="repo-sync"]').simulate('click', {preventDefault: () => {}});
    assert.isTrue(wrapper.find('Octicon[icon="repo-sync"]').hasClass('refreshing'));

    callback();
    wrapper.update();

    assert.isFalse(wrapper.find('Octicon[icon="repo-sync"]').hasClass('refreshing'));
  });

  it('reports errors encountered during refresh', function() {
    let callback = null;
    const relayRefetch = sinon.stub().callsFake((_0, _1, cb) => {
      callback = cb;
    });
    const reportRelayError = sinon.spy();
    const wrapper = shallow(buildApp({relayRefetch}, {reportRelayError}));

    wrapper.find('Octicon[icon="repo-sync"]').simulate('click', {preventDefault: () => {}});

    const e = new Error('ouch');
    callback(e);
    assert.isTrue(reportRelayError.calledWith(sinon.match.string, e));

    wrapper.update();
    assert.isFalse(wrapper.find('Octicon[icon="repo-sync"]').hasClass('refreshing'));
  });

  it('disregardes a double refresh', function() {
    let callback = null;
    const relayRefetch = sinon.stub().callsFake((_0, _1, cb) => {
      callback = cb;
    });
    const wrapper = shallow(buildApp({relayRefetch}, {}));

    wrapper.find('Octicon[icon="repo-sync"]').simulate('click', {preventDefault: () => {}});
    assert.strictEqual(relayRefetch.callCount, 1);

    wrapper.find('Octicon[icon="repo-sync"]').simulate('click', {preventDefault: () => {}});
    assert.strictEqual(relayRefetch.callCount, 1);

    callback();
    wrapper.update();

    wrapper.find('Octicon[icon="repo-sync"]').simulate('click', {preventDefault: () => {}});
    assert.strictEqual(relayRefetch.callCount, 2);
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

  describe('clicking link to view issueish link', function() {
    it('records an event', function() {
      const wrapper = shallow(buildApp({
        repositoryName: 'repo',
        ownerLogin: 'user0',
        issueishNumber: 100,
      }));

      sinon.stub(reporterProxy, 'addEvent');

      const link = wrapper.find('a.github-IssueishDetailView-headerLink');
      assert.strictEqual(link.text(), 'user0/repo#100');
      assert.strictEqual(link.prop('href'), 'https://github.com/user0/repo/issues/100');
      link.simulate('click');

      assert.isTrue(reporterProxy.addEvent.calledWith('open-issue-in-browser', {package: 'github', component: 'BareIssueDetailView'}));
    });
  });
});
