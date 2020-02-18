import React from 'react';
import {shallow} from 'enzyme';

import ChangedFilesCountView from '../../lib/views/changed-files-count-view';
import * as reporterProxy from '../../lib/reporter-proxy';

describe('ChangedFilesCountView', function() {
  let wrapper;

  it('renders diff icon', function() {
    wrapper = shallow(<ChangedFilesCountView />);
    assert.isTrue(wrapper.html().includes('git-commit'));
  });

  it('renders merge conflict icon if there is a merge conflict', function() {
    wrapper = shallow(<ChangedFilesCountView mergeConflictsPresent={true} />);
    assert.isTrue(wrapper.html().includes('icon-alert'));
  });

  it('renders singular count for one file', function() {
    wrapper = shallow(<ChangedFilesCountView changedFilesCount={1} />);
    assert.isTrue(wrapper.text().includes('Git (1)'));
  });

  it('renders multiple count if more than one file', function() {
    wrapper = shallow(<ChangedFilesCountView changedFilesCount={2} />);
    assert.isTrue(wrapper.text().includes('Git (2)'));
  });

  it('records an event on click', function() {
    sinon.stub(reporterProxy, 'addEvent');
    wrapper = shallow(<ChangedFilesCountView />);
    wrapper.simulate('click');
    assert.isTrue(reporterProxy.addEvent.calledWith('click', {package: 'github', component: 'ChangedFileCountView'}));
  });
});
