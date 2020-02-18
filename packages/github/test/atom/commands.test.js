import React from 'react';
import {mount} from 'enzyme';

import Commands, {Command} from '../../lib/atom/commands';
import RefHolder from '../../lib/models/ref-holder';

describe('Commands', function() {
  let atomEnv, commands;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    commands = atomEnv.commands;
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  it('registers commands on mount and unregisters them on unmount', async function() {
    const callback1 = sinon.stub();
    const callback2 = sinon.stub();
    const element = document.createElement('div');
    const app = (
      <Commands registry={commands} target={element}>
        <Command command="github:do-thing1" callback={callback1} />
        <Command command="github:do-thing2" callback={callback2} />
      </Commands>
    );

    const wrapper = mount(app);
    commands.dispatch(element, 'github:do-thing1');
    assert.equal(callback1.callCount, 1);
    commands.dispatch(element, 'github:do-thing2');
    assert.equal(callback2.callCount, 1);

    await new Promise(resolve => {
      wrapper.setProps({children: <Command command="github:do-thing1" callback={callback1} />}, resolve);
    });

    callback1.reset();
    callback2.reset();
    commands.dispatch(element, 'github:do-thing1');
    assert.equal(callback1.callCount, 1);
    commands.dispatch(element, 'github:do-thing2');
    assert.equal(callback2.callCount, 0);

    wrapper.unmount();

    callback1.reset();
    callback2.reset();
    commands.dispatch(element, 'github:do-thing1');
    assert.equal(callback1.callCount, 0);
    commands.dispatch(element, 'github:do-thing2');
    assert.equal(callback2.callCount, 0);
  });

  it('updates commands when props change', async function() {
    const element = document.createElement('div');
    const callback1 = sinon.stub();
    const callback2 = sinon.stub();

    class App extends React.Component {
      render() {
        return (
          <Command
            registry={commands}
            target={element}
            command={this.props.command}
            callback={this.props.callback}
          />
        );
      }
    }

    const app = <App command="user:command1" callback={callback1} />;
    const wrapper = mount(app);

    commands.dispatch(element, 'user:command1');
    assert.equal(callback1.callCount, 1);

    await new Promise(resolve => {
      wrapper.setProps({command: 'user:command2', callback: callback2}, resolve);
    });

    callback1.reset();
    commands.dispatch(element, 'user:command1');
    assert.equal(callback1.callCount, 0);
    assert.equal(callback2.callCount, 0);
    commands.dispatch(element, 'user:command2');
    assert.equal(callback1.callCount, 0);
    assert.equal(callback2.callCount, 1);
  });

  it('allows the target prop to be a RefHolder to capture refs from parent components', function() {
    const callback = sinon.spy();
    const holder = new RefHolder();
    mount(
      <Commands registry={commands} target={holder}>
        <Command command="github:do-thing" callback={callback} />
      </Commands>,
    );

    const element = document.createElement('div');
    commands.dispatch(element, 'github:do-thing');
    assert.isFalse(callback.called);

    holder.setter(element);
    commands.dispatch(element, 'github:do-thing');
    assert.isTrue(callback.called);
  });
});
