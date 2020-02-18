import React from 'react';
import {shallow} from 'enzyme';

import Remote from '../../lib/models/remote';
import RemoteSet from '../../lib/models/remote-set';
import Branch, {nullBranch} from '../../lib/models/branch';
import RemoteSelectorView from '../../lib/views/remote-selector-view';

describe('RemoteSelectorView', function() {
  function buildApp(overrideProps = {}) {
    const props = {
      remotes: new RemoteSet(),
      currentBranch: nullBranch,
      selectRemote: () => {},
      ...overrideProps,
    };

    return <RemoteSelectorView {...props} />;
  }

  it('shows the current branch name', function() {
    const currentBranch = new Branch('aaa');
    const wrapper = shallow(buildApp({currentBranch}));
    assert.strictEqual(wrapper.find('strong').text(), 'aaa');
  });

  it('renders each remote', function() {
    const remote0 = new Remote('zero', 'git@github.com:aaa/bbb.git');
    const remote1 = new Remote('one', 'git@github.com:ccc/ddd.git');
    const remotes = new RemoteSet([remote0, remote1]);
    const selectRemote = sinon.spy();

    const wrapper = shallow(buildApp({remotes, selectRemote}));

    const zero = wrapper.find('li').filterWhere(w => w.key() === 'zero').find('button');
    assert.strictEqual(zero.text(), 'zero (aaa/bbb)');
    zero.simulate('click', 'event0');
    assert.isTrue(selectRemote.calledWith('event0', remote0));

    const one = wrapper.find('li').filterWhere(w => w.key() === 'one').find('button');
    assert.strictEqual(one.text(), 'one (ccc/ddd)');
    one.simulate('click', 'event1');
    assert.isTrue(selectRemote.calledWith('event1', remote1));
  });
});
