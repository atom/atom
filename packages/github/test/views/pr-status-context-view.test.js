import React from 'react';
import {shallow} from 'enzyme';

import {BarePrStatusContextView} from '../../lib/views/pr-status-context-view';
import {contextBuilder} from '../builder/graphql/timeline';

import contextQuery from '../../lib/views/__generated__/prStatusContextView_context.graphql';

describe('PrStatusContextView', function() {
  function buildApp(override = {}) {
    const props = {
      context: contextBuilder(contextQuery).build(),
      ...override,
    };
    return <BarePrStatusContextView {...props} />;
  }

  it('renders an octicon corresponding to the status context state', function() {
    const context = contextBuilder(contextQuery)
      .state('ERROR')
      .build();
    const wrapper = shallow(buildApp({context}));
    assert.isTrue(wrapper.find('Octicon[icon="alert"]').hasClass('github-PrStatuses--failure'));
  });

  it('renders the context name and description', function() {
    const context = contextBuilder(contextQuery)
      .context('the context')
      .description('the description')
      .build();

    const wrapper = shallow(buildApp({context}));
    assert.match(wrapper.find('.github-PrStatuses-list-item-context').text(), /the context/);
    assert.match(wrapper.find('.github-PrStatuses-list-item-context').text(), /the description/);
  });

  it('renders a link to the details', function() {
    const context = contextBuilder(contextQuery)
      .targetUrl('https://ci.provider.com/builds/123')
      .build();

    const wrapper = shallow(buildApp({context}));
    assert.strictEqual(
      wrapper.find('.github-PrStatuses-list-item-details-link a').prop('href'),
      'https://ci.provider.com/builds/123',
    );
  });
});
