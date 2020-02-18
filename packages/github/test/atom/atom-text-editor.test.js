import React from 'react';
import {mount, shallow} from 'enzyme';
import {TextBuffer} from 'atom';

import RefHolder from '../../lib/models/ref-holder';
import AtomTextEditor from '../../lib/atom/atom-text-editor';

describe('AtomTextEditor', function() {
  let atomEnv, workspace, refModel;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    workspace = atomEnv.workspace;
    refModel = new RefHolder();
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  it('creates a text editor element', function() {
    const app = mount(
      <AtomTextEditor workspace={workspace} refModel={refModel} />,
    );

    const children = app.find('div').getDOMNode().children;
    assert.lengthOf(children, 1);
    const child = children[0];
    assert.isTrue(workspace.isTextEditor(child.getModel()));
    assert.strictEqual(child.getModel(), refModel.getOr(undefined));
  });

  it('creates its own model ref if one is not provided by a parent', function() {
    const app = mount(<AtomTextEditor workspace={workspace} />);
    assert.isTrue(workspace.isTextEditor(app.instance().refModel.get()));
  });

  it('creates its own element ref if one is not provided by a parent', function() {
    const app = mount(<AtomTextEditor workspace={workspace} />);

    const model = app.instance().refModel.get();
    const element = app.instance().refElement.get();
    assert.strictEqual(element, model.getElement());
    assert.strictEqual(element.getModel(), model);
  });

  it('accepts parent-provided model and element refs', function() {
    const refElement = new RefHolder();

    mount(<AtomTextEditor refModel={refModel} refElement={refElement} workspace={workspace} />);

    const model = refModel.get();
    const element = refElement.get();

    assert.isTrue(workspace.isTextEditor(model));
    assert.strictEqual(element, model.getElement());
    assert.strictEqual(element.getModel(), model);
  });

  it('returns undefined if the current model is unavailable', function() {
    const emptyHolder = new RefHolder();
    const app = shallow(<AtomTextEditor refModel={emptyHolder} />);
    assert.isUndefined(app.instance().getModel());
  });

  it('configures the created text editor with props', function() {
    mount(
      <AtomTextEditor
        workspace={workspace}
        refModel={refModel}
        mini={true}
        readOnly={true}
        placeholderText="hooray"
        lineNumberGutterVisible={false}
        autoWidth={true}
        autoHeight={false}
      />,
    );

    const editor = refModel.get();

    assert.isTrue(editor.isMini());
    assert.isTrue(editor.isReadOnly());
    assert.strictEqual(editor.getPlaceholderText(), 'hooray');
    assert.isFalse(editor.lineNumberGutter.isVisible());
    assert.isTrue(editor.getAutoWidth());
    assert.isFalse(editor.getAutoHeight());
  });

  it('accepts a precreated buffer', function() {
    const buffer = new TextBuffer();
    buffer.setText('precreated');

    mount(
      <AtomTextEditor
        workspace={workspace}
        refModel={refModel}
        buffer={buffer}
      />,
    );

    const editor = refModel.get();

    assert.strictEqual(editor.getText(), 'precreated');

    buffer.setText('changed');
    assert.strictEqual(editor.getText(), 'changed');
  });

  it('mount with all text preselected on request', function() {
    const buffer = new TextBuffer();
    buffer.setText('precreated\ntwo lines\n');

    mount(
      <AtomTextEditor
        workspace={workspace}
        refModel={refModel}
        buffer={buffer}
        preselect={true}
      />,
    );

    const editor = refModel.get();

    assert.strictEqual(editor.getText(), 'precreated\ntwo lines\n');
    assert.strictEqual(editor.getSelectedText(), 'precreated\ntwo lines\n');
  });

  it('updates changed attributes on re-render', function() {
    const app = mount(
      <AtomTextEditor
        workspace={workspace}
        refModel={refModel}
        readOnly={true}
      />,
    );

    const editor = refModel.get();
    assert.isTrue(editor.isReadOnly());

    app.setProps({readOnly: false});

    assert.isFalse(editor.isReadOnly());
  });

  it('destroys its text editor on unmount', function() {
    const app = mount(
      <AtomTextEditor
        workspace={workspace}
        refModel={refModel}
        readOnly={true}
      />,
    );

    const editor = refModel.get();
    sinon.spy(editor, 'destroy');

    app.unmount();

    assert.isTrue(editor.destroy.called);
  });

  describe('event subscriptions', function() {
    let handler, buffer;

    beforeEach(function() {
      handler = sinon.spy();

      buffer = new TextBuffer({
        text: 'one\ntwo\nthree\nfour\nfive\n',
      });
    });

    it('defaults to no-op handlers', function() {
      mount(
        <AtomTextEditor
          workspace={workspace}
          refModel={refModel}
          buffer={buffer}
        />,
      );

      const editor = refModel.get();

      // Trigger didChangeCursorPosition
      editor.setCursorBufferPosition([2, 3]);

      // Trigger didAddSelection
      editor.addSelectionForBufferRange([[1, 0], [3, 3]]);

      // Trigger didChangeSelectionRange
      const [selection] = editor.getSelections();
      selection.setBufferRange([[2, 2], [2, 3]]);

      // Trigger didDestroySelection
      editor.setSelectedBufferRange([[1, 0], [1, 2]]);
    });

    it('triggers didChangeCursorPosition when the cursor position changes', function() {
      mount(
        <AtomTextEditor
          workspace={workspace}
          refModel={refModel}
          buffer={buffer}
          didChangeCursorPosition={handler}
        />,
      );

      const editor = refModel.get();
      editor.setCursorBufferPosition([2, 3]);

      assert.isTrue(handler.called);
      const [{newBufferPosition}] = handler.lastCall.args;
      assert.deepEqual(newBufferPosition.serialize(), [2, 3]);

      handler.resetHistory();
      editor.setCursorBufferPosition([2, 3]);
      assert.isFalse(handler.called);
    });

    it('triggers didAddSelection when a selection is added', function() {
      mount(
        <AtomTextEditor
          workspace={workspace}
          refModel={refModel}
          buffer={buffer}
          didAddSelection={handler}
        />,
      );

      const editor = refModel.get();
      editor.addSelectionForBufferRange([[1, 0], [3, 3]]);

      assert.isTrue(handler.called);
      const [selection] = handler.lastCall.args;
      assert.deepEqual(selection.getBufferRange().serialize(), [[1, 0], [3, 3]]);
    });

    it("triggers didChangeSelectionRange when an existing selection's range is altered", function() {
      mount(
        <AtomTextEditor
          workspace={workspace}
          refModel={refModel}
          buffer={buffer}
          didChangeSelectionRange={handler}
        />,
      );

      const editor = refModel.get();
      editor.setSelectedBufferRange([[2, 0], [2, 1]]);
      const [selection] = editor.getSelections();
      assert.isTrue(handler.called);
      handler.resetHistory();

      selection.setBufferRange([[2, 2], [2, 3]]);
      assert.isTrue(handler.called);
      const [payload] = handler.lastCall.args;
      if (payload) {
        assert.deepEqual(payload.oldBufferRange.serialize(), [[2, 0], [2, 1]]);
        assert.deepEqual(payload.oldScreenRange.serialize(), [[2, 0], [2, 1]]);
        assert.deepEqual(payload.newBufferRange.serialize(), [[2, 2], [2, 3]]);
        assert.deepEqual(payload.newScreenRange.serialize(), [[2, 2], [2, 3]]);
        assert.strictEqual(payload.selection, selection);
      }
    });

    it('triggers didDestroySelection when an existing selection is destroyed', function() {
      mount(
        <AtomTextEditor
          workspace={workspace}
          refModel={refModel}
          buffer={buffer}
          didDestroySelection={handler}
        />,
      );

      const editor = refModel.get();
      editor.setSelectedBufferRanges([
        [[2, 0], [2, 1]],
        [[3, 0], [3, 1]],
      ]);
      const selection1 = editor.getSelections()[1];
      assert.isFalse(handler.called);

      editor.setSelectedBufferRange([[1, 0], [1, 2]]);
      assert.isTrue(handler.calledWith(selection1));
    });
  });

  describe('hideEmptiness', function() {
    it('adds the github-AtomTextEditor-empty class when constructed with an empty TextBuffer', function() {
      const emptyBuffer = new TextBuffer();

      const wrapper = mount(<AtomTextEditor workspace={workspace} buffer={emptyBuffer} hideEmptiness={true} />);
      const element = wrapper.instance().refElement.get();

      assert.isTrue(element.classList.contains('github-AtomTextEditor-empty'));
    });

    it('removes the github-AtomTextEditor-empty class when constructed with a non-empty TextBuffer', function() {
      const nonEmptyBuffer = new TextBuffer({text: 'nonempty\n'});

      const wrapper = mount(<AtomTextEditor workspace={workspace} buffer={nonEmptyBuffer} hideEmptiness={true} />);
      const element = wrapper.instance().refElement.get();

      assert.isFalse(element.classList.contains('github-AtomTextEditor-empty'));
    });

    it('adds and removes the github-AtomTextEditor-empty class as its TextBuffer becomes empty and non-empty', function() {
      const buffer = new TextBuffer({text: 'nonempty\n...to start with\n'});

      const wrapper = mount(<AtomTextEditor workspace={workspace} buffer={buffer} hideEmptiness={true} />);
      const element = wrapper.instance().refElement.get();

      assert.isFalse(element.classList.contains('github-AtomTextEditor-empty'));

      buffer.setText('');
      assert.isTrue(element.classList.contains('github-AtomTextEditor-empty'));

      buffer.setText('asdf\n');
      assert.isFalse(element.classList.contains('github-AtomTextEditor-empty'));
    });
  });

  it('detects DOM node membership', function() {
    const wrapper = mount(
      <AtomTextEditor workspace={workspace} refModel={refModel} />,
    );

    const children = wrapper.find('div').getDOMNode().children;
    assert.lengthOf(children, 1);
    const child = children[0];
    const instance = wrapper.instance();

    assert.isTrue(instance.contains(child));
    assert.isFalse(instance.contains(document.body));
  });

  it('focuses its editor element', function() {
    const wrapper = mount(
      <AtomTextEditor workspace={workspace} refModel={refModel} />,
    );

    const children = wrapper.find('div').getDOMNode().children;
    assert.lengthOf(children, 1);
    const child = children[0];
    sinon.spy(child, 'focus');

    const instance = wrapper.instance();
    instance.focus();
    assert.isTrue(child.focus.called);
  });
});
