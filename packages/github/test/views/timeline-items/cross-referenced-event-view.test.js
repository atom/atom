import React from 'react';
import {shallow} from 'enzyme';

import {BareCrossReferencedEventView} from '../../../lib/views/timeline-items/cross-referenced-event-view';
import {createCrossReferencedEventResult} from '../../fixtures/factories/cross-referenced-event-result';

describe('CrossReferencedEventView', function() {
  function buildApp(opts) {
    return <BareCrossReferencedEventView item={createCrossReferencedEventResult(opts)} />;
  }

  it('renders cross-reference data for a cross-repository reference', function() {
    const wrapper = shallow(buildApp({
      isCrossRepository: true,
      number: 5,
      title: 'the title',
      url: 'https://github.com/aaa/bbb/pulls/5',
      repositoryName: 'repo',
      repositoryOwnerLogin: 'owner',
      prState: 'MERGED',
    }));

    assert.strictEqual(wrapper.find('.cross-referenced-event-label-title').text(), 'the title');

    const link = wrapper.find('IssueishLink');
    assert.strictEqual(link.prop('url'), 'https://github.com/aaa/bbb/pulls/5');
    assert.strictEqual(link.children().text(), 'owner/repo#5');

    assert.isFalse(wrapper.find('.cross-referenced-event-private').exists());

    const badge = wrapper.find('IssueishBadge');
    assert.strictEqual(badge.prop('type'), 'PullRequest');
    assert.strictEqual(badge.prop('state'), 'MERGED');
  });

  it('renders a shorter issueish reference number for intra-repository references', function() {
    const wrapper = shallow(buildApp({
      isCrossRepository: false,
      number: 6,
      url: 'https://github.com/aaa/bbb/pulls/6',
    }));

    const link = wrapper.find('IssueishLink');
    assert.strictEqual(link.prop('url'), 'https://github.com/aaa/bbb/pulls/6');
    assert.strictEqual(link.children().text(), '#6');
  });

  it('renders a lock on references from private sources', function() {
    const wrapper = shallow(buildApp({
      repositoryIsPrivate: true,
    }));

    assert.isTrue(wrapper.find('.cross-referenced-event-private Octicon[icon="lock"]').exists());
  });
});
