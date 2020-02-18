import React from 'react';
import {shallow} from 'enzyme';

import DialogsController, {dialogRequests} from '../../lib/controllers/dialogs-controller';
import GithubLoginModel from '../../lib/models/github-login-model';
import {InMemoryStrategy} from '../../lib/shared/keytar-strategy';

describe('DialogsController', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrides = {}) {
    return (
      <DialogsController
        loginModel={new GithubLoginModel(InMemoryStrategy)}
        request={dialogRequests.null}
        inProgress={false}
        currentWindow={atomEnv.getCurrentWindow()}
        workspace={atomEnv.workspace}
        commands={atomEnv.commands}
        config={atomEnv.config}
        {...overrides}
      />
    );
  }

  it('renders nothing when a nullDialogRequest is provided', function() {
    const wrapper = shallow(buildApp({
      request: dialogRequests.null,
    }));
    assert.isTrue(wrapper.exists('NullDialog'));
  });

  it('renders a chosen dialog when the appropriate DialogRequest is provided', function() {
    const wrapper = shallow(buildApp({
      request: dialogRequests.init({dirPath: __dirname}),
    }));
    assert.isTrue(wrapper.exists('InitDialog'));
  });

  it('passes inProgress to the dialog when the accept callback is asynchronous', async function() {
    let completeWork = () => {};
    const workPromise = new Promise(resolve => {
      completeWork = resolve;
    });
    const accept = sinon.stub().returns(workPromise);

    const request = dialogRequests.init({dirPath: '/not/home'});
    request.onProgressingAccept(accept);

    const wrapper = shallow(buildApp({request}));
    assert.isFalse(wrapper.find('InitDialog').prop('inProgress'));
    assert.isFalse(accept.called);

    const acceptPromise = wrapper.find('InitDialog').prop('request').accept('an-argument');
    assert.isTrue(wrapper.find('InitDialog').prop('inProgress'));
    assert.isTrue(accept.calledWith('an-argument'));

    completeWork('some-result');
    assert.strictEqual(await acceptPromise, 'some-result');

    wrapper.update();
    assert.isFalse(wrapper.find('InitDialog').prop('inProgress'));
  });

  describe('error handling', function() {
    it('passes a raised error to the dialog when raised during a synchronous accept callback', function() {
      const e = new Error('wtf');
      const request = dialogRequests.init({dirPath: __dirname});
      request.onAccept(() => { throw e; });

      const wrapper = shallow(buildApp({request}));
      wrapper.find('InitDialog').prop('request').accept();
      assert.strictEqual(wrapper.find('InitDialog').prop('error'), e);
    });

    it('passes a raised error to the dialog when raised during an asynchronous accept callback', async function() {
      let breakWork = () => {};
      const workPromise = new Promise((_, reject) => {
        breakWork = reject;
      });
      const accept = sinon.stub().returns(workPromise);

      const request = dialogRequests.init({dirPath: '/not/home'});
      request.onProgressingAccept(accept);

      const wrapper = shallow(buildApp({request}));
      const acceptPromise = wrapper.find('InitDialog').prop('request').accept('an-argument');
      assert.isTrue(wrapper.find('InitDialog').prop('inProgress'));
      assert.isTrue(accept.calledWith('an-argument'));

      const e = new Error('ouch');
      breakWork(e);
      await acceptPromise;

      wrapper.update();
      assert.strictEqual(wrapper.find('InitDialog').prop('error'), e);
    });
  });

  describe('specific dialogs', function() {
    it('passes appropriate props to InitDialog', function() {
      const accept = sinon.spy();
      const cancel = sinon.spy();
      const request = dialogRequests.init({dirPath: '/some/path'});
      request.onAccept(accept);
      request.onCancel(cancel);

      const wrapper = shallow(buildApp({request}));
      const dialog = wrapper.find('InitDialog');
      assert.strictEqual(dialog.prop('commands'), atomEnv.commands);

      const req = dialog.prop('request');

      req.accept();
      assert.isTrue(accept.called);

      req.cancel();
      assert.isTrue(cancel.called);

      assert.strictEqual(req.getParams().dirPath, '/some/path');
    });

    it('passes appropriate props to CloneDialog', function() {
      const accept = sinon.spy();
      const cancel = sinon.spy();
      const request = dialogRequests.clone({sourceURL: 'git@github.com:atom/github.git', destPath: '/some/path'});
      request.onAccept(accept);
      request.onCancel(cancel);

      const wrapper = shallow(buildApp({request}));
      const dialog = wrapper.find('CloneDialog');
      assert.strictEqual(dialog.prop('config'), atomEnv.config);
      assert.strictEqual(dialog.prop('commands'), atomEnv.commands);

      const req = dialog.prop('request');

      req.accept();
      assert.isTrue(accept.called);

      req.cancel();
      assert.isTrue(cancel.called);

      assert.strictEqual(req.getParams().sourceURL, 'git@github.com:atom/github.git');
      assert.strictEqual(req.getParams().destPath, '/some/path');
    });

    it('passes appropriate props to CredentialDialog', function() {
      const accept = sinon.spy();
      const cancel = sinon.spy();
      const request = dialogRequests.credential({
        prompt: 'who the hell are you',
        includeUsername: true,
        includeRemember: true,
      });
      request.onAccept(accept);
      request.onCancel(cancel);

      const wrapper = shallow(buildApp({request}));
      const dialog = wrapper.find('CredentialDialog');
      assert.strictEqual(dialog.prop('commands'), atomEnv.commands);

      const req = dialog.prop('request');

      req.accept({username: 'me', password: 'whatever'});
      assert.isTrue(accept.calledWith({username: 'me', password: 'whatever'}));

      req.cancel();
      assert.isTrue(cancel.called);

      assert.strictEqual(req.getParams().prompt, 'who the hell are you');
      assert.isTrue(req.getParams().includeUsername);
      assert.isTrue(req.getParams().includeRemember);
    });

    it('passes appropriate props to OpenIssueishDialog', function() {
      const accept = sinon.spy();
      const cancel = sinon.spy();
      const request = dialogRequests.issueish();
      request.onAccept(accept);
      request.onCancel(cancel);

      const wrapper = shallow(buildApp({request}));
      const dialog = wrapper.find('OpenIssueishDialog');
      assert.strictEqual(dialog.prop('commands'), atomEnv.commands);

      const req = dialog.prop('request');

      req.accept('https://github.com/atom/github/issue/123');
      assert.isTrue(accept.calledWith('https://github.com/atom/github/issue/123'));

      req.cancel();
      assert.isTrue(cancel.called);
    });

    it('passes appropriate props to OpenCommitDialog', function() {
      const accept = sinon.spy();
      const cancel = sinon.spy();
      const request = dialogRequests.commit();
      request.onAccept(accept);
      request.onCancel(cancel);

      const wrapper = shallow(buildApp({request}));
      const dialog = wrapper.find('OpenCommitDialog');
      assert.strictEqual(dialog.prop('commands'), atomEnv.commands);

      const req = dialog.prop('request');

      req.accept('abcd1234');
      assert.isTrue(accept.calledWith('abcd1234'));

      req.cancel();
      assert.isTrue(cancel.called);
    });

    it('passes appropriate props to the CreateDialog when creating', function() {
      const accept = sinon.spy();
      const cancel = sinon.spy();
      const request = dialogRequests.create();
      request.onAccept(accept);
      request.onCancel(cancel);

      const loginModel = new GithubLoginModel(InMemoryStrategy);

      const wrapper = shallow(buildApp({request, loginModel}));
      const dialog = wrapper.find('CreateDialog');
      assert.strictEqual(dialog.prop('loginModel'), loginModel);
      assert.strictEqual(dialog.prop('currentWindow'), atomEnv.getCurrentWindow());
      assert.strictEqual(dialog.prop('workspace'), atomEnv.workspace);
      assert.strictEqual(dialog.prop('commands'), atomEnv.commands);
      assert.strictEqual(dialog.prop('config'), atomEnv.config);

      const req = dialog.prop('request');

      req.accept('abcd1234');
      assert.isTrue(accept.calledWith('abcd1234'));

      req.cancel();
      assert.isTrue(cancel.called);
    });

    it('passes appropriate props to the CreateDialog when publishing', function() {
      const accept = sinon.spy();
      const cancel = sinon.spy();
      const request = dialogRequests.publish({localDir: __dirname});
      request.onAccept(accept);
      request.onCancel(cancel);

      const loginModel = new GithubLoginModel(InMemoryStrategy);

      const wrapper = shallow(buildApp({request, loginModel}));
      const dialog = wrapper.find('CreateDialog');
      assert.strictEqual(dialog.prop('loginModel'), loginModel);
      assert.strictEqual(dialog.prop('currentWindow'), atomEnv.getCurrentWindow());
      assert.strictEqual(dialog.prop('workspace'), atomEnv.workspace);
      assert.strictEqual(dialog.prop('commands'), atomEnv.commands);
      assert.strictEqual(dialog.prop('config'), atomEnv.config);

      const req = dialog.prop('request');

      req.accept('abcd1234');
      assert.isTrue(accept.calledWith('abcd1234'));

      req.cancel();
      assert.isTrue(cancel.called);
    });
  });
});
