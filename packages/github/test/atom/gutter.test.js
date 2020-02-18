import React from 'react';
import {mount} from 'enzyme';
import {TextBuffer} from 'atom';

import AtomTextEditor from '../../lib/atom/atom-text-editor';
import Gutter from '../../lib/atom/gutter';

describe('Gutter', function() {
  let atomEnv, domRoot;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();

    domRoot = document.createElement('div');
    domRoot.id = 'github-Gutter-test';
    document.body.appendChild(domRoot);

    const workspaceElement = atomEnv.workspace.getElement();
    domRoot.appendChild(workspaceElement);
  });

  afterEach(function() {
    atomEnv.destroy();
    document.body.removeChild(domRoot);
  });

  it('adds a custom gutter to an editor supplied by prop', async function() {
    const editor = await atomEnv.workspace.open(__filename);

    const app = (
      <Gutter editor={editor} name="aaa" priority={10} />
    );
    const wrapper = mount(app);

    const gutter = editor.gutterWithName('aaa');
    assert.isNotNull(gutter);
    assert.isTrue(gutter.isVisible());
    assert.strictEqual(gutter.priority, 10);

    wrapper.unmount();

    assert.isNull(editor.gutterWithName('aaa'));
  });

  it('adds a custom gutter to an editor from a context', function() {
    const app = (
      <AtomTextEditor workspace={atomEnv.workspace}>
        <Gutter name="bbb" priority={20} />
      </AtomTextEditor>
    );
    const wrapper = mount(app);

    const editor = wrapper.instance().getModel();
    const gutter = editor.gutterWithName('bbb');
    assert.isNotNull(gutter);
    assert.isTrue(gutter.isVisible());
    assert.strictEqual(gutter.priority, 20);
  });

  it('uses a function to derive number labels', async function() {
    const buffer = new TextBuffer({text: '000\n111\n222\n333\n444\n555\n666\n777\n888\n999\n'});
    const labelFn = ({bufferRow, screenRow}) => `custom ${bufferRow} ${screenRow}`;

    const app = (
      <AtomTextEditor workspace={atomEnv.workspace} buffer={buffer}>
        <Gutter
          name="ccc"
          priority={30}
          type="line-number"
          labelFn={labelFn}
          className="yyy"
        />
      </AtomTextEditor>
    );
    const wrapper = mount(app, {attachTo: domRoot});

    const editorRoot = wrapper.getDOMNode();
    await assert.async.lengthOf(editorRoot.querySelectorAll('.yyy .line-number'), 12);

    const lineNumbers = editorRoot.querySelectorAll('.yyy .line-number');
    assert.strictEqual(lineNumbers[1].innerText, 'custom 0 0');
    assert.strictEqual(lineNumbers[2].innerText, 'custom 1 1');
    assert.strictEqual(lineNumbers[3].innerText, 'custom 2 2');
  });
});
