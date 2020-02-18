import React from 'react';
import {shallow, mount} from 'enzyme';
import PropTypes from 'prop-types';

import PaneItem from '../../lib/atom/pane-item';
import StubItem from '../../lib/items/stub-item';

class Component extends React.Component {
  static propTypes = {
    text: PropTypes.string.isRequired,
    didFocus: PropTypes.func,
  }

  static defaultProps = {
    didFocus: () => {},
  }

  render() {
    return (
      <div>{this.props.text}</div>
    );
  }

  getTitle() {
    return `Component with: ${this.props.text}`;
  }

  getText() {
    return this.props.text;
  }

  focus() {
    return this.props.didFocus();
  }
}

describe('PaneItem', function() {
  let atomEnv, workspace;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    workspace = atomEnv.workspace;
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  describe('opener', function() {
    it('registers an opener on the workspace', function() {
      sinon.spy(workspace, 'addOpener');

      shallow(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern">
          {() => <Component text="a prop" />}
        </PaneItem>,
      );

      assert.isTrue(workspace.addOpener.called);
    });

    it('disposes the opener on unmount', function() {
      const sub = {
        dispose: sinon.spy(),
      };
      sinon.stub(workspace, 'addOpener').returns(sub);

      const wrapper = shallow(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern">
          {() => <Component text="a prop" />}
        </PaneItem>,
      );
      wrapper.unmount();

      assert.isTrue(sub.dispose.called);
    });

    it('renders no children', function() {
      const wrapper = shallow(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern">
          {() => <Component text="a prop" />}
        </PaneItem>,
      );

      assert.lengthOf(wrapper.find('Component'), 0);
    });
  });

  describe('when opened with a matching URI', function() {
    it('calls its render prop', async function() {
      let called = false;
      mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern">
          {() => {
            called = true;
            return <Component text="a prop" />;
          }}
        </PaneItem>,
      );

      assert.isFalse(called);
      await workspace.open('atom-github://pattern');
      assert.isTrue(called);
    });

    it('uses the child component as the workspace item', async function() {
      mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern">
          {({itemHolder}) => <Component ref={itemHolder.setter} text="a prop" />}
        </PaneItem>,
      );

      const item = await workspace.open('atom-github://pattern');
      assert.strictEqual(item.getTitle(), 'Component with: a prop');
    });

    it('adds a CSS class to the root element', async function() {
      mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern" className="root">
          {({itemHolder}) => <Component ref={itemHolder.setter} text="a prop" />}
        </PaneItem>,
      );

      const item = await workspace.open('atom-github://pattern');
      assert.isTrue(item.getElement().classList.contains('root'));
    });

    it('renders a child item', async function() {
      const wrapper = mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern">
          {() => <Component text="a prop" />}
        </PaneItem>,
      );
      await workspace.open('atom-github://pattern');
      assert.lengthOf(wrapper.update().find('Component'), 1);
    });

    it('renders a different child item for each matching URI', async function() {
      const wrapper = mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern/{id}">
          {() => <Component text="a prop" />}
        </PaneItem>,
      );
      await workspace.open('atom-github://pattern/1');
      await workspace.open('atom-github://pattern/2');

      assert.lengthOf(wrapper.update().find('Component'), 2);
    });

    it('renders a different child item for each item in a different Pane', async function() {
      const wrapper = mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern/{id}">
          {() => <Component text="a prop" />}
        </PaneItem>,
      );

      const item0 = await workspace.open('atom-github://pattern/1');
      const pane0 = workspace.paneForItem(item0);
      pane0.splitRight({copyActiveItem: true});

      assert.lengthOf(wrapper.update().find('Component'), 2);
    });

    it('passes matched parameters to its render prop', async function() {
      let calledWith = null;
      mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern/{id}">
          {({params}) => {
            calledWith = params;
            return <Component text="a prop" />;
          }}
        </PaneItem>,
      );

      assert.isNull(calledWith);
      await workspace.open('atom-github://pattern/123');
      assert.deepEqual(calledWith, {id: '123'});

      calledWith = null;
      await workspace.open('atom-github://pattern/456');
      assert.deepEqual(calledWith, {id: '456'});
    });

    it('passes the URI itself', async function() {
      let calledWith = null;
      mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern/{id}">
          {({uri}) => {
            calledWith = uri;
            return <Component text="a prop" />;
          }}
        </PaneItem>,
      );

      assert.isNull(calledWith);
      await workspace.open('atom-github://pattern/123');
      assert.strictEqual(calledWith, 'atom-github://pattern/123');

      calledWith = null;
      await workspace.open('atom-github://pattern/456');
      assert.strictEqual(calledWith, 'atom-github://pattern/456');
    });

    it('calls focus() on the child item when focus() is called', async function() {
      const didFocus = sinon.spy();
      mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern">
          {({itemHolder}) => <Component ref={itemHolder.setter} text="a prop" didFocus={didFocus} />}
        </PaneItem>,
      );
      const item = await workspace.open('atom-github://pattern');
      item.getElement().dispatchEvent(new FocusEvent('focus'));

      assert.isTrue(didFocus.called);
    });

    it('removes a child when its pane is destroyed', async function() {
      const wrapper = mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern/{id}">
          {() => <Component text="a prop" />}
        </PaneItem>,
      );

      await workspace.open('atom-github://pattern/0');
      const item1 = await workspace.open('atom-github://pattern/1');

      assert.lengthOf(wrapper.update().find('Component'), 2);

      assert.isTrue(await workspace.paneForItem(item1).destroyItem(item1));

      assert.lengthOf(wrapper.update().find('Component'), 1);
    });
  });

  describe('when StubItems are present', function() {
    it('renders children into the stubs', function() {
      const stub0 = StubItem.create(
        'some-component',
        {title: 'Component'},
        'atom-github://pattern/root/10',
      );
      workspace.getActivePane().addItem(stub0);
      const stub1 = StubItem.create(
        'other-component',
        {title: 'Other Component'},
        'atom-github://other/pattern',
      );
      workspace.getActivePane().addItem(stub1);

      const wrapper = mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern/root/{id}">
          {({params}) => <Component text={params.id} />}
        </PaneItem>,
      );

      assert.lengthOf(wrapper.find('Component'), 1);
      assert.strictEqual(wrapper.find('Component').prop('text'), '10');
    });

    it('adopts the real item into the stub', function() {
      const stub = StubItem.create(
        'some-component',
        {title: 'Component'},
        'atom-github://pattern/root/10',
      );
      workspace.getActivePane().addItem(stub);

      mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern/root/{id}">
          {({params, itemHolder}) => <Component ref={itemHolder.setter} text={params.id} />}
        </PaneItem>,
      );

      assert.strictEqual(stub.getText(), '10');
    });

    it('passes additional props from the stub to the real component', function() {
      const extra = Symbol('extra');
      const stub = StubItem.create(
        'some-component',
        {title: 'Component', extra},
        'atom-github://pattern/root/10',
      );
      workspace.getActivePane().addItem(stub);

      const wrapper = mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern/root/{id}">
          {({itemHolder, deserialized}) => <Component ref={itemHolder.setter} extra={deserialized.extra} text="nah" />}
        </PaneItem>,
      );

      assert.lengthOf(wrapper.find('Component'), 1);
      assert.strictEqual(wrapper.find('Component').prop('extra'), extra);
    });

    it('adds a CSS class to the stub root', function() {
      const stub = StubItem.create(
        'some-component',
        {title: 'Component'},
        'atom-github://pattern/root/10',
      );
      workspace.getActivePane().addItem(stub);

      mount(
        <PaneItem workspace={workspace} uriPattern="atom-github://pattern/root/{id}" className="added">
          {({params, itemHolder}) => <Component ref={itemHolder.setter} text={params.id} />}
        </PaneItem>,
      );

      assert.isTrue(stub.getElement().classList.contains('added'));
    });
  });
});
