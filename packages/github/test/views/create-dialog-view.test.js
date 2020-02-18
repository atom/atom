import React from 'react';
import {shallow} from 'enzyme';
import {TextBuffer} from 'atom';

import CreateDialogView from '../../lib/views/create-dialog-view';
import RepositoryHomeSelectionView from '../../lib/views/repository-home-selection-view';
import {dialogRequests} from '../../lib/controllers/dialogs-controller';

describe('CreateDialogView', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    return (
      <CreateDialogView
        request={dialogRequests.create()}
        isLoading={false}
        inProgress={false}
        selectedOwnerID="user-id"
        repoName={new TextBuffer()}
        selectedVisibility="PUBLIC"
        localPath={new TextBuffer()}
        sourceRemoteName={new TextBuffer()}
        selectedProtocol="https"
        didChangeOwnerID={() => {}}
        didChangeVisibility={() => {}}
        didChangeProtocol={() => {}}
        acceptEnabled={true}
        accept={() => {}}
        currentWindow={atomEnv.getCurrentWindow()}
        workspace={atomEnv.workspace}
        commands={atomEnv.commands}
        config={atomEnv.config}
        {...override}
      />
    );
  }

  it('renders in a loading state when no relay data is available', function() {
    const wrapper = shallow(buildApp({user: null, isLoading: true}));

    const homeView = wrapper.find(RepositoryHomeSelectionView);
    assert.isNull(homeView.prop('user'));
    assert.isTrue(homeView.prop('isLoading'));
  });

  it('customizes dialog text in create mode', function() {
    const createRequest = dialogRequests.create();
    const wrapper = shallow(buildApp({request: createRequest}));

    assert.include(wrapper.find('.github-Create-header').text(), 'Create GitHub repository');
    assert.isFalse(wrapper.find('DirectorySelect').prop('disabled'));
    assert.strictEqual(wrapper.find('DialogView').prop('acceptText'), 'Create');
  });

  it('customizes dialog text and disables local directory controls in publish mode', function() {
    const publishRequest = dialogRequests.publish({localDir: '/local/directory'});
    const localPath = new TextBuffer({text: '/local/directory'});
    const wrapper = shallow(buildApp({request: publishRequest, localPath}));

    assert.include(wrapper.find('.github-Create-header').text(), 'Publish GitHub repository');
    assert.isTrue(wrapper.find('DirectorySelect').prop('disabled'));
    assert.strictEqual(wrapper.find('DirectorySelect').prop('buffer').getText(), '/local/directory');
    assert.strictEqual(wrapper.find('DialogView').prop('acceptText'), 'Publish');
  });
});
