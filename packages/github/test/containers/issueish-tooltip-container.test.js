import React from 'react';
import {shallow} from 'enzyme';

import {BareIssueishTooltipContainer} from '../../lib/containers/issueish-tooltip-container';
import {pullRequestBuilder} from '../builder/graphql/pr';
import {GHOST_USER} from '../../lib/helpers';

import pullRequestsQuery from '../../lib/containers/__generated__/issueishTooltipContainer_resource.graphql';

describe('IssueishTooltipContainer', function() {
  function buildApp(override = {}) {
    const props = {
      ...override,
    };

    return <BareIssueishTooltipContainer {...props} />;
  }

  it('renders information about an issueish', function() {
    const wrapper = shallow(buildApp({
      resource: pullRequestBuilder(pullRequestsQuery)
        .state('OPEN')
        .number(5)
        .title('Fix all the things!')
        .repository(r => {
          r.owner(o => o.login('owner'));
          r.name('repo');
        })
        .author(a => {
          a.login('user');
          a.avatarUrl('https://avatars2.githubusercontent.com/u/0?v=12');
        })
        .build(),
    }));

    assert.strictEqual(wrapper.find('.author-avatar').prop('src'), 'https://avatars2.githubusercontent.com/u/0?v=12');
    assert.strictEqual(wrapper.find('.author-avatar').prop('alt'), 'user');
    assert.strictEqual(wrapper.find('.issueish-title').text(), 'Fix all the things!');
    assert.strictEqual(wrapper.find('.issueish-link').text(), 'owner/repo#5');
  });

  it('shows ghost user as author if none is provided', function() {
    const wrapper = shallow(buildApp({
      resource: pullRequestBuilder(pullRequestsQuery)
        .state('OPEN')
        .number(5)
        .title('Fix all the things!')
        .repository(r => {
          r.owner(o => o.login('owner'));
          r.name('repo');
        })
        .build(),
    }));

    assert.strictEqual(wrapper.find('.author-avatar').prop('src'), GHOST_USER.avatarUrl);
    assert.strictEqual(wrapper.find('.author-avatar').prop('alt'), GHOST_USER.login);
  });
});
