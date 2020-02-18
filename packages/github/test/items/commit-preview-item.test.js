import React from 'react';
import {mount} from 'enzyme';

import CommitPreviewItem from '../../lib/items/commit-preview-item';
import PaneItem from '../../lib/atom/pane-item';
import WorkdirContextPool from '../../lib/models/workdir-context-pool';
import {cloneRepository} from '../helpers';

describe('CommitPreviewItem', function() {
  let atomEnv, repository, pool;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    const workdir = await cloneRepository();

    pool = new WorkdirContextPool({
      workspace: atomEnv.workspace,
    });

    repository = pool.add(workdir).getRepository();
  });

  afterEach(function() {
    atomEnv.destroy();
    pool.clear();
  });

  function buildPaneApp(override = {}) {
    const props = {
      workdirContextPool: pool,
      workspace: atomEnv.workspace,
      commands: atomEnv.commands,
      keymaps: atomEnv.keymaps,
      tooltips: atomEnv.tooltips,
      config: atomEnv.config,
      discardLines: () => {},
      undoLastDiscard: () => {},
      surfaceToCommitPreviewButton: () => {},
      ...override,
    };

    return (
      <PaneItem workspace={atomEnv.workspace} uriPattern={CommitPreviewItem.uriPattern}>
        {({itemHolder, params}) => {
          return (
            <CommitPreviewItem
              ref={itemHolder.setter}
              workingDirectory={params.workingDirectory}
              {...props}
            />
          );
        }}
      </PaneItem>
    );
  }

  function open(options = {}) {
    const opts = {
      workingDirectory: repository.getWorkingDirectoryPath(),
      ...options,
    };
    const uri = CommitPreviewItem.buildURI(opts.workingDirectory);
    return atomEnv.workspace.open(uri);
  }

  it('constructs and opens the correct URI', async function() {
    const wrapper = mount(buildPaneApp());
    await open();

    assert.isTrue(wrapper.update().find('CommitPreviewItem').exists());
  });

  it('passes extra props to its container', async function() {
    const extra = Symbol('extra');
    const wrapper = mount(buildPaneApp({extra}));
    await open();

    assert.strictEqual(wrapper.update().find('CommitPreviewContainer').prop('extra'), extra);
  });

  it('locates the repository from the context pool', async function() {
    const wrapper = mount(buildPaneApp());
    await open();

    assert.strictEqual(wrapper.update().find('CommitPreviewContainer').prop('repository'), repository);
  });

  it('passes an absent repository if the working directory is unrecognized', async function() {
    const wrapper = mount(buildPaneApp());
    await open({workingDirectory: '/nah'});

    assert.isTrue(wrapper.update().find('CommitPreviewContainer').prop('repository').isAbsent());
  });

  it('returns a fixed title and icon', async function() {
    mount(buildPaneApp());
    const item = await open();

    assert.strictEqual(item.getTitle(), 'Staged Changes');
    assert.strictEqual(item.getIconName(), 'tasklist');
  });

  it('terminates pending state', async function() {
    mount(buildPaneApp());

    const item = await open();
    const callback = sinon.spy();
    const sub = item.onDidTerminatePendingState(callback);

    assert.strictEqual(callback.callCount, 0);
    item.terminatePendingState();
    assert.strictEqual(callback.callCount, 1);
    item.terminatePendingState();
    assert.strictEqual(callback.callCount, 1);

    sub.dispose();
  });

  it('may be destroyed once', async function() {
    mount(buildPaneApp());

    const item = await open();
    const callback = sinon.spy();
    const sub = item.onDidDestroy(callback);

    assert.strictEqual(callback.callCount, 0);
    item.destroy();
    assert.strictEqual(callback.callCount, 1);

    sub.dispose();
  });

  it('serializes itself as a CommitPreviewStub', async function() {
    mount(buildPaneApp());
    const item0 = await open({workingDirectory: '/dir0'});
    assert.deepEqual(item0.serialize(), {
      deserializer: 'CommitPreviewStub',
      uri: 'atom-github://commit-preview?workdir=%2Fdir0',
    });

    const item1 = await open({workingDirectory: '/dir1'});
    assert.deepEqual(item1.serialize(), {
      deserializer: 'CommitPreviewStub',
      uri: 'atom-github://commit-preview?workdir=%2Fdir1',
    });
  });

  it('has an item-level accessor for the current working directory', async function() {
    mount(buildPaneApp());
    const item = await open({workingDirectory: '/dir7'});
    assert.strictEqual(item.getWorkingDirectory(), '/dir7');
  });

  describe('focus()', function() {
    it('imperatively focuses the value of the initial focus ref', async function() {
      mount(buildPaneApp());
      const item = await open();

      const focusSpy = {focus: sinon.spy()};
      item.refInitialFocus.setter(focusSpy);

      item.focus();

      assert.isTrue(focusSpy.focus.called);
    });

    it('is a no-op if there is no initial focus ref', async function() {
      mount(buildPaneApp());
      const item = await open();

      item.refInitialFocus.setter(null);

      item.focus();
    });
  });

  describe('observeEmbeddedTextEditor() to interoperate with find-and-replace', function() {
    let sub, editor;

    beforeEach(function() {
      editor = {
        isAlive() { return true; },
      };
    });

    afterEach(function() {
      sub && sub.dispose();
    });

    it('calls its callback immediately if an editor is present and alive', async function() {
      const wrapper = mount(buildPaneApp());
      const item = await open();

      wrapper.update().find('CommitPreviewContainer').prop('refEditor').setter(editor);

      const cb = sinon.spy();
      sub = item.observeEmbeddedTextEditor(cb);
      assert.isTrue(cb.calledWith(editor));
    });

    it('does not call its callback if an editor is present but destroyed', async function() {
      const wrapper = mount(buildPaneApp());
      const item = await open();

      wrapper.update().find('CommitPreviewContainer').prop('refEditor').setter({isAlive() { return false; }});

      const cb = sinon.spy();
      sub = item.observeEmbeddedTextEditor(cb);
      assert.isFalse(cb.called);
    });

    it('calls its callback later if the editor changes', async function() {
      const wrapper = mount(buildPaneApp());
      const item = await open();

      const cb = sinon.spy();
      sub = item.observeEmbeddedTextEditor(cb);

      wrapper.update().find('CommitPreviewContainer').prop('refEditor').setter(editor);
      assert.isTrue(cb.calledWith(editor));
    });

    it('does not call its callback after its editor is destroyed', async function() {
      const wrapper = mount(buildPaneApp());
      const item = await open();

      const cb = sinon.spy();
      sub = item.observeEmbeddedTextEditor(cb);

      wrapper.update().find('CommitPreviewContainer').prop('refEditor').setter({isAlive() { return false; }});
      assert.isFalse(cb.called);
    });
  });
});
