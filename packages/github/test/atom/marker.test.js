import React from 'react';
import {mount} from 'enzyme';
import {Range} from 'atom';

import Marker from '../../lib/atom/marker';
import AtomTextEditor from '../../lib/atom/atom-text-editor';
import RefHolder from '../../lib/models/ref-holder';
import MarkerLayer from '../../lib/atom/marker-layer';
import ErrorBoundary from '../../lib/error-boundary';

describe('Marker', function() {
  let atomEnv, workspace, editor, marker, markerID;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    workspace = atomEnv.workspace;
    editor = await atomEnv.workspace.open(__filename);
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function setMarker(m) {
    marker = m;
  }

  function setMarkerID(id) {
    markerID = id;
  }

  it('adds its marker on mount with default properties', function() {
    mount(
      <Marker
        editor={editor}
        bufferRange={Range.fromObject([[0, 0], [10, 0]])}
        handleID={setMarkerID}
        handleMarker={setMarker}
      />,
    );

    const theMarker = editor.getMarker(markerID);
    assert.strictEqual(theMarker, marker);
    assert.isTrue(theMarker.getBufferRange().isEqual([[0, 0], [10, 0]]));
    assert.strictEqual(theMarker.bufferMarker.invalidate, 'overlap');
    assert.isFalse(theMarker.isReversed());
  });

  it('configures its marker', function() {
    mount(
      <Marker
        editor={editor}
        handleID={setMarkerID}
        bufferRange={Range.fromObject([[1, 2], [4, 5]])}
        reversed={true}
        invalidate={'never'}
        exclusive={true}
      />,
    );

    const theMarker = editor.getMarker(markerID);
    assert.isTrue(theMarker.getBufferRange().isEqual([[1, 2], [4, 5]]));
    assert.isTrue(theMarker.isReversed());
    assert.strictEqual(theMarker.bufferMarker.invalidate, 'never');
  });

  it('prefers marking a MarkerLayer to a TextEditor', function() {
    const layer = editor.addMarkerLayer();

    mount(
      <Marker
        editor={editor}
        layer={layer}
        handleID={setMarkerID}
        bufferRange={Range.fromObject([[0, 0], [1, 0]])}
      />,
    );

    const theMarker = layer.getMarker(markerID);
    assert.strictEqual(theMarker.layer, layer);
  });

  it('destroys its marker on unmount', function() {
    const wrapper = mount(
      <Marker editor={editor} handleID={setMarkerID} bufferRange={Range.fromObject([[0, 0], [0, 0]])} />,
    );

    assert.isDefined(editor.getMarker(markerID));
    wrapper.unmount();
    assert.isUndefined(editor.getMarker(markerID));
  });

  it('marks an editor from a parent node', function() {
    const editorHolder = new RefHolder();
    mount(
      <AtomTextEditor workspace={workspace} refModel={editorHolder}>
        <Marker handleID={setMarkerID} bufferRange={Range.fromObject([[0, 0], [0, 0]])} />
      </AtomTextEditor>,
    );

    const theEditor = editorHolder.get();
    const theMarker = theEditor.getMarker(markerID);
    assert.isTrue(theMarker.getBufferRange().isEqual([[0, 0], [0, 0]]));
  });

  it('marks a marker layer from a parent node', function() {
    let layerID;
    const editorHolder = new RefHolder();
    mount(
      <AtomTextEditor workspace={workspace} refModel={editorHolder}>
        <MarkerLayer handleID={id => { layerID = id; }}>
          <Marker handleID={setMarkerID} bufferRange={Range.fromObject([[0, 0], [0, 0]])} />
        </MarkerLayer>
      </AtomTextEditor>,
    );

    const theEditor = editorHolder.get();
    const layer = theEditor.getMarkerLayer(layerID);
    const theMarker = layer.getMarker(markerID);
    assert.isTrue(theMarker.getBufferRange().isEqual([[0, 0], [0, 0]]));
  });

  describe('with an externally managed marker', function() {
    it('locates its marker by ID', function() {
      const external = editor.markBufferRange([[0, 0], [0, 5]]);
      const wrapper = mount(<Marker editor={editor} id={external.id} />);
      const instance = wrapper.find('BareMarker').instance();
      assert.strictEqual(instance.markerHolder.get(), external);
    });

    it('locates its marker on a parent MarkerLayer', function() {
      const layer = editor.addMarkerLayer();
      const external = layer.markBufferRange([[0, 0], [0, 5]]);
      const wrapper = mount(<Marker layer={layer} id={external.id} />);
      const instance = wrapper.find('BareMarker').instance();
      assert.strictEqual(instance.markerHolder.get(), external);
    });

    describe('fails on construction', function() {
      let errors;

      // This consumes the error rather than printing it to console.
      const onError = function(e) {
        if (e.message === 'Uncaught Error: Invalid marker ID: 67') {
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

      it('if its ID is invalid', function() {
        mount(<ErrorBoundary><Marker editor={editor} id={67} /></ErrorBoundary>);
        assert.strictEqual(errors[0].message, 'Invalid marker ID: 67');
      });
    });

    it('does not destroy its marker on unmount', function() {
      const external = editor.markBufferRange([[0, 0], [0, 5]]);
      const wrapper = mount(<Marker editor={editor} id={external.id} />);
      wrapper.unmount();
      assert.isFalse(external.isDestroyed());
    });
  });
});
