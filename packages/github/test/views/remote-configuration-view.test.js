import React from 'react';
import {shallow} from 'enzyme';
import {TextBuffer} from 'atom';

import RemoteConfigurationView from '../../lib/views/remote-configuration-view';
import TabGroup from '../../lib/tab-group';
import {TabbableTextEditor} from '../../lib/views/tabbable';

describe('RemoteConfigurationView', function() {
  let atomEnv;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    const sourceRemoteBuffer = new TextBuffer();
    return (
      <RemoteConfigurationView
        currentProtocol={'https'}
        didChangeProtocol={() => {}}
        sourceRemoteBuffer={sourceRemoteBuffer}
        tabGroup={new TabGroup()}
        commands={atomEnv.commands}
        {...override}
      />
    );
  }

  it('passes models to the appropriate controls', function() {
    const sourceRemoteBuffer = new TextBuffer();
    const currentProtocol = 'ssh';

    const wrapper = shallow(buildApp({currentProtocol, sourceRemoteBuffer}));
    assert.strictEqual(wrapper.find(TabbableTextEditor).prop('buffer'), sourceRemoteBuffer);
    assert.isFalse(wrapper.find('.github-RemoteConfiguration-protocolOption--https .input-radio').prop('checked'));
    assert.isTrue(wrapper.find('.github-RemoteConfiguration-protocolOption--ssh .input-radio').prop('checked'));
  });

  it('calls a callback when the protocol is changed', function() {
    const didChangeProtocol = sinon.spy();

    const wrapper = shallow(buildApp({didChangeProtocol}));
    wrapper.find('.github-RemoteConfiguration-protocolOption--ssh .input-radio')
      .prop('onChange')({target: {value: 'ssh'}});

    assert.isTrue(didChangeProtocol.calledWith('ssh'));
  });
});
