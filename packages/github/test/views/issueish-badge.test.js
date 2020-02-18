import React from 'react';
import {shallow} from 'enzyme';

import IssueishBadge from '../../lib/views/issueish-badge';

describe('IssueishBadge', function() {
  function buildApp(overloadProps = {}) {
    return (
      <IssueishBadge
        type="Issue"
        state="OPEN"
        {...overloadProps}
      />
    );
  }

  it('applies a className and any other properties to the span', function() {
    const extra = Symbol('extra');
    const wrapper = shallow(buildApp({
      className: 'added',
      state: 'CLOSED',
      extra,
    }));

    const span = wrapper.find('span.github-IssueishBadge');
    assert.isTrue(span.hasClass('added'));
    assert.isTrue(span.hasClass('closed'));
    assert.strictEqual(span.prop('extra'), extra);
  });

  it('renders an appropriate icon', function() {
    const wrapper = shallow(buildApp({type: 'Issue', state: 'OPEN'}));
    assert.isTrue(wrapper.find('Octicon[icon="issue-opened"]').exists());
    assert.match(wrapper.text(), /open$/);

    wrapper.setProps({type: 'Issue', state: 'CLOSED'});
    assert.isTrue(wrapper.find('Octicon[icon="issue-closed"]').exists());
    assert.match(wrapper.text(), /closed$/);

    wrapper.setProps({type: 'PullRequest', state: 'OPEN'});
    assert.isTrue(wrapper.find('Octicon[icon="git-pull-request"]').exists());
    assert.match(wrapper.text(), /open$/);

    wrapper.setProps({type: 'PullRequest', state: 'CLOSED'});
    assert.isTrue(wrapper.find('Octicon[icon="git-pull-request"]').exists());
    assert.match(wrapper.text(), /closed$/);

    wrapper.setProps({type: 'PullRequest', state: 'MERGED'});
    assert.isTrue(wrapper.find('Octicon[icon="git-merge"]').exists());
    assert.match(wrapper.text(), /merged$/);

    wrapper.setProps({type: 'Unknown', state: 'OPEN'});
    assert.isTrue(wrapper.find('Octicon[icon="question"]').exists());
    assert.match(wrapper.text(), /open$/);

    wrapper.setProps({type: 'PullRequest', state: 'UNKNOWN'});
    assert.isTrue(wrapper.find('Octicon[icon="question"]').exists());
    assert.match(wrapper.text(), /unknown$/);
  });
});
