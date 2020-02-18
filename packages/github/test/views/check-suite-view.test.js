import React from 'react';
import {shallow} from 'enzyme';

import {BareCheckSuiteView} from '../../lib/views/check-suite-view';
import CheckRunView from '../../lib/views/check-run-view';

import checkSuiteQuery from '../../lib/views/__generated__/checkSuiteView_checkSuite.graphql';
import {checkSuiteBuilder} from '../builder/graphql/timeline';

describe('CheckSuiteView', function() {
  function buildApp(override = {}) {
    const props = {
      checkSuite: checkSuiteBuilder(checkSuiteQuery).build(),
      checkRuns: [],
      switchToIssueish: () => {},
      ...override,
    };

    return <BareCheckSuiteView {...props} />;
  }

  it('renders the summarized suite information', function() {
    const checkSuite = checkSuiteBuilder(checkSuiteQuery)
      .app(a => a.name('app'))
      .status('COMPLETED')
      .conclusion('SUCCESS')
      .build();

    const wrapper = shallow(buildApp({checkSuite}));

    const icon = wrapper.find('Octicon');
    assert.strictEqual(icon.prop('icon'), 'check');
    assert.isTrue(icon.hasClass('github-PrStatuses--success'));

    assert.strictEqual(wrapper.find('.github-PrStatuses-list-item-context strong').text(), 'app');
  });

  it('omits app information when the app is no longer present', function() {
    const checkSuite = checkSuiteBuilder(checkSuiteQuery)
      .nullApp()
      .build();

    const wrapper = shallow(buildApp({checkSuite}));

    assert.isTrue(wrapper.exists('Octicon'));
    assert.isFalse(wrapper.exists('.github-PrStatuses-list-item-context'));
  });

  it('renders a CheckRun for each run within the suite', function() {
    const checkRuns = [{id: 0}, {id: 1}, {id: 2}];

    const wrapper = shallow(buildApp({checkRuns}));
    assert.deepEqual(wrapper.find(CheckRunView).map(v => v.prop('checkRun')), checkRuns);
  });
});
