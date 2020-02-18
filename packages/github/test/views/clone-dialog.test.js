import React from 'react';
import {shallow} from 'enzyme';
import path from 'path';

import CloneDialog from '../../lib/views/clone-dialog';
import {dialogRequests} from '../../lib/controllers/dialogs-controller';

describe('CloneDialog', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(overrides = {}) {
    return (
      <CloneDialog
        config={atomEnv.config}
        workspace={atomEnv.workspace}
        commands={atomEnv.commands}
        request={dialogRequests.clone()}
        inProgress={false}
        {...overrides}
      />
    );
  }

  describe('entering a remote URL', function() {
    it("updates the project path automatically if it hasn't been modified", function() {
      sinon.stub(atomEnv.config, 'get').returns(path.join('/home/me/src'));
      const wrapper = shallow(buildApp());

      wrapper.find('.github-Clone-sourceURL').prop('buffer').setText('git@github.com:atom/github.git');
      wrapper.update();
      assert.strictEqual(
        wrapper.find('.github-Clone-destinationPath').prop('buffer').getText(),
        path.join('/home/me/src/github'),
      );

      wrapper.find('.github-Clone-sourceURL').prop('buffer')
        .setText('https://github.com/smashwilson/slack-emojinator.git');
      wrapper.update();
      assert.strictEqual(
        wrapper.find('.github-Clone-destinationPath').prop('buffer').getText(),
        path.join('/home/me/src/slack-emojinator'),
      );
    });

    it("doesn't update the project path if the source URL has no pathname", function() {
      sinon.stub(atomEnv.config, 'get').returns(path.join('/home/me/src'));
      const wrapper = shallow(buildApp());

      wrapper.find('.github-Clone-sourceURL').prop('buffer').setText('https://github.com');
      wrapper.update();
      assert.strictEqual(
        wrapper.find('.github-Clone-destinationPath').prop('buffer').getText(),
        path.join('/home/me/src'),
      );
    });

    it("doesn't update the project path if it has been modified", function() {
      const wrapper = shallow(buildApp());
      wrapper.find('.github-Clone-destinationPath').prop('buffer').setText(path.join('/somewhere/else'));
      wrapper.find('.github-Clone-sourceURL').prop('buffer').setText('git@github.com:atom/github.git');
      assert.strictEqual(
        wrapper.find('.github-Clone-destinationPath').prop('buffer').getText(),
        path.join('/somewhere/else'),
      );
    });
  });

  describe('clone button enablement', function() {
    it('disables the clone button with no remote URL', function() {
      const wrapper = shallow(buildApp());
      wrapper.find('.github-Clone-destinationPath').prop('buffer').setText(path.join('/some/where'));
      wrapper.find('.github-Clone-sourceURL').prop('buffer').setText('');
      wrapper.update();

      assert.isFalse(wrapper.find('DialogView').prop('acceptEnabled'));
    });

    it('disables the clone button with no project path', function() {
      const wrapper = shallow(buildApp());
      wrapper.find('.github-Clone-destinationPath').prop('buffer').setText('');
      wrapper.find('.github-Clone-sourceURL').prop('buffer').setText('git@github.com:atom/github.git');
      wrapper.update();

      assert.isFalse(wrapper.find('DialogView').prop('acceptEnabled'));
    });

    it('enables the clone button when both text boxes are populated', function() {
      const wrapper = shallow(buildApp());
      wrapper.find('.github-Clone-destinationPath').prop('buffer').setText(path.join('/some/where'));
      wrapper.find('.github-Clone-sourceURL').prop('buffer').setText('git@github.com:atom/github.git');
      wrapper.update();

      assert.isTrue(wrapper.find('DialogView').prop('acceptEnabled'));
    });
  });

  it('calls the acceptance callback', function() {
    const accept = sinon.spy();
    const request = dialogRequests.clone();
    request.onAccept(accept);
    const wrapper = shallow(buildApp({request}));

    wrapper.find('.github-Clone-destinationPath').prop('buffer').setText(path.join('/some/where'));
    wrapper.find('.github-Clone-sourceURL').prop('buffer').setText('git@github.com:atom/github.git');

    wrapper.find('DialogView').prop('accept')();
    assert.isTrue(accept.calledWith('git@github.com:atom/github.git', path.join('/some/where')));
  });

  it('does nothing from the acceptance callback if either text field is empty', function() {
    const accept = sinon.spy();
    const request = dialogRequests.clone();
    request.onAccept(accept);
    const wrapper = shallow(buildApp({request}));

    wrapper.find('DialogView').prop('accept')();
    assert.isFalse(accept.called);
  });

  it('calls the cancellation callback', function() {
    const cancel = sinon.spy();
    const request = dialogRequests.clone();
    request.onCancel(cancel);
    const wrapper = shallow(buildApp({request}));

    wrapper.find('DialogView').prop('cancel')();
    assert.isTrue(cancel.called);
  });

  describe('in progress', function() {
    it('disables the text editors and buttons', function() {
      const wrapper = shallow(buildApp({inProgress: true}));

      assert.isTrue(wrapper.find('.github-Clone-sourceURL').prop('readOnly'));
      assert.isTrue(wrapper.find('.github-Clone-destinationPath').prop('readOnly'));
    });
  });
});
