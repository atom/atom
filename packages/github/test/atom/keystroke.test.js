import React from 'react';
import {shallow} from 'enzyme';

import RefHolder from '../../lib/models/ref-holder';
import Keystroke from '../../lib/atom/keystroke';

describe('Keystroke', function() {
  let atomEnv, keymaps, root, child;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    keymaps = atomEnv.keymaps;

    root = document.createElement('div');
    root.className = 'github-KeystrokeTest';

    child = document.createElement('div');
    child.className = 'github-KeystrokeTest-child';
    root.appendChild(child);

    atomEnv.commands.add(root, 'keystroke-test:root', () => {});
    atomEnv.commands.add(child, 'keystroke-test:child', () => {});
    keymaps.add(__filename, {
      '.github-KeystrokeTest': {
        'ctrl-x': 'keystroke-test:root',
      },
      '.github-KeystrokeTest-child': {
        'alt-x': 'keystroke-test:root',
        'ctrl-y': 'keystroke-test:child',
      },
    });
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  it('renders nothing for an unmapped command', function() {
    const wrapper = shallow(
      <Keystroke keymaps={keymaps} command="keystroke-test:unmapped" />,
    );

    assert.isFalse(wrapper.find('span.keystroke').exists());
  });

  it('renders nothing for a command that does not apply to the current target', function() {
    const wrapper = shallow(
      <Keystroke keymaps={keymaps} command="keystroke-test:child" refTarget={RefHolder.on(root)} />,
    );

    assert.isFalse(wrapper.find('span.keystroke').exists());
  });

  it('renders a registered keystroke', function() {
    const wrapper = shallow(
      <Keystroke keymaps={keymaps} command="keystroke-test:root" refTarget={RefHolder.on(root)} />,
    );

    assert.strictEqual(wrapper.find('span.keystroke').text(), process.platform === 'darwin' ? '\u2303X' : 'Ctrl+X');

    // Exercise some other edge cases in the component lifecycle that are not particularly interesting
    wrapper.setProps({});
    wrapper.unmount();
  });

  it('uses the target to disambiguate keystroke bindings', function() {
    const wrapper = shallow(
      <Keystroke keymaps={keymaps} command="keystroke-test:root" refTarget={RefHolder.on(root)} />,
    );

    assert.strictEqual(wrapper.find('span.keystroke').text(), process.platform === 'darwin' ? '\u2303X' : 'Ctrl+X');

    wrapper.setProps({refTarget: RefHolder.on(child)});

    assert.strictEqual(wrapper.find('span.keystroke').text(), process.platform === 'darwin' ? '\u2325X' : 'Alt+X');
  });

  it('re-renders if the command prop changes', function() {
    const wrapper = shallow(
      <Keystroke keymaps={keymaps} command="keystroke-test:root" refTarget={RefHolder.on(child)} />,
    );
    assert.strictEqual(wrapper.find('span.keystroke').text(), process.platform === 'darwin' ? '\u2325X' : 'Alt+X');

    wrapper.setProps({command: 'keystroke-test:child'});

    assert.strictEqual(wrapper.find('span.keystroke').text(), process.platform === 'darwin' ? '\u2303Y' : 'Ctrl+Y');
  });
});
