import React from 'react';
import {shallow} from 'enzyme';
import path from 'path';

import {BareCreateDialogController} from '../../lib/controllers/create-dialog-controller';
import CreateDialogView from '../../lib/views/create-dialog-view';
import {dialogRequests} from '../../lib/controllers/dialogs-controller';
import {userBuilder} from '../builder/graphql/user';
import userQuery from '../../lib/controllers/__generated__/createDialogController_user.graphql';

describe('CreateDialogController', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();

    atomEnv.config.set('core.projectHome', path.join('/home/me/src'));
    atomEnv.config.set('github.sourceRemoteName', 'origin');
    atomEnv.config.set('github.remoteFetchProtocol', 'https');
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    return (
      <BareCreateDialogController
        user={userBuilder(userQuery).build()}
        request={dialogRequests.create()}
        isLoading={false}
        inProgress={false}
        currentWindow={atomEnv.getCurrentWindow()}
        workspace={atomEnv.workspace}
        commands={atomEnv.commands}
        config={atomEnv.config}
        {...override}
      />
    );
  }

  it('synchronizes the source remote name from Atom configuration', function() {
    const wrapper = shallow(buildApp());
    const buffer = wrapper.find(CreateDialogView).prop('sourceRemoteName');
    assert.strictEqual(buffer.getText(), 'origin');

    atomEnv.config.set('github.sourceRemoteName', 'upstream');
    assert.strictEqual(buffer.getText(), 'upstream');

    buffer.setText('home');
    assert.strictEqual(atomEnv.config.get('github.sourceRemoteName'), 'home');

    sinon.spy(atomEnv.config, 'set');
    buffer.setText('home');
    assert.isFalse(atomEnv.config.set.called);

    wrapper.unmount();
  });

  it('synchronizes the source protocol from Atom configuration', async function() {
    const wrapper = shallow(buildApp());
    assert.strictEqual(wrapper.find(CreateDialogView).prop('selectedProtocol'), 'https');

    atomEnv.config.set('github.remoteFetchProtocol', 'ssh');
    assert.strictEqual(wrapper.find(CreateDialogView).prop('selectedProtocol'), 'ssh');

    await wrapper.find(CreateDialogView).prop('didChangeProtocol')('https');
    assert.strictEqual(atomEnv.config.get('github.remoteFetchProtocol'), 'https');

    sinon.spy(atomEnv.config, 'set');
    await wrapper.find(CreateDialogView).prop('didChangeProtocol')('https');
    assert.isFalse(atomEnv.config.set.called);
  });

  it('begins with an empty owner ID while loading', function() {
    const wrapper = shallow(buildApp({user: null, isLoading: true}));

    assert.strictEqual(wrapper.find(CreateDialogView).prop('selectedOwnerID'), '');
  });

  it('begins with the owner ID as the viewer ID', function() {
    const user = userBuilder(userQuery)
      .id('user0')
      .build();
    const wrapper = shallow(buildApp({user}));

    assert.strictEqual(wrapper.find(CreateDialogView).prop('selectedOwnerID'), 'user0');
  });

  describe('initial repository name', function() {
    it('is empty if the initial local path is unspecified', function() {
      const request = dialogRequests.create();
      const wrapper = shallow(buildApp({request}));
      assert.isTrue(wrapper.find(CreateDialogView).prop('repoName').isEmpty());
    });

    it('is the base name of the initial local path', function() {
      const request = dialogRequests.publish({localDir: path.join('/local/directory')});
      const wrapper = shallow(buildApp({request}));
      assert.strictEqual(wrapper.find(CreateDialogView).prop('repoName').getText(), 'directory');
    });
  });

  describe('initial local path', function() {
    it('is the project home directory if unspecified', function() {
      const request = dialogRequests.create();
      const wrapper = shallow(buildApp({request}));
      assert.strictEqual(wrapper.find(CreateDialogView).prop('localPath').getText(), path.join('/home/me/src'));
    });

    it('is the provided path from the dialog request', function() {
      const request = dialogRequests.publish({localDir: path.join('/local/directory')});
      const wrapper = shallow(buildApp({request}));
      assert.strictEqual(wrapper.find(CreateDialogView).prop('localPath').getText(), path.join('/local/directory'));
    });
  });

  describe('repository name and local path name feedback', function() {
    it('matches the repository name to the local path basename when the local path is modified and the repository name is not', function() {
      const wrapper = shallow(buildApp());
      assert.isTrue(wrapper.find(CreateDialogView).prop('repoName').isEmpty());

      wrapper.find(CreateDialogView).prop('localPath').setText(path.join('/local/directory'));
      assert.strictEqual(wrapper.find(CreateDialogView).prop('repoName').getText(), 'directory');
    });

    it('leaves the repository name unchanged if it has been modified', function() {
      const wrapper = shallow(buildApp());
      wrapper.find(CreateDialogView).prop('repoName').setText('repo-name');

      wrapper.find(CreateDialogView).prop('localPath').setText(path.join('/local/directory'));
      assert.strictEqual(wrapper.find(CreateDialogView).prop('repoName').getText(), 'repo-name');
    });

    it('matches the local path basename to the repository name when the repository name is modified and the local path is not', function() {
      const wrapper = shallow(buildApp());
      assert.strictEqual(wrapper.find(CreateDialogView).prop('localPath').getText(), path.join('/home/me/src'));

      wrapper.find(CreateDialogView).prop('repoName').setText('the-repo');
      assert.strictEqual(wrapper.find(CreateDialogView).prop('localPath').getText(), path.join('/home/me/src/the-repo'));

      wrapper.find(CreateDialogView).prop('repoName').setText('different-name');
      assert.strictEqual(wrapper.find(CreateDialogView).prop('localPath').getText(), path.join('/home/me/src/different-name'));
    });

    it('leaves the local path unchanged if it has been modified', function() {
      const wrapper = shallow(buildApp());
      wrapper.find(CreateDialogView).prop('localPath').setText(path.join('/some/local/directory'));

      wrapper.find(CreateDialogView).prop('repoName').setText('the-repo');
      assert.strictEqual(wrapper.find(CreateDialogView).prop('localPath').getText(), path.join('/some/local/directory'));
    });
  });

  describe('accept enablement', function() {
    it('enabled the accept button when all data is present and non-empty', function() {
      const wrapper = shallow(buildApp());

      wrapper.find(CreateDialogView).prop('repoName').setText('the-repo');
      wrapper.find(CreateDialogView).prop('localPath').setText(path.join('/local/path'));

      assert.isTrue(wrapper.find(CreateDialogView).prop('acceptEnabled'));
    });

    it('disables the accept button if the repo name is empty', function() {
      const wrapper = shallow(buildApp());

      wrapper.find(CreateDialogView).prop('repoName').setText('zzz');
      wrapper.find(CreateDialogView).prop('repoName').setText('');
      wrapper.find(CreateDialogView).prop('localPath').setText(path.join('/local/path'));

      assert.isFalse(wrapper.find(CreateDialogView).prop('acceptEnabled'));
    });

    it('disables the accept button if the local path is empty', function() {
      const wrapper = shallow(buildApp());

      wrapper.find(CreateDialogView).prop('repoName').setText('the-repo');
      wrapper.find(CreateDialogView).prop('localPath').setText('');

      assert.isFalse(wrapper.find(CreateDialogView).prop('acceptEnabled'));
    });

    it('disables the accept button if the source remote name is empty', function() {
      const wrapper = shallow(buildApp());

      wrapper.find(CreateDialogView).prop('sourceRemoteName').setText('');

      assert.isFalse(wrapper.find(CreateDialogView).prop('acceptEnabled'));
    });

    it('disables the accept button if user data has not loaded yet', function() {
      const wrapper = shallow(buildApp({user: null}));

      assert.isFalse(wrapper.find(CreateDialogView).prop('acceptEnabled'));
    });

    it('enables the accept button when user data loads', function() {
      const wrapper = shallow(buildApp({user: null}));
      wrapper.find(CreateDialogView).prop('repoName').setText('the-repo');
      wrapper.find(CreateDialogView).prop('localPath').setText(path.join('/local/path'));

      assert.isFalse(wrapper.find(CreateDialogView).prop('acceptEnabled'));

      wrapper.setProps({user: userBuilder(userQuery).build()});
      assert.isTrue(wrapper.find(CreateDialogView).prop('acceptEnabled'));

      wrapper.setProps({});
      assert.isTrue(wrapper.find(CreateDialogView).prop('acceptEnabled'));
    });
  });

  describe('acceptance', function() {
    it('does nothing if insufficient data is available', async function() {
      const accept = sinon.spy();
      const request = dialogRequests.create();
      request.onAccept(accept);
      const wrapper = shallow(buildApp({request}));

      wrapper.find(CreateDialogView).prop('repoName').setText('');
      await wrapper.find(CreateDialogView).prop('accept')();

      assert.isFalse(accept.called);
    });

    it('uses the user ID if the selected owner ID was never changed', async function() {
      const accept = sinon.spy();
      const request = dialogRequests.create();
      request.onAccept(accept);
      const wrapper = shallow(buildApp({request, user: null, isLoading: true}));

      assert.strictEqual(wrapper.find(CreateDialogView).prop('selectedOwnerID'), '');

      wrapper.setProps({
        user: userBuilder(userQuery).id('my-id').build(),
        isLoading: false,
      });

      wrapper.find(CreateDialogView).prop('repoName').setText('repo-name');
      wrapper.find(CreateDialogView).prop('didChangeVisibility')('PRIVATE');
      wrapper.find(CreateDialogView).prop('localPath').setText(path.join('/local/path'));
      wrapper.find(CreateDialogView).prop('didChangeProtocol')('ssh');
      wrapper.find(CreateDialogView).prop('sourceRemoteName').setText('upstream');

      assert.strictEqual(wrapper.find(CreateDialogView).prop('selectedOwnerID'), '');

      await wrapper.find(CreateDialogView).prop('accept')();

      assert.isTrue(accept.calledWith({
        ownerID: 'my-id',
        name: 'repo-name',
        visibility: 'PRIVATE',
        localPath: path.join('/local/path'),
        protocol: 'ssh',
        sourceRemoteName: 'upstream',
      }));
    });

    it('resolves onAccept with the populated data', async function() {
      const accept = sinon.spy();
      const request = dialogRequests.create();
      request.onAccept(accept);
      const wrapper = shallow(buildApp({request}));

      wrapper.find(CreateDialogView).prop('didChangeOwnerID')('org-id');
      wrapper.find(CreateDialogView).prop('repoName').setText('repo-name');
      wrapper.find(CreateDialogView).prop('didChangeVisibility')('PRIVATE');
      wrapper.find(CreateDialogView).prop('localPath').setText(path.join('/local/path'));
      wrapper.find(CreateDialogView).prop('didChangeProtocol')('ssh');
      wrapper.find(CreateDialogView).prop('sourceRemoteName').setText('upstream');

      await wrapper.find(CreateDialogView).prop('accept')();

      assert.isTrue(accept.calledWith({
        ownerID: 'org-id',
        name: 'repo-name',
        visibility: 'PRIVATE',
        localPath: path.join('/local/path'),
        protocol: 'ssh',
        sourceRemoteName: 'upstream',
      }));
    });
  });
});
