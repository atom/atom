import React from 'react';
import {shallow} from 'enzyme';

import {BareCheckRunView} from '../../lib/views/check-run-view';
import {checkRunBuilder} from '../builder/graphql/timeline';

import checkRunQuery from '../../lib/views/__generated__/checkRunView_checkRun.graphql';

describe('CheckRunView', function() {
  function buildApp(override = {}) {
    const props = {
      checkRun: checkRunBuilder(checkRunQuery).build(),
      switchToIssueish: () => {},
      ...override,
    };

    return <BareCheckRunView {...props} />;
  }

  it('renders check run information', function() {
    const checkRun = checkRunBuilder(checkRunQuery)
      .status('COMPLETED')
      .conclusion('FAILURE')
      .name('some check run')
      .permalink('https://github.com/atom/github/runs/1111')
      .detailsUrl('https://ci.com/job/123')
      .title('this is the title')
      .summary('some stuff happened')
      .build();

    const wrapper = shallow(buildApp({checkRun}));

    const icon = wrapper.find('Octicon');
    assert.strictEqual(icon.prop('icon'), 'x');
    assert.isTrue(icon.hasClass('github-PrStatuses--failure'));

    assert.strictEqual(wrapper.find('a.github-PrStatuses-list-item-name').text(), 'some check run');
    assert.strictEqual(wrapper.find('a.github-PrStatuses-list-item-name').prop('href'), 'https://github.com/atom/github/runs/1111');

    assert.strictEqual(wrapper.find('.github-PrStatuses-list-item-title').text(), 'this is the title');

    assert.strictEqual(wrapper.find('.github-PrStatuses-list-item-summary').prop('markdown'), 'some stuff happened');

    assert.strictEqual(wrapper.find('.github-PrStatuses-list-item-details-link').text(), 'Details');
    assert.strictEqual(wrapper.find('.github-PrStatuses-list-item-details-link').prop('href'), 'https://ci.com/job/123');
  });

  it('omits optional fields that are absent', function() {
    const checkRun = checkRunBuilder(checkRunQuery)
      .status('IN_PROGRESS')
      .name('some check run')
      .permalink('https://github.com/atom/github/runs/1111')
      .nullTitle()
      .nullSummary()
      .build();

    const wrapper = shallow(buildApp({checkRun}));
    assert.isFalse(wrapper.exists('.github-PrStatuses-list-item-title'));
    assert.isFalse(wrapper.exists('.github-PrStatuses-list-item-summary'));
  });

  it('handles issueish navigation from links in the build summary', function() {
    const checkRun = checkRunBuilder(checkRunQuery)
      .summary('#1234')
      .build();

    const switchToIssueish = sinon.spy();
    const wrapper = shallow(buildApp({switchToIssueish, checkRun}));

    wrapper.find('GithubDotcomMarkdown').prop('switchToIssueish')();
    assert.isTrue(switchToIssueish.called);
  });
});
