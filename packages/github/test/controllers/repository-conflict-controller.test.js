import path from 'path';
import React from 'react';
import {mount} from 'enzyme';

import {cloneRepository, buildRepository} from '../helpers';

import RepositoryConflictController from '../../lib/controllers/repository-conflict-controller';
import EditorConflictController from '../../lib/controllers/editor-conflict-controller';

describe('RepositoryConflictController', () => {
  let atomEnv, workspace, app;

  beforeEach(() => {
    atomEnv = global.buildAtomEnvironment();
    atomEnv.config.set('github.graphicalConflictResolution', true);
    workspace = atomEnv.workspace;
    const commands = atomEnv.commands;

    app = <RepositoryConflictController workspace={workspace} config={atomEnv.config} commands={commands} />;
  });

  afterEach(() => atomEnv.destroy());

  describe('with no conflicts', () => {
    it('renders no children', async () => {
      const workdirPath = await cloneRepository('merge-conflict');
      const repository = await buildRepository(workdirPath);

      await Promise.all(['modified-on-both-ours.txt', 'modified-on-both-theirs.txt'].map(basename => {
        return workspace.open(path.join(workdirPath, basename));
      }));

      app = React.cloneElement(app, {repository});
      const wrapper = mount(app);

      assert.equal(wrapper.find(EditorConflictController).length, 0);
    });
  });

  describe('with conflicts but no open editors', () => {
    it('renders no children', async () => {
      const workdirPath = await cloneRepository('merge-conflict');
      const repository = await buildRepository(workdirPath);

      assert.isRejected(repository.git.merge('origin/branch'));

      app = React.cloneElement(app, {repository});
      const wrapper = mount(app);

      assert.equal(wrapper.find(EditorConflictController).length, 0);
    });
  });

  describe('with conflicts and open editors', () => {
    it('renders an EditorConflictController for each conflicting editor', async () => {
      const workdirPath = await cloneRepository('merge-conflict');
      const repository = await buildRepository(workdirPath);

      await assert.isRejected(repository.git.merge('origin/branch'));

      await Promise.all(['modified-on-both-ours.txt', 'modified-on-both-theirs.txt'].map(basename => {
        return workspace.open(path.join(workdirPath, basename));
      }));

      app = React.cloneElement(app, {repository});
      const wrapper = mount(app);

      await assert.async.equal(wrapper.update().find(EditorConflictController).length, 2);
    });
  });

  describe('with the configuration option disabled', function() {
    beforeEach(function() {
      atomEnv.config.set('github.graphicalConflictResolution', false);
    });

    it('renders no children', async function() {
      const workdirPath = await cloneRepository('merge-conflict');
      const repository = await buildRepository(workdirPath);

      await assert.isRejected(repository.git.merge('origin/branch'));

      await Promise.all(['modified-on-both-ours.txt', 'modified-on-both-theirs.txt'].map(basename => {
        return workspace.open(path.join(workdirPath, basename));
      }));

      app = React.cloneElement(app, {repository});
      const wrapper = mount(app);

      await assert.async.lengthOf(wrapper.find(EditorConflictController), 0);
    });
  });
});
