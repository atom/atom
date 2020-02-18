import {watchWorkspaceItem} from '../lib/watch-workspace-item';
import URIPattern from '../lib/atom/uri-pattern';

import {registerGitHubOpener} from './helpers';

describe('watchWorkspaceItem', function() {
  let sub, atomEnv, workspace, component;

  beforeEach(function() {
    atomEnv = global.buildAtomEnvironment();
    workspace = atomEnv.workspace;

    component = {
      state: {},
      setState: sinon.stub().callsFake((updater, cb) => cb && cb()),
    };

    registerGitHubOpener(atomEnv);
  });

  afterEach(function() {
    sub && sub.dispose();
    atomEnv.destroy();
  });

  describe('initial state', function() {
    it('creates component state if none is present', function() {
      component.state = undefined;

      sub = watchWorkspaceItem(workspace, 'atom-github://item', component, 'aKey');
      assert.deepEqual(component.state, {aKey: false});
    });

    it('is false when the pane is not open', async function() {
      await workspace.open('atom-github://nonmatching');

      sub = watchWorkspaceItem(workspace, 'atom-github://item', component, 'someKey');
      assert.isFalse(component.state.someKey);
    });

    it('is false when the pane is open but not active', async function() {
      await workspace.open('atom-github://item/one');
      await workspace.open('atom-github://item/two');

      sub = watchWorkspaceItem(workspace, 'atom-github://item/one', component, 'theKey');
      assert.isFalse(component.state.theKey);
    });

    it('is true when the pane is already open and active', async function() {
      await workspace.open('atom-github://item/two');
      await workspace.open('atom-github://item/one');

      sub = watchWorkspaceItem(workspace, 'atom-github://item/one', component, 'theKey');
      assert.isTrue(component.state.theKey);
    });

    it('is true when the pane is open and active in any pane', async function() {
      await workspace.open('atom-github://some-item', {location: 'right'});
      await workspace.open('atom-github://nonmatching');

      assert.strictEqual(workspace.getRightDock().getActivePaneItem().getURI(), 'atom-github://some-item');
      assert.strictEqual(workspace.getActivePaneItem().getURI(), 'atom-github://nonmatching');

      sub = watchWorkspaceItem(workspace, 'atom-github://some-item', component, 'someKey');
      assert.isTrue(component.state.someKey);
    });

    it('accepts a preconstructed URIPattern', async function() {
      await workspace.open('atom-github://item/one');
      const u = new URIPattern('atom-github://item/{pattern}');

      sub = watchWorkspaceItem(workspace, u, component, 'theKey');
      assert.isTrue(component.state.theKey);
    });
  });

  describe('workspace events', function() {
    it('becomes true when the pane is opened', async function() {
      sub = watchWorkspaceItem(workspace, 'atom-github://item/{pattern}', component, 'theKey');
      assert.isFalse(component.state.theKey);

      await workspace.open('atom-github://item/match');

      assert.isTrue(component.setState.calledWith({theKey: true}));
    });

    it('remains true if another matching pane is opened', async function() {
      await workspace.open('atom-github://item/match0');
      sub = watchWorkspaceItem(workspace, 'atom-github://item/{pattern}', component, 'theKey');
      assert.isTrue(component.state.theKey);

      await workspace.open('atom-github://item/match1');
      assert.isFalse(component.setState.called);
    });

    it('becomes false if a nonmatching pane is opened', async function() {
      await workspace.open('atom-github://item/match0');
      sub = watchWorkspaceItem(workspace, 'atom-github://item/{pattern}', component, 'theKey');
      assert.isTrue(component.state.theKey);

      await workspace.open('atom-github://other-item/match1');
      assert.isTrue(component.setState.calledWith({theKey: false}));
    });

    it('becomes false if the last matching pane is closed', async function() {
      await workspace.open('atom-github://item/match0');
      await workspace.open('atom-github://item/match1');

      sub = watchWorkspaceItem(workspace, 'atom-github://item/{pattern}', component, 'theKey');
      assert.isTrue(component.state.theKey);

      assert.isTrue(workspace.hide('atom-github://item/match1'));
      assert.isFalse(component.setState.called);

      assert.isTrue(workspace.hide('atom-github://item/match0'));
      assert.isTrue(component.setState.calledWith({theKey: false}));
    });
  });

  it('stops updating when disposed', async function() {
    sub = watchWorkspaceItem(workspace, 'atom-github://item', component, 'theKey');
    assert.isFalse(component.state.theKey);

    sub.dispose();
    await workspace.open('atom-github://item');
    assert.isFalse(component.setState.called);

    await workspace.hide('atom-github://item');
    assert.isFalse(component.setState.called);
  });

  describe('setPattern', function() {
    it('immediately updates the state based on the new pattern', async function() {
      sub = watchWorkspaceItem(workspace, 'atom-github://item0/{pattern}', component, 'theKey');
      assert.isFalse(component.state.theKey);

      await workspace.open('atom-github://item1/match');
      assert.isFalse(component.setState.called);

      await sub.setPattern('atom-github://item1/{pattern}');
      assert.isFalse(component.state.theKey);
      assert.isTrue(component.setState.calledWith({theKey: true}));
    });

    it('uses the new pattern to keep state up to date', async function() {
      sub = watchWorkspaceItem(workspace, 'atom-github://item0/{pattern}', component, 'theKey');
      await sub.setPattern('atom-github://item1/{pattern}');

      await workspace.open('atom-github://item0/match');
      assert.isFalse(component.setState.called);

      await workspace.open('atom-github://item1/match');
      assert.isTrue(component.setState.calledWith({theKey: true}));
    });

    it('accepts a preconstructed URIPattern', async function() {
      sub = watchWorkspaceItem(workspace, 'atom-github://item0/{pattern}', component, 'theKey');
      assert.isFalse(component.state.theKey);

      await workspace.open('atom-github://item1/match');
      assert.isFalse(component.setState.called);

      await sub.setPattern(new URIPattern('atom-github://item1/{pattern}'));
      assert.isFalse(component.state.theKey);
      assert.isTrue(component.setState.calledWith({theKey: true}));
    });
  });
});
