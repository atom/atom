import React from 'react';
import {shallow} from 'enzyme';

import OpenCommitDialog, {openCommitDetailItem} from '../../lib/views/open-commit-dialog';
import {dialogRequests} from '../../lib/controllers/dialogs-controller';
import CommitDetailItem from '../../lib/items/commit-detail-item';
import {GitError} from '../../lib/git-shell-out-strategy';
import {TabbableTextEditor} from '../../lib/views/tabbable';
import * as reporterProxy from '../../lib/reporter-proxy';

describe('OpenCommitDialog', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function isValidRef(ref) {
    return Promise.resolve(/^abcd/.test(ref));
  }

  function buildApp(overrides = {}) {
    const request = dialogRequests.commit();

    return (
      <OpenCommitDialog
        request={request}
        inProgress={false}
        isValidRef={isValidRef}
        workspace={atomEnv.workspace}
        commands={atomEnv.commands}
        {...overrides}
      />
    );
  }

  describe('open button enablement', function() {
    it('disables the open button with no commit ref', function() {
      const wrapper = shallow(buildApp());

      assert.isFalse(wrapper.find('DialogView').prop('acceptEnabled'));
    });

    it('enables the open button when commit sha box is populated', function() {
      const wrapper = shallow(buildApp());
      wrapper.find(TabbableTextEditor).prop('buffer').setText('abcd1234');

      assert.isTrue(wrapper.find('DialogView').prop('acceptEnabled'));

      wrapper.find(TabbableTextEditor).prop('buffer').setText('abcd6789');
      assert.isTrue(wrapper.find('DialogView').prop('acceptEnabled'));
    });
  });

  it('calls the acceptance callback with the entered ref', function() {
    const accept = sinon.spy();
    const request = dialogRequests.commit();
    request.onAccept(accept);

    const wrapper = shallow(buildApp({request}));
    wrapper.find(TabbableTextEditor).prop('buffer').setText('abcd1234');
    wrapper.find('DialogView').prop('accept')();

    assert.isTrue(accept.calledWith('abcd1234'));
    wrapper.unmount();
  });

  it('does nothing on accept if the ref is empty', async function() {
    const accept = sinon.spy();
    const request = dialogRequests.commit();
    request.onAccept(accept);

    const wrapper = shallow(buildApp({request}));
    await wrapper.find('DialogView').prop('accept')();

    assert.isFalse(accept.called);
  });

  it('calls the cancellation callback', function() {
    const cancel = sinon.spy();
    const request = dialogRequests.commit();
    request.onCancel(cancel);

    const wrapper = shallow(buildApp({request}));

    wrapper.find('DialogView').prop('cancel')();
    assert.isTrue(cancel.called);
  });

  describe('openCommitDetailItem()', function() {
    let repository;

    beforeEach(function() {
      sinon.stub(atomEnv.workspace, 'open').resolves('item');
      sinon.stub(reporterProxy, 'addEvent');

      repository = {
        getWorkingDirectoryPath() {
          return __dirname;
        },
        getCommit(ref) {
          if (ref === 'abcd1234') {
            return Promise.resolve('ok');
          }

          if (ref === 'bad') {
            const e = new GitError('bad ref');
            e.code = 128;
            return Promise.reject(e);
          }

          return Promise.reject(new GitError('other error'));
        },
      };
    });

    it('opens a CommitDetailItem with the chosen valid ref and records an event', async function() {
      assert.strictEqual(await openCommitDetailItem('abcd1234', {workspace: atomEnv.workspace, repository}), 'item');
      assert.isTrue(atomEnv.workspace.open.calledWith(
        CommitDetailItem.buildURI(__dirname, 'abcd1234'),
        {searchAllPanes: true},
      ));
      assert.isTrue(reporterProxy.addEvent.calledWith(
        'open-commit-in-pane',
        {package: 'github', from: OpenCommitDialog.name},
      ));
    });

    it('raises a friendly error if the ref is invalid', async function() {
      const e = await openCommitDetailItem('bad', {workspace: atomEnv.workspace, repository}).then(
        () => { throw new Error('unexpected success'); },
        error => error,
      );
      assert.strictEqual(e.userMessage, 'There is no commit associated with that reference.');
    });

    it('passes other errors through directly', async function() {
      const e = await openCommitDetailItem('nope', {workspace: atomEnv.workspace, repository}).then(
        () => { throw new Error('unexpected success'); },
        error => error,
      );
      assert.isUndefined(e.userMessage);
      assert.strictEqual(e.message, 'other error');
    });
  });
});
