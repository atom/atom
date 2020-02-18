import React from 'react';
import {shallow} from 'enzyme';

import {BareMergedEventView} from '../../../lib/views/timeline-items/merged-event-view';

describe('MergedEventView', function() {
  function buildApp(opts, overrideProps = {}) {
    const o = {
      includeActor: true,
      includeCommit: true,
      actorLogin: 'actor',
      actorAvatarUrl: 'https://avatars.com/u/100',
      commitOid: '0000ffff0000ffff',
      mergeRefName: 'some-ref',
      ...opts,
    };

    const props = {
      item: {
        mergeRefName: o.mergeRefName,
        createdAt: '2018-07-02T09:00:00Z',
      },
      ...overrideProps,
    };

    if (o.includeActor) {
      props.item.actor = {
        login: o.actorLogin,
        avatarUrl: o.actorAvatarUrl,
      };
    }

    if (o.includeCommit) {
      props.item.commit = {
        oid: o.commitOid,
      };
    }

    return <BareMergedEventView {...props} />;
  }

  it('renders event data', function() {
    const wrapper = shallow(buildApp({}));

    const avatarImg = wrapper.find('img.author-avatar');
    assert.strictEqual(avatarImg.prop('src'), 'https://avatars.com/u/100');
    assert.strictEqual(avatarImg.prop('title'), 'actor');

    assert.strictEqual(wrapper.find('.username').text(), 'actor');
    assert.strictEqual(wrapper.find('.sha').text(), '0000ffff');
    assert.strictEqual(wrapper.find('.merge-ref').text(), 'some-ref');

    assert.strictEqual(wrapper.find('Timeago').prop('time'), '2018-07-02T09:00:00Z');
  });

  it('renders correctly without an actor or commit', function() {
    const wrapper = shallow(buildApp({includeActor: false, includeCommit: false}));

    assert.isFalse(wrapper.find('img.author-avatar').exists());
    assert.strictEqual(wrapper.find('.username').text(), 'someone');
    assert.isFalse(wrapper.find('.sha').exists());
  });

  it('renders a space between merged and commit', function() {
    const wrapper = shallow(buildApp({}));
    const text = wrapper.find('.merged-event-header').text();

    assert.isTrue(text.includes('merged commit'));
  });
});
