import React from 'react';
import {shallow} from 'enzyme';
import {shell} from 'electron';

import BranchSet from '../../lib/models/branch-set';
import Branch, {nullBranch} from '../../lib/models/branch';
import Remote from '../../lib/models/remote';
import RemoteSet from '../../lib/models/remote-set';
import {getEndpoint} from '../../lib/models/endpoint';
import RemoteController from '../../lib/controllers/remote-controller';
import * as reporterProxy from '../../lib/reporter-proxy';

describe('RemoteController', function() {
  let atomEnv, remote, remoteSet, currentBranch, branchSet;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();

    remote = new Remote('origin', 'git@github.com:atom/github');
    remoteSet = new RemoteSet([remote]);
    currentBranch = new Branch('master', nullBranch, nullBranch, true);
    branchSet = new BranchSet();
    branchSet.add(currentBranch);
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function createApp(props = {}) {
    return (
      <RemoteController
        repository={null}

        endpoint={getEndpoint('github.com')}
        token="1234"

        workingDirectory={__dirname}
        workspace={atomEnv.workspace}
        remote={remote}
        remotes={remoteSet}
        branches={branchSet}
        aheadCount={0}
        pushInProgress={false}

        onPushBranch={() => {}}

        {...props}
      />
    );
  }

  it('increments a counter when onCreatePr is called', async function() {
    const wrapper = shallow(createApp());
    sinon.stub(shell, 'openExternal').callsArg(2);
    sinon.stub(reporterProxy, 'incrementCounter');

    await wrapper.instance().onCreatePr();
    assert.equal(reporterProxy.incrementCounter.callCount, 1);
    assert.deepEqual(reporterProxy.incrementCounter.lastCall.args, ['create-pull-request']);
  });

  it('handles error when onCreatePr fails', async function() {
    const wrapper = shallow(createApp());
    sinon.stub(shell, 'openExternal').callsArgWith(2, new Error('oh noes'));
    sinon.stub(reporterProxy, 'incrementCounter');

    try {
      await wrapper.instance().onCreatePr();
    } catch (err) {
      assert.equal(err.message, 'oh noes');
    }
    assert.equal(reporterProxy.incrementCounter.callCount, 0);
  });

  it('renders issueish searches', function() {
    const wrapper = shallow(createApp());

    const controller = wrapper.update().find('IssueishSearchesController');
    assert.strictEqual(controller.prop('token'), '1234');
    assert.strictEqual(controller.prop('endpoint').getHost(), 'github.com');
    assert.strictEqual(controller.prop('remote'), remote);
    assert.strictEqual(controller.prop('branches'), branchSet);
  });
});
