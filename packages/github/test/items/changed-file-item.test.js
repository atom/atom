import path from 'path';
import React from 'react';
import {mount} from 'enzyme';

import PaneItem from '../../lib/atom/pane-item';
import ChangedFileItem from '../../lib/items/changed-file-item';
import WorkdirContextPool from '../../lib/models/workdir-context-pool';
import {cloneRepository} from '../helpers';

describe('ChangedFileItem', function() {
  let atomEnv, repository, pool;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();

    const workdirPath = await cloneRepository();

    pool = new WorkdirContextPool({
      workspace: atomEnv.workspace,
    });
    repository = pool.add(workdirPath).getRepository();
  });

  afterEach(function() {
    atomEnv.destroy();
    pool.clear();
  });

  function buildPaneApp(overrideProps = {}) {
    const props = {
      workdirContextPool: pool,
      workspace: atomEnv.workspace,
      commands: atomEnv.commands,
      keymaps: atomEnv.keymaps,
      tooltips: atomEnv.tooltips,
      config: atomEnv.config,
      discardLines: () => {},
      undoLastDiscard: () => {},
      surfaceFileAtPath: () => {},
      ...overrideProps,
    };

    return (
      <PaneItem workspace={atomEnv.workspace} uriPattern={ChangedFileItem.uriPattern}>
        {({itemHolder, params}) => {
          return (
            <ChangedFileItem
              ref={itemHolder.setter}
              workingDirectory={params.workingDirectory}
              relPath={path.join(...params.relPath)}
              stagingStatus={params.stagingStatus}
              {...props}
            />
          );
        }}
      </PaneItem>
    );
  }

  function open(options = {}) {
    const opts = {
      relPath: 'a.txt',
      workingDirectory: repository.getWorkingDirectoryPath(),
      stagingStatus: 'unstaged',
      ...options,
    };
    const uri = ChangedFileItem.buildURI(opts.relPath, opts.workingDirectory, opts.stagingStatus);
    return atomEnv.workspace.open(uri);
  }

  it('locates the repository from the context pool', async function() {
    const wrapper = mount(buildPaneApp());
    await open();

    assert.strictEqual(wrapper.update().find('ChangedFileContainer').prop('repository'), repository);
  });

  it('passes an absent repository if the working directory is unrecognized', async function() {
    const wrapper = mount(buildPaneApp());
    await open({workingDirectory: '/nope'});

    assert.isTrue(wrapper.update().find('ChangedFileContainer').prop('repository').isAbsent());
  });

  it('passes other props to the container', async function() {
    const other = Symbol('other');
    const wrapper = mount(buildPaneApp({other}));
    await open();

    assert.strictEqual(wrapper.update().find('ChangedFileContainer').prop('other'), other);
  });

  describe('getTitle()', function() {
    it('renders an unstaged title', async function() {
      mount(buildPaneApp());
      const item = await open({stagingStatus: 'unstaged'});

      assert.strictEqual(item.getTitle(), 'Unstaged Changes: a.txt');
    });

    it('renders a staged title', async function() {
      mount(buildPaneApp());
      const item = await open({stagingStatus: 'staged'});

      assert.strictEqual(item.getTitle(), 'Staged Changes: a.txt');
    });
  });

  describe('buildURI', function() {
    it('correctly uri encodes all components', function() {
      const filePathWithSpecialChars = '???.txt';
      const stagingStatus = 'staged';
      const workdirPath = '/???/!!!';

      const uri = ChangedFileItem.buildURI(filePathWithSpecialChars, workdirPath, stagingStatus);
      assert.include(uri, encodeURIComponent(filePathWithSpecialChars));
      assert.include(uri, encodeURIComponent(workdirPath));
      assert.include(uri, encodeURIComponent(stagingStatus));
    });
  });

  it('terminates pending state', async function() {
    const wrapper = mount(buildPaneApp());

    const item = await open(wrapper);
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
    const wrapper = mount(buildPaneApp());

    const item = await open(wrapper);
    const callback = sinon.spy();
    const sub = item.onDidDestroy(callback);

    assert.strictEqual(callback.callCount, 0);
    item.destroy();
    assert.strictEqual(callback.callCount, 1);

    sub.dispose();
  });

  it('serializes itself as a FilePatchControllerStub', async function() {
    mount(buildPaneApp());
    const item0 = await open({relPath: 'a.txt', workingDirectory: '/dir0', stagingStatus: 'unstaged'});
    assert.deepEqual(item0.serialize(), {
      deserializer: 'FilePatchControllerStub',
      uri: 'atom-github://file-patch/a.txt?workdir=%2Fdir0&stagingStatus=unstaged',
    });

    const item1 = await open({relPath: 'b.txt', workingDirectory: '/dir1', stagingStatus: 'staged'});
    assert.deepEqual(item1.serialize(), {
      deserializer: 'FilePatchControllerStub',
      uri: 'atom-github://file-patch/b.txt?workdir=%2Fdir1&stagingStatus=staged',
    });
  });

  it('has some item-level accessors', async function() {
    mount(buildPaneApp());
    const item = await open({relPath: 'a.txt', workingDirectory: '/dir', stagingStatus: 'unstaged'});

    assert.strictEqual(item.getStagingStatus(), 'unstaged');
    assert.strictEqual(item.getFilePath(), 'a.txt');
    assert.strictEqual(item.getWorkingDirectory(), '/dir');
    assert.isTrue(item.isFilePatchItem());
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

      wrapper.update().find('ChangedFileContainer').prop('refEditor').setter(editor);

      const cb = sinon.spy();
      sub = item.observeEmbeddedTextEditor(cb);
      assert.isTrue(cb.calledWith(editor));
    });

    it('does not call its callback if an editor is present but destroyed', async function() {
      const wrapper = mount(buildPaneApp());
      const item = await open();

      wrapper.update().find('ChangedFileContainer').prop('refEditor').setter({isAlive() { return false; }});

      const cb = sinon.spy();
      sub = item.observeEmbeddedTextEditor(cb);
      assert.isFalse(cb.called);
    });

    it('calls its callback later if the editor changes', async function() {
      const wrapper = mount(buildPaneApp());
      const item = await open();

      const cb = sinon.spy();
      sub = item.observeEmbeddedTextEditor(cb);

      wrapper.update().find('ChangedFileContainer').prop('refEditor').setter(editor);
      assert.isTrue(cb.calledWith(editor));
    });

    it('does not call its callback after its editor is destroyed', async function() {
      const wrapper = mount(buildPaneApp());
      const item = await open();

      const cb = sinon.spy();
      sub = item.observeEmbeddedTextEditor(cb);

      wrapper.update().find('ChangedFileContainer').prop('refEditor').setter({isAlive() { return false; }});
      assert.isFalse(cb.called);
    });
  });
});
