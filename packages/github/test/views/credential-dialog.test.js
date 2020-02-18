import React from 'react';
import {shallow} from 'enzyme';

import CredentialDialog from '../../lib/views/credential-dialog';
import {dialogRequests} from '../../lib/controllers/dialogs-controller';

describe('CredentialDialog', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrides = {}) {
    return (
      <CredentialDialog
        request={dialogRequests.credential()}
        inProgress={false}
        workspace={atomEnv.workspace}
        commands={atomEnv.commands}
        {...overrides}
      />
    );
  }

  describe('accept', function() {
    it('reports the current username and password', function() {
      const accept = sinon.spy();
      const request = dialogRequests.credential({includeUsername: true});
      request.onAccept(accept);
      const wrapper = shallow(buildApp({request}));

      wrapper.find('.github-Credential-username').simulate('change', {target: {value: 'someone'}});
      wrapper.find('.github-Credential-password').simulate('change', {target: {value: 'letmein'}});
      wrapper.find('DialogView').prop('accept')();

      assert.isTrue(accept.calledWith({
        username: 'someone',
        password: 'letmein',
      }));
    });

    it('omits the username if includeUsername is false', function() {
      const accept = sinon.spy();
      const request = dialogRequests.credential({includeUsername: false});
      request.onAccept(accept);
      const wrapper = shallow(buildApp({request}));

      assert.isFalse(wrapper.find('.github-Credential-username').exists());
      wrapper.find('.github-Credential-password').simulate('change', {target: {value: 'twowordsuppercase'}});
      wrapper.find('DialogView').prop('accept')();

      assert.isTrue(accept.calledWith({
        password: 'twowordsuppercase',
      }));
    });

    it('includes a "remember me" checkbox', function() {
      const accept = sinon.spy();
      const request = dialogRequests.credential({includeUsername: true, includeRemember: true});
      request.onAccept(accept);
      const wrapper = shallow(buildApp({request}));

      const rememberBox = wrapper.find('.github-Credential-remember');
      assert.isTrue(rememberBox.exists());
      rememberBox.simulate('change', {target: {checked: true}});

      wrapper.find('.github-Credential-username').simulate('change', {target: {value: 'someone'}});
      wrapper.find('.github-Credential-password').simulate('change', {target: {value: 'letmein'}});
      wrapper.find('DialogView').prop('accept')();

      assert.isTrue(accept.calledWith({
        username: 'someone',
        password: 'letmein',
        remember: true,
      }));
    });

    it('omits the "remember me" checkbox', function() {
      const request = dialogRequests.credential({includeRemember: false});
      const wrapper = shallow(buildApp({request}));
      assert.isFalse(wrapper.exists('.github-Credential-remember'));
    });
  });

  it('calls the cancel callback', function() {
    const cancel = sinon.spy();
    const request = dialogRequests.credential();
    request.onCancel(cancel);
    const wrapper = shallow(buildApp({request}));

    wrapper.find('DialogView').prop('cancel')();
    assert.isTrue(cancel.called);
  });

  describe('show password', function() {
    it('sets the passwords input type to "text" on the first click', function() {
      const wrapper = shallow(buildApp());
      wrapper.find('.github-Credential-visibility').simulate('click');

      const passwordInput = wrapper.find('.github-Credential-password');
      assert.strictEqual(passwordInput.prop('type'), 'text');
    });

    it('sets the passwords input type back to "password" on the second click', function() {
      const wrapper = shallow(buildApp());
      wrapper.find('.github-Credential-visibility').simulate('click').simulate('click');

      const passwordInput = wrapper.find('.github-Credential-password');
      assert.strictEqual(passwordInput.prop('type'), 'password');
    });
  });

  describe('sign in button enablement', function() {
    it('is always enabled when includeUsername is false', function() {
      const request = dialogRequests.credential({includeUsername: false});
      const wrapper = shallow(buildApp({request}));

      assert.isTrue(wrapper.find('DialogView').prop('acceptEnabled'));
    });

    it('is disabled if includeUsername is true and the username is empty', function() {
      const request = dialogRequests.credential({includeUsername: true});
      const wrapper = shallow(buildApp({request}));

      assert.isFalse(wrapper.find('DialogView').prop('acceptEnabled'));
    });

    it('is enabled if includeUsername is true and the username is populated', function() {
      const request = dialogRequests.credential({includeUsername: true});
      const wrapper = shallow(buildApp({request}));
      wrapper.find('.github-Credential-username').simulate('change', {target: {value: 'nonempty'}});

      assert.isTrue(wrapper.find('DialogView').prop('acceptEnabled'));
    });
  });
});
