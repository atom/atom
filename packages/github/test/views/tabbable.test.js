import React from 'react';
import {shallow, mount} from 'enzyme';

import {makeTabbable, TabbableSelect} from '../../lib/views/tabbable';
import TabGroup from '../../lib/tab-group';

describe('makeTabbable', function() {
  let atomEnv, tabGroup;

  const fakeEvent = {
    stopPropagation() {},
  };

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    tabGroup = new TabGroup();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  it('accepts an HTML tag', function() {
    const TabbableDiv = makeTabbable('div');
    const wrapper = shallow(
      <TabbableDiv
        tabGroup={tabGroup}
        commands={atomEnv.commands}
        other="value"
      />,
    );

    // Rendered element properties
    const div = wrapper.find('div');
    assert.isUndefined(div.prop('tabGroup'));
    assert.isUndefined(div.prop('commands'));
    assert.strictEqual(div.prop('tabIndex'), -1);
    assert.strictEqual(div.prop('other'), 'value');

    // Command registration
    const commands = wrapper.find('Commands');
    const element = Symbol('element');
    commands.prop('target').setter(element);

    sinon.stub(tabGroup, 'focusAfter');
    commands.find('Command[command="core:focus-next"]').prop('callback')(fakeEvent);
    assert.isTrue(tabGroup.focusAfter.called);

    sinon.stub(tabGroup, 'focusBefore');
    commands.find('Command[command="core:focus-previous"]').prop('callback')(fakeEvent);
    assert.isTrue(tabGroup.focusBefore.called);
  });

  it('accepts a React component', function() {
    const TabbableExample = makeTabbable(Example);
    const wrapper = shallow(
      <TabbableExample
        tabGroup={tabGroup}
        commands={atomEnv.commands}
        other="value"
      />,
    );

    // Rendered component element properties
    const example = wrapper.find(Example);
    assert.isUndefined(example.prop('tabGroup'));
    assert.isUndefined(example.prop('commands'));
    assert.strictEqual(example.prop('other'), 'value');
  });

  it('adds a ref to the TabGroup', function() {
    sinon.stub(tabGroup, 'appendElement');
    sinon.stub(tabGroup, 'removeElement');

    const TabbableExample = makeTabbable(Example);
    const wrapper = mount(<TabbableExample tabGroup={tabGroup} commands={atomEnv.commands} />);

    const instance = wrapper.find(Example).instance();
    assert.isTrue(tabGroup.appendElement.calledWith(instance, false));

    wrapper.unmount();

    assert.isTrue(tabGroup.removeElement.calledWith(instance));
  });

  it('customizes the ref used to register commands', function() {
    const TabbableExample = makeTabbable(Example, {rootRefProp: 'arbitraryName'});
    const wrapper = shallow(<TabbableExample tabGroup={tabGroup} commands={atomEnv.commands} />);

    const rootRef = wrapper.find(Example).prop('arbitraryName');
    assert.strictEqual(wrapper.find('Commands').prop('target'), rootRef);
  });

  it('passes commands to the wrapped component', function() {
    const TabbableExample = makeTabbable(Example, {passCommands: true});
    const wrapper = shallow(<TabbableExample tabGroup={tabGroup} commands={atomEnv.commands} />);
    assert.strictEqual(wrapper.find(Example).prop('commands'), atomEnv.commands);
  });

  describe('TabbableSelect', function() {
    it('proxies keydown events', function() {
      const wrapper = mount(<TabbableSelect tabGroup={tabGroup} commands={atomEnv.commands} />);
      const div = wrapper.find('div.github-TabbableWrapper').getDOMNode();
      const select = wrapper.find('Select').instance();
      let lastCode = null;
      sinon.stub(select, 'handleKeyDown').callsFake(e => {
        lastCode = e.keyCode;
      });

      const codes = new Map([
        ['github:selectbox-down', 40],
        ['github:selectbox-up', 38],
        ['github:selectbox-enter', 13],
        ['github:selectbox-tab', 9],
        ['github:selectbox-backspace', 8],
        ['github:selectbox-pageup', 33],
        ['github:selectbox-pagedown', 34],
        ['github:selectbox-end', 35],
        ['github:selectbox-home', 36],
        ['github:selectbox-delete', 46],
        ['github:selectbox-escape', 27],
      ]);

      for (const [command, code] of codes) {
        lastCode = null;
        atomEnv.commands.dispatch(div, command);
        assert.strictEqual(lastCode, code);
      }
    });

    it('passes focus() to the Select component', function() {
      const wrapper = mount(<TabbableSelect tabGroup={tabGroup} commands={atomEnv.commands} />);
      const select = wrapper.find('Select').instance();
      sinon.stub(select, 'focus');

      wrapper.instance().elementRef.get().focus();
      assert.isTrue(select.focus.called);
    });
  });
});

class Example extends React.Component {
  render() {
    return <div />;
  }
}
