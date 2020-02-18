import React from 'react';
import {mount} from 'enzyme';

import CommitDetailItem from '../../lib/items/commit-detail-item';
import PaneItem from '../../lib/atom/pane-item';
import WorkdirContextPool from '../../lib/models/workdir-context-pool';
import {cloneRepository} from '../helpers';

describe('CommitDetailItem', function() {
  let atomEnv, repository, pool;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    const workdir = await cloneRepository('multiple-commits');

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
      ...override,
    };

    return (
      <PaneItem workspace={atomEnv.workspace} uriPattern={CommitDetailItem.uriPattern}>
        {({itemHolder, params}) => {
          return (
            <CommitDetailItem
              ref={itemHolder.setter}
              workingDirectory={params.workingDirectory}
              sha={params.sha}
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
      sha: '18920c900bfa6e4844853e7e246607a31c3e2e8c',
      ...options,
    };
    const uri = CommitDetailItem.buildURI(opts.workingDirectory, opts.sha);
    return atomEnv.workspace.open(uri);
  }

  it('constructs and opens the correct URI', async function() {
    const wrapper = mount(buildPaneApp());
    await open();

    assert.isTrue(wrapper.update().find('CommitDetailItem').exists());
  });

  it('passes extra props to its container', async function() {
    const extra = Symbol('extra');
    const wrapper = mount(buildPaneApp({extra}));
    await open();

    assert.strictEqual(wrapper.update().find('CommitDetailItem').prop('extra'), extra);
  });

  it('serializes itself as a CommitDetailItem', async function() {
    mount(buildPaneApp());
    const item0 = await open({workingDirectory: '/dir0', sha: '420'});
    assert.deepEqual(item0.serialize(), {
      deserializer: 'CommitDetailStub',
      uri: 'atom-github://commit-detail?workdir=%2Fdir0&sha=420',
    });

    const item1 = await open({workingDirectory: '/dir1', sha: '1337'});
    assert.deepEqual(item1.serialize(), {
      deserializer: 'CommitDetailStub',
      uri: 'atom-github://commit-detail?workdir=%2Fdir1&sha=1337',
    });
  });

  it('locates the repository from the context pool', async function() {
    const wrapper = mount(buildPaneApp());
    await open();

    assert.strictEqual(wrapper.update().find('CommitDetailContainer').prop('repository'), repository);
  });

  it('passes an absent repository if the working directory is unrecognized', async function() {
    const wrapper = mount(buildPaneApp());
    await open({workingDirectory: '/nah'});

    assert.isTrue(wrapper.update().find('CommitDetailContainer').prop('repository').isAbsent());
  });

  it('returns a fixed title and icon', async function() {
    mount(buildPaneApp());
    const item = await open({sha: '1337'});

    assert.strictEqual(item.getTitle(), 'Commit: 1337');
    assert.strictEqual(item.getIconName(), 'git-commit');
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

  it('has an item-level accessor for the current working directory & sha', async function() {
    mount(buildPaneApp());
    const item = await open({workingDirectory: '/dir7', sha: '420'});
    assert.strictEqual(item.getWorkingDirectory(), '/dir7');
    assert.strictEqual(item.getSha(), '420');
  });

  describe('initial focus', function() {
    it('brings focus to the element a child populates refInitialFocus after it loads', async function() {
      const wrapper = mount(buildPaneApp());
      // Spin forever to keep refInitialFocus from being assigned
      sinon.stub(repository, 'getCommit').returns(new Promise(() => {}));

      const item = await open();
      item.focus();
      wrapper.update();

      const refInitialFocus = wrapper.find('CommitDetailContainer').prop('refInitialFocus');
      const focusSpy = sinon.spy();
      refInitialFocus.setter({focus: focusSpy});
      await refInitialFocus.getPromise();

      assert.isTrue(focusSpy.called);
    });

    it("prevents the item from stealing focus if it's been answered", async function() {
      const wrapper = mount(buildPaneApp());
      sinon.stub(repository, 'getCommit').returns(new Promise(() => {}));

      const item = await open();
      item.preventFocus();
      item.focus();
      wrapper.update();

      const refInitialFocus = wrapper.find('CommitDetailContainer').prop('refInitialFocus');
      const focusSpy = sinon.spy();
      refInitialFocus.setter({focus: focusSpy});
      await refInitialFocus.getPromise();

      assert.isFalse(focusSpy.called);
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

      wrapper.update().find('CommitDetailContainer').prop('refEditor').setter(editor);

      const cb = sinon.spy();
      sub = item.observeEmbeddedTextEditor(cb);
      assert.isTrue(cb.calledWith(editor));
    });

    it('does not call its callback if an editor is present but destroyed', async function() {
      const wrapper = mount(buildPaneApp());
      const item = await open();

      wrapper.update().find('CommitDetailContainer').prop('refEditor').setter({isAlive() { return false; }});

      const cb = sinon.spy();
      sub = item.observeEmbeddedTextEditor(cb);
      assert.isFalse(cb.called);
    });

    it('calls its callback later if the editor changes', async function() {
      const wrapper = mount(buildPaneApp());
      const item = await open();

      const cb = sinon.spy();
      sub = item.observeEmbeddedTextEditor(cb);

      wrapper.update().find('CommitDetailContainer').prop('refEditor').setter(editor);
      assert.isTrue(cb.calledWith(editor));
    });

    it('does not call its callback after its editor is destroyed', async function() {
      const wrapper = mount(buildPaneApp());
      const item = await open();

      const cb = sinon.spy();
      sub = item.observeEmbeddedTextEditor(cb);

      wrapper.update().find('CommitDetailContainer').prop('refEditor').setter({isAlive() { return false; }});
      assert.isFalse(cb.called);
    });
  });
});
