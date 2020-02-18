import React from 'react';
import {mount} from 'enzyme';
import {Range} from 'atom';
import path from 'path';

import Decoration from '../../lib/atom/decoration';
import AtomTextEditor from '../../lib/atom/atom-text-editor';
import Marker from '../../lib/atom/marker';
import MarkerLayer from '../../lib/atom/marker-layer';
import ErrorBoundary from '../../lib/error-boundary';

describe('Decoration', function() {
  let atomEnv, workspace, editor, marker;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    workspace = atomEnv.workspace;

    editor = await workspace.open(__filename);
    marker = editor.markBufferRange([[2, 0], [6, 0]]);
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  it('decorates its marker on render', function() {
    const app = (
      <Decoration
        editor={editor}
        decorable={marker}
        type="line"
        position="head"
        className="something"
      />
    );
    mount(app);

    assert.lengthOf(editor.getLineDecorations({position: 'head', class: 'something'}), 1);
  });

  describe('with a subtree', function() {
    beforeEach(function() {
      sinon.spy(editor, 'decorateMarker');
    });

    it('creates a block decoration', function() {
      const app = (
        <Decoration editor={editor} decorable={marker} type="block" className="parent">
          <div className="decoration-subtree">
            This is a subtree
          </div>
        </Decoration>
      );
      mount(app);

      const args = editor.decorateMarker.firstCall.args;
      assert.equal(args[0], marker);
      assert.equal(args[1].type, 'block');
      const element = args[1].item.getElement();
      assert.strictEqual(element.className, 'react-atom-decoration parent');
      const child = element.firstElementChild;
      assert.equal(child.className, 'decoration-subtree');
      assert.equal(child.textContent, 'This is a subtree');
    });

    it('creates an overlay decoration', function() {
      const app = (
        <Decoration editor={editor} decorable={marker} type="overlay">
          <div className="decoration-subtree">
            This is a subtree
          </div>
        </Decoration>
      );
      mount(app);

      const args = editor.decorateMarker.firstCall.args;
      assert.equal(args[0], marker);
      assert.equal(args[1].type, 'overlay');
      const child = args[1].item.getElement().firstElementChild;
      assert.equal(child.className, 'decoration-subtree');
      assert.equal(child.textContent, 'This is a subtree');
    });

    it('decorates a gutter after it has been created in the editor', function() {
      const gutterName = 'rubin-starset-memorial-gutter';
      const app = (
        <Decoration editor={editor} decorable={marker} type="gutter" gutterName={gutterName}>
          <div className="decoration-subtree">
            This is a subtree
          </div>
        </Decoration>
      );
      mount(app);

      // the gutter has not been created yet at this point
      assert.isNull(editor.gutterWithName(gutterName));
      assert.isFalse(editor.decorateMarker.called);

      editor.addGutter({name: gutterName});

      assert.isTrue(editor.decorateMarker.called);
      const args = editor.decorateMarker.firstCall.args;
      assert.equal(args[0], marker);
      assert.equal(args[1].type, 'gutter');
      assert.equal(args[1].gutterName, 'rubin-starset-memorial-gutter');
      const child = args[1].item.getElement().firstElementChild;
      assert.equal(child.className, 'decoration-subtree');
      assert.equal(child.textContent, 'This is a subtree');
    });

    it('does not decorate a non-existent gutter', function() {
      const gutterName = 'rubin-starset-memorial-gutter';
      const app = (
        <Decoration editor={editor} decorable={marker} type="gutter" gutterName={gutterName}>
          <div className="decoration-subtree">
            This is a subtree
          </div>
        </Decoration>
      );
      mount(app);

      assert.isNull(editor.gutterWithName(gutterName));
      assert.isFalse(editor.decorateMarker.called);

      editor.addGutter({name: 'another-gutter-name'});

      assert.isFalse(editor.decorateMarker.called);
      assert.isNull(editor.gutterWithName(gutterName));
    });

    describe('throws an error', function() {
      let errors;

      // This consumes the error rather than printing it to console.
      const onError = function(e) {
        if (e.message === 'Uncaught Error: You are trying to decorate a gutter but did not supply gutterName prop.') {
          errors.push(e.error);
          e.preventDefault();
        }
      };

      beforeEach(function() {
        errors = [];
        window.addEventListener('error', onError);
      });

      afterEach(function() {
        errors = [];
        window.removeEventListener('error', onError);
      });

      it('if `gutterName` prop is not supplied for gutter decorations', function() {
        const app = (
          <ErrorBoundary>
            <Decoration editor={editor} decorable={marker} type="gutter">
              <div className="decoration-subtree">
                This is a subtree
              </div>
            </Decoration>
          </ErrorBoundary>
        );
        mount(app);
        assert.strictEqual(errors[0].message, 'You are trying to decorate a gutter but did not supply gutterName prop.');
      });
    });
  });

  describe('when props update', function() {
    it('creates a new decoration on a different TextEditor and marker', async function() {
      const wrapper = mount(<Decoration editor={editor} decorable={marker} type="line" className="pretty" />);

      assert.lengthOf(editor.getLineDecorations({class: 'pretty'}), 1);
      const [original] = editor.getLineDecorations({class: 'pretty'});

      const newEditor = await workspace.open(path.join(__dirname, 'marker.test.js'));
      const newMarker = newEditor.markBufferRange([[0, 0], [1, 0]]);

      wrapper.setProps({editor: newEditor, decorable: newMarker});

      assert.isTrue(original.isDestroyed());
      assert.lengthOf(editor.getLineDecorations({class: 'pretty'}), 0);

      assert.lengthOf(newEditor.getLineDecorations({class: 'pretty'}), 1);
      const [newDecoration] = newEditor.getLineDecorations({class: 'pretty'});
      assert.strictEqual(newDecoration.getMarker(), newMarker);
    });

    it('creates a new decoration on a different Marker', function() {
      const wrapper = mount(<Decoration editor={editor} decorable={marker} type="line" className="pretty" />);

      assert.lengthOf(editor.getLineDecorations({class: 'pretty'}), 1);
      const [original] = editor.getLineDecorations({class: 'pretty'});

      const newMarker = editor.markBufferRange([[1, 0], [3, 0]]);
      wrapper.setProps({decorable: newMarker});

      assert.isTrue(original.isDestroyed());

      assert.lengthOf(editor.getLineDecorations({class: 'pretty'}), 1);
      const [newDecoration] = editor.getLineDecorations({class: 'pretty'});
      assert.strictEqual(newDecoration.getMarker(), newMarker);
    });

    it('destroys and re-creates its decoration', function() {
      const wrapper = mount(<Decoration editor={editor} decorable={marker} type="line" className="pretty" />);

      assert.lengthOf(editor.getLineDecorations({class: 'pretty'}), 1);
      const [original] = editor.getLineDecorations({class: 'pretty'});

      wrapper.setProps({type: 'line-number', className: 'prettier'});

      assert.isTrue(original.isDestroyed());
      assert.lengthOf(editor.getLineNumberDecorations({class: 'prettier'}), 1);
    });

    it('does not create a decoration when the Marker is not on the TextEditor', async function() {
      const wrapper = mount(<Decoration editor={editor} decorable={marker} type="line" className="pretty" />);

      assert.lengthOf(editor.getLineDecorations({class: 'pretty'}), 1);
      const [original] = editor.getLineDecorations({class: 'pretty'});

      const newEditor = await workspace.open(path.join(__dirname, 'marker.test.js'));
      wrapper.setProps({editor: newEditor});

      assert.isTrue(original.isDestroyed());
      assert.lengthOf(editor.getLineDecorations({class: 'pretty'}), 0);
      assert.lengthOf(newEditor.getLineDecorations({class: 'pretty'}), 0);
    });
  });

  it('destroys its decoration on unmount', function() {
    const app = (
      <Decoration
        editor={editor}
        decorable={marker}
        type="line"
        className="whatever"
      />
    );
    const wrapper = mount(app);

    assert.lengthOf(editor.getLineDecorations({class: 'whatever'}), 1);

    wrapper.unmount();

    assert.lengthOf(editor.getLineDecorations({class: 'whatever'}), 0);
  });

  it('decorates a parent Marker on a parent TextEditor', function() {
    const wrapper = mount(
      <AtomTextEditor workspace={workspace}>
        <Marker bufferRange={Range.fromObject([[0, 0], [0, 0]])}>
          <Decoration type="line" className="whatever" position="head" />
        </Marker>
      </AtomTextEditor>,
    );
    const theEditor = wrapper.instance().getModel();

    assert.lengthOf(theEditor.getLineDecorations({position: 'head', class: 'whatever'}), 1);
  });

  it('decorates a parent MarkerLayer on a parent TextEditor', function() {
    let layerID = null;
    const wrapper = mount(
      <AtomTextEditor workspace={workspace}>
        <MarkerLayer handleID={id => { layerID = id; }}>
          <Marker bufferRange={Range.fromObject([[0, 0], [0, 0]])} />
          <Decoration type="line" className="something" />
        </MarkerLayer>
      </AtomTextEditor>,
    );
    const theEditor = wrapper.instance().getModel();
    const theLayer = theEditor.getMarkerLayer(layerID);

    const layerMap = theEditor.decorationManager.layerDecorationsByMarkerLayer;
    const decorationSet = layerMap.get(theLayer);
    assert.strictEqual(decorationSet.size, 1);
  });

  it('decorates a parent Marker on a prop-provided TextEditor', function() {
    mount(
      <Marker editor={editor} bufferRange={Range.fromObject([[0, 0], [1, 0]])}>
        <Decoration editor={editor} type="line" className="something" />
      </Marker>,
    );

    assert.lengthOf(editor.getLineDecorations({class: 'something'}), 1);
  });

  it('decorates a parent MarkerLayer on a prop-provided TextEditor', function() {
    let layerID = null;
    mount(
      <MarkerLayer editor={editor} handleID={id => { layerID = id; }}>
        <Marker bufferRange={Range.fromObject([[0, 0], [1, 0]])} />
        <Decoration editor={editor} type="line" className="something" />
      </MarkerLayer>,
    );

    const theLayer = editor.getMarkerLayer(layerID);

    const layerMap = editor.decorationManager.layerDecorationsByMarkerLayer;
    const decorationSet = layerMap.get(theLayer);
    assert.strictEqual(decorationSet.size, 1);
  });

  it('does not attempt to decorate a destroyed Marker', function() {
    marker.destroy();

    const app = (
      <Decoration
        editor={editor}
        decorable={marker}
        type="line"
        position="head"
        className="something"
      />
    );
    mount(app);

    assert.lengthOf(editor.getLineDecorations(), 0);
  });

  it('does not attempt to decorate a destroyed TextEditor', function() {
    editor.destroy();

    const app = (
      <Decoration
        editor={editor}
        decorable={marker}
        type="line"
        position="head"
        className="something"
      />
    );
    mount(app);

    assert.lengthOf(editor.getLineDecorations(), 0);
  });
});
