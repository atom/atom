import React from 'react';
import {shallow} from 'enzyme';

import GithubTileView from '../../lib/views/github-tile-view';
import * as reporterProxy from '../../lib/reporter-proxy';

describe('GithubTileView', function() {
  let wrapper, clickSpy;
  beforeEach(function() {
    clickSpy = sinon.spy();
    wrapper = shallow(<GithubTileView didClick={clickSpy} />);
  });

  it('renders github icon and text', function() {
    assert.isTrue(wrapper.html().includes('mark-github'));
    assert.isTrue(wrapper.text().includes('GitHub'));
  });

  it('calls props.didClick when clicked', function() {
    wrapper.simulate('click');
    assert.isTrue(clickSpy.calledOnce);
  });

  it('records an event on click', function() {
    sinon.stub(reporterProxy, 'addEvent');
    wrapper.simulate('click');
    assert.isTrue(reporterProxy.addEvent.calledWith('click', {package: 'github', component: 'GithubTileView'}));
  });
});
