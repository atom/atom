import React from 'react';
import {shallow} from 'enzyme';

import {BareHeadRefForcePushedEventView} from '../../../lib/views/timeline-items/head-ref-force-pushed-event-view';

describe('HeadRefForcePushedEventView', function() {
  function buildApp(opts, overrideProps = {}) {
    const o = {
      includeActor: true,
      includeBeforeCommit: true,
      includeAfterCommit: true,
      actorAvatarUrl: 'https://avatars.com/u/200',
      actorLogin: 'actor',
      beforeCommitOid: '0000111100001111',
      afterCommitOid: '0000222200002222',
      createdAt: '2018-07-02T09:00:00Z',
      headRefName: 'head-ref',
      headRepositoryOwnerLogin: 'head-repo-owner',
      repositoryOwnerLogin: 'repo-owner',
      ...opts,
    };

    const props = {
      item: {
        actor: null,
        beforeCommit: null,
        afterCommit: null,
        createdAt: o.createdAt,
      },
      issueish: {
        headRefName: o.headRefName,
        headRepositoryOwner: {
          login: o.headRepositoryOwnerLogin,
        },
        repository: {
          owner: {
            login: o.repositoryOwnerLogin,
          },
        },
      },
      ...overrideProps,
    };

    if (o.includeActor && !props.item.actor) {
      props.item.actor = {
        avatarUrl: o.actorAvatarUrl,
        login: o.actorLogin,
      };
    }

    if (o.includeBeforeCommit && !props.item.beforeCommit) {
      props.item.beforeCommit = {
        oid: o.beforeCommitOid,
      };
    }

    if (o.includeAfterCommit && !props.item.afterCommit) {
      props.item.afterCommit = {
        oid: o.afterCommitOid,
      };
    }

    return <BareHeadRefForcePushedEventView {...props} />;
  }

  it('renders all event data', function() {
    const wrapper = shallow(buildApp({}));

    const avatarImg = wrapper.find('img.author-avatar');
    assert.strictEqual(avatarImg.prop('src'), 'https://avatars.com/u/200');
    assert.strictEqual(avatarImg.prop('title'), 'actor');

    assert.strictEqual(wrapper.find('.username').text(), 'actor');
    assert.match(wrapper.find('.head-ref-force-pushed-event').text(), /force-pushed the head-repo-owner:head-ref/);
    assert.deepEqual(wrapper.find('.sha').map(n => n.text()), ['00001111', '00002222']);
    assert.strictEqual(wrapper.find('Timeago').prop('time'), '2018-07-02T09:00:00Z');
  });

  it('omits the branch prefix when the head and base repositories match', function() {
    const wrapper = shallow(buildApp({
      headRepositoryOwnerLogin: 'same',
      repositoryOwnerLogin: 'same',
    }));

    assert.match(wrapper.find('.head-ref-force-pushed-event').text(), /force-pushed the head-ref/);
  });

  it('renders with a missing actor and before and after commits', function() {
    const wrapper = shallow(buildApp({includeActor: false, includeBeforeCommit: false, includeAfterCommit: false}));

    assert.isFalse(wrapper.find('img.author-avatar').exists());
    assert.strictEqual(wrapper.find('.username').text(), 'someone');
    assert.isFalse(wrapper.find('.sha').exists());
    assert.match(wrapper.find('.head-ref-force-pushed-event').text(), /an old commit to a new commit/);
  });
});
