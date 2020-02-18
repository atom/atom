import React from 'react';
import {shallow} from 'enzyme';

import {BareCrossReferencedEventsView} from '../../../lib/views/timeline-items/cross-referenced-events-view';
import CrossReferencedEventView from '../../../lib/views/timeline-items/cross-referenced-event-view';
import {createCrossReferencedEventResult} from '../../fixtures/factories/cross-referenced-event-result';

describe('CrossReferencedEventsView', function() {
  function buildApp(opts) {
    return (
      <BareCrossReferencedEventsView
        nodes={opts.nodeOpts.map(createCrossReferencedEventResult)}
      />
    );
  }

  it('renders a child component for each grouped child event', function() {
    const wrapper = shallow(buildApp({nodeOpts: [{}, {}, {}]}));
    assert.lengthOf(wrapper.find(CrossReferencedEventView), 3);
  });

  it('generates a summary based on a single pull request cross-reference', function() {
    const wrapper = shallow(buildApp({
      nodeOpts: [
        {
          includeActor: true,
          isPullRequest: true,
          isCrossRepository: true,
          actorLogin: 'me',
          actorAvatarUrl: 'https://avatars.com/u/1',
          repositoryOwnerLogin: 'aaa',
          repositoryName: 'bbb',
          referencedAt: '2018-07-02T09:00:00Z',
        },
      ],
    }));

    const avatarImg = wrapper.find('img.author-avatar');
    assert.strictEqual(avatarImg.prop('src'), 'https://avatars.com/u/1');
    assert.strictEqual(avatarImg.prop('title'), 'me');

    assert.strictEqual(wrapper.find('strong').at(0).text(), 'me');

    assert.isTrue(
      wrapper.find('span').someWhere(s => /referenced this from a pull request in aaa\/bbb/.test(s.text())),
    );

    assert.strictEqual(wrapper.find('Timeago').prop('time'), '2018-07-02T09:00:00Z');
  });

  it('generates a summary based on a single issue cross-reference', function() {
    const wrapper = shallow(buildApp({
      nodeOpts: [
        {
          isPullRequest: false,
          isCrossRepository: true,
          actorLogin: 'you',
          actorAvatarUrl: 'https://avatars.com/u/2',
          repositoryOwnerLogin: 'ccc',
          repositoryName: 'ddd',
        },
      ],
    }));

    const avatarImg = wrapper.find('img.author-avatar');
    assert.strictEqual(avatarImg.prop('src'), 'https://avatars.com/u/2');
    assert.strictEqual(avatarImg.prop('title'), 'you');

    assert.strictEqual(wrapper.find('strong').at(0).text(), 'you');

    assert.isTrue(
      wrapper.find('span').someWhere(s => /referenced this from an issue in ccc\/ddd/.test(s.text())),
    );
  });

  it('omits the head repository blurb if the reference is not cross-repository', function() {
    const wrapper = shallow(buildApp({
      nodeOpts: [
        {
          isCrossRepository: false,
          repositoryOwnerLogin: 'ccc',
          repositoryName: 'ddd',
        },
      ],
    }));

    assert.isFalse(
      wrapper.find('span').someWhere(s => /in ccc\/ddd/.test(s.text())),
    );
  });
});
