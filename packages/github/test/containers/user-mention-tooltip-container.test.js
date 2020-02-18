import React from 'react';
import {shallow} from 'enzyme';

import {BareUserMentionTooltipContainer} from '../../lib/containers/user-mention-tooltip-container';
import {userBuilder, organizationBuilder} from '../builder/graphql/user';

import ownerQuery from '../../lib/containers/__generated__/userMentionTooltipContainer_repositoryOwner.graphql';

describe('UserMentionTooltipContainer', function() {
  function buildApp(override = {}) {
    const props = {
      ...override,
    };

    return <BareUserMentionTooltipContainer {...props} />;
  }

  it('renders information about a User', function() {
    const wrapper = shallow(buildApp({
      repositoryOwner: userBuilder(ownerQuery)
        .login('someone')
        .avatarUrl('https://i.redd.it/03xcogvbr6v21.jpg')
        .company('Infinity, Ltd.')
        .repositories(conn => conn.totalCount(5))
        .build(),
    }));

    assert.strictEqual(wrapper.find('img').prop('src'), 'https://i.redd.it/03xcogvbr6v21.jpg');
    assert.isTrue(wrapper.find('span').someWhere(s => s.text() === 'Infinity, Ltd.'));
    assert.isTrue(wrapper.find('span').someWhere(s => s.text() === '5 repositories'));
  });

  it('renders information about an Organization', function() {
    const wrapper = shallow(buildApp({
      repositoryOwner: organizationBuilder(ownerQuery)
        .login('acme')
        .avatarUrl('https://i.redd.it/eekf8onik0v21.jpg')
        .membersWithRole(conn => conn.totalCount(10))
        .repositories(conn => conn.totalCount(5))
        .build(),
    }));

    assert.strictEqual(wrapper.find('img').prop('src'), 'https://i.redd.it/eekf8onik0v21.jpg');
    assert.isTrue(wrapper.find('span').someWhere(s => s.text() === '10 members'));
    assert.isTrue(wrapper.find('span').someWhere(s => s.text() === '5 repositories'));
  });
});
