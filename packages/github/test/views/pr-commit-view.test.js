import moment from 'moment';
import React from 'react';
import {shallow} from 'enzyme';

import {PrCommitView} from '../../lib/views/pr-commit-view';

const defaultProps = {
  committer: {
    avatarUrl: 'https://avatars3.githubusercontent.com/u/3781742',
    name: 'Margaret Hamilton',
    date: '2018-05-16T21:54:24.500Z',
  },
  messageHeadline: 'This one weird trick for getting to the moon will blow your mind 🚀',
  shortSha: 'bad1dea',
  sha: 'bad1deaea3d816383721478fc631b5edd0c2b370',
  url: 'https://github.com/atom/github/pull/1684/commits/bad1deaea3d816383721478fc631b5edd0c2b370',
};

const getProps = function(itemOverrides = {}, overrides = {}) {
  return {
    item: {
      ...defaultProps,
      ...itemOverrides,
    },
    onBranch: true,
    openCommit: () => {},
    ...overrides,
  };
};

describe('PrCommitView', function() {
  function buildApp(itemOverrides = {}, overrides = {}) {
    return <PrCommitView {...getProps(itemOverrides, overrides)} />;
  }

  it('renders the commit view for commits without message body', function() {
    const wrapper = shallow(buildApp({}));
    assert.deepEqual(wrapper.find('.github-PrCommitView-title').text(), defaultProps.messageHeadline);
    const imageHtml = wrapper.find('.github-PrCommitView-avatar').html();
    assert.ok(imageHtml.includes(defaultProps.committer.avatarUrl));

    const humanizedTimeSince = moment(defaultProps.committer.date).fromNow();
    const expectedMetaText = `${defaultProps.committer.name} committed ${humanizedTimeSince}`;
    assert.deepEqual(wrapper.find('.github-PrCommitView-metaText').text(), expectedMetaText);

    assert.ok(wrapper.find('a').html().includes(defaultProps.url));

    assert.lengthOf(wrapper.find('.github-PrCommitView-moreButton'), 0);
    assert.lengthOf(wrapper.find('.github-PrCommitView-moreText'), 0);
  });

  it('renders the toggle button for commits with message body', function() {
    const messageBody = 'spoiler alert, you will believe what happens next';
    const wrapper = shallow(buildApp({messageBody}));
    const toggleButton = wrapper.find('.github-PrCommitView-moreButton');
    assert.lengthOf(toggleButton, 1);
    assert.deepEqual(toggleButton.text(), 'show more...');
  });

  it('toggles the commit message body when button is clicked', function() {
    const messageBody = 'stuff and things';
    const wrapper = shallow(buildApp({messageBody}));

    // initial state is toggled off
    assert.lengthOf(wrapper.find('.github-PrCommitView-moreText'), 0);

    // toggle on
    wrapper.find('.github-PrCommitView-moreButton').simulate('click');
    const moreText = wrapper.find('.github-PrCommitView-moreText');
    assert.lengthOf(moreText, 1);
    assert.deepEqual(moreText.text(), messageBody);
    assert.deepEqual(wrapper.find('.github-PrCommitView-moreButton').text(), 'hide more...');

    // toggle off again
    wrapper.find('.github-PrCommitView-moreButton').simulate('click');
    assert.lengthOf(wrapper.find('.github-PrCommitView-moreText'), 0);
    assert.deepEqual(wrapper.find('.github-PrCommitView-moreButton').text(), 'show more...');
  });

  describe('if PR is checked out', function() {
    it('shows message headlines as clickable', function() {
      const wrapper = shallow(buildApp({}));
      assert.isTrue(wrapper.find('.github-PrCommitView-messageHeadline').is('button'));
    });

    it('opens a commit with the full sha when title is clicked', function() {
      const openCommit = sinon.spy();
      const wrapper = shallow(buildApp({sha: 'longsha123'}, {openCommit}));
      wrapper.find('button.github-PrCommitView-messageHeadline').at(0).simulate('click');
      assert.isTrue(openCommit.calledWith({sha: 'longsha123'}));
    });
  });

  it('does not show message headlines as clickable if PR is not checked out', function() {
    const wrapper = shallow(buildApp({}, {onBranch: false}));
    assert.isTrue(wrapper.find('.github-PrCommitView-messageHeadline').is('span'));
  });
});
