import React from 'react';
import {shallow} from 'enzyme';

import OpenIssueishDialog, {openIssueishItem} from '../../lib/views/open-issueish-dialog';
import IssueishDetailItem from '../../lib/items/issueish-detail-item';
import {dialogRequests} from '../../lib/controllers/dialogs-controller';
import * as reporterProxy from '../../lib/reporter-proxy';

describe('OpenIssueishDialog', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    sinon.stub(reporterProxy, 'addEvent').returns();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrides = {}) {
    const request = dialogRequests.issueish();

    return (
      <OpenIssueishDialog
        request={request}
        inProgress={false}
        workspace={atomEnv.workspace}
        commands={atomEnv.commands}
        {...overrides}
      />
    );
  }

  describe('open button enablement', function() {
    it('disables the open button with no issue url', function() {
      const wrapper = shallow(buildApp());

      wrapper.find('.github-OpenIssueish-url').prop('buffer').setText('');
      assert.isFalse(wrapper.find('DialogView').prop('acceptEnabled'));
    });

    it('enables the open button when issue url box is populated', function() {
      const wrapper = shallow(buildApp());
      wrapper.find('.github-OpenIssueish-url').prop('buffer').setText('https://github.com/atom/github/pull/1807');

      assert.isTrue(wrapper.find('DialogView').prop('acceptEnabled'));
    });
  });

  it('calls the acceptance callback with the entered URL', function() {
    const accept = sinon.spy();
    const request = dialogRequests.issueish();
    request.onAccept(accept);
    const wrapper = shallow(buildApp({request}));
    wrapper.find('.github-OpenIssueish-url').prop('buffer').setText('https://github.com/atom/github/pull/1807');
    wrapper.find('DialogView').prop('accept')();

    assert.isTrue(accept.calledWith('https://github.com/atom/github/pull/1807'));
  });

  it('calls the cancellation callback', function() {
    const cancel = sinon.spy();
    const request = dialogRequests.issueish();
    request.onCancel(cancel);
    const wrapper = shallow(buildApp({request}));
    wrapper.find('DialogView').prop('cancel')();

    assert.isTrue(cancel.called);
  });

  describe('openIssueishItem', function() {
    it('opens an item for a valid issue URL', async function() {
      sinon.stub(atomEnv.workspace, 'open').resolves('item');
      assert.strictEqual(
        await openIssueishItem('https://github.com/atom/github/issues/2203', {
          workspace: atomEnv.workspace, workdir: __dirname,
        }),
        'item',
      );
      assert.isTrue(atomEnv.workspace.open.calledWith(
        IssueishDetailItem.buildURI({
          host: 'github.com', owner: 'atom', repo: 'github', number: 2203, workdir: __dirname,
        }),
      ));
    });

    it('opens an item for a valid PR URL', async function() {
      sinon.stub(atomEnv.workspace, 'open').resolves('item');
      assert.strictEqual(
        await openIssueishItem('https://github.com/smashwilson/az-coordinator/pull/10', {
          workspace: atomEnv.workspace, workdir: __dirname,
        }),
        'item',
      );
      assert.isTrue(atomEnv.workspace.open.calledWith(
        IssueishDetailItem.buildURI({
          host: 'github.com', owner: 'smashwilson', repo: 'az-coordinator', number: 10, workdir: __dirname,
        }),
      ));
    });

    it('rejects with an error for an invalid URL', async function() {
      await assert.isRejected(
        openIssueishItem('https://azurefire.net/not-an-issue', {workspace: atomEnv.workspace, workdir: __dirname}),
        'Not a valid issue or pull request URL',
      );
    });
  });
});
