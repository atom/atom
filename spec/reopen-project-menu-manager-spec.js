/** @babel */

import { Disposable } from 'event-kit';

const ReopenProjectMenuManager = require('../src/reopen-project-menu-manager');

function numberRange(low, high) {
  const size = high - low;
  const result = new Array(size);
  for (var i = 0; i < size; i++) result[i] = low + i;
  return result;
}

describe('ReopenProjectMenuManager', () => {
  let menuManager, commandRegistry, config, historyManager, reopenProjects;
  let commandDisposable, configDisposable, historyDisposable;
  let openFunction;

  beforeEach(() => {
    menuManager = jasmine.createSpyObj('MenuManager', ['add']);
    menuManager.add.andReturn(new Disposable());

    commandRegistry = jasmine.createSpyObj('CommandRegistry', ['add']);
    commandDisposable = jasmine.createSpyObj('Disposable', ['dispose']);
    commandRegistry.add.andReturn(commandDisposable);

    config = jasmine.createSpyObj('Config', ['onDidChange', 'get']);
    config.get.andReturn(10);
    configDisposable = jasmine.createSpyObj('Disposable', ['dispose']);
    config.didChangeListener = {};
    config.onDidChange.andCallFake((key, fn) => {
      config.didChangeListener[key] = fn;
      return configDisposable;
    });

    historyManager = jasmine.createSpyObj('historyManager', [
      'getProjects',
      'onDidChangeProjects'
    ]);
    historyManager.getProjects.andReturn([]);
    historyDisposable = jasmine.createSpyObj('Disposable', ['dispose']);
    historyManager.onDidChangeProjects.andCallFake(fn => {
      historyManager.changeProjectsListener = fn;
      return historyDisposable;
    });

    openFunction = jasmine.createSpy();
    reopenProjects = new ReopenProjectMenuManager({
      menu: menuManager,
      commands: commandRegistry,
      history: historyManager,
      config,
      open: openFunction
    });
  });

  describe('constructor', () => {
    it("registers the 'reopen-project' command function", () => {
      expect(commandRegistry.add).toHaveBeenCalled();
      const cmdCall = commandRegistry.add.calls[0];
      expect(cmdCall.args.length).toBe(2);
      expect(cmdCall.args[0]).toBe('atom-workspace');
      expect(typeof cmdCall.args[1]['application:reopen-project']).toBe(
        'function'
      );
    });
  });

  describe('dispose', () => {
    it('disposes of the history, command and config disposables', () => {
      reopenProjects.dispose();
      expect(historyDisposable.dispose).toHaveBeenCalled();
      expect(configDisposable.dispose).toHaveBeenCalled();
      expect(commandDisposable.dispose).toHaveBeenCalled();
    });

    it('disposes of the menu disposable once used', () => {
      const menuDisposable = jasmine.createSpyObj('Disposable', ['dispose']);
      menuManager.add.andReturn(menuDisposable);
      reopenProjects.update();
      expect(menuDisposable.dispose).not.toHaveBeenCalled();
      reopenProjects.dispose();
      expect(menuDisposable.dispose).toHaveBeenCalled();
    });
  });

  describe('the command', () => {
    it('calls open with the paths of the project specified by the detail index', () => {
      historyManager.getProjects.andReturn([
        { paths: ['/a'] },
        { paths: ['/b', 'c:\\'] }
      ]);
      reopenProjects.update();

      const reopenProjectCommand =
        commandRegistry.add.calls[0].args[1]['application:reopen-project'];
      reopenProjectCommand({ detail: { index: 1 } });

      expect(openFunction).toHaveBeenCalled();
      expect(openFunction.calls[0].args[0]).toEqual(['/b', 'c:\\']);
    });

    it('does not call open when no command detail is supplied', () => {
      const reopenProjectCommand =
        commandRegistry.add.calls[0].args[1]['application:reopen-project'];
      reopenProjectCommand({});

      expect(openFunction).not.toHaveBeenCalled();
    });

    it('does not call open when no command detail index is supplied', () => {
      const reopenProjectCommand =
        commandRegistry.add.calls[0].args[1]['application:reopen-project'];
      reopenProjectCommand({ detail: { anything: 'here' } });

      expect(openFunction).not.toHaveBeenCalled();
    });
  });

  describe('update', () => {
    it('adds menu items to MenuManager based on projects from HistoryManager', () => {
      historyManager.getProjects.andReturn([
        { paths: ['/a'] },
        { paths: ['/b', 'c:\\'] }
      ]);
      reopenProjects.update();
      expect(historyManager.getProjects).toHaveBeenCalled();
      expect(menuManager.add).toHaveBeenCalled();
      const menuArg = menuManager.add.calls[0].args[0];
      expect(menuArg.length).toBe(1);
      expect(menuArg[0].label).toBe('File');
      expect(menuArg[0].submenu.length).toBe(1);
      const projectsMenu = menuArg[0].submenu[0];
      expect(projectsMenu.label).toBe('Reopen Project');
      expect(projectsMenu.submenu.length).toBe(2);

      const first = projectsMenu.submenu[0];
      expect(first.label).toBe('/a');
      expect(first.command).toBe('application:reopen-project');
      expect(first.commandDetail).toEqual({ index: 0, paths: ['/a'] });

      const second = projectsMenu.submenu[1];
      expect(second.label).toBe('b, c:\\');
      expect(second.command).toBe('application:reopen-project');
      expect(second.commandDetail).toEqual({ index: 1, paths: ['/b', 'c:\\'] });
    });

    it("adds only the number of menu items specified in the 'core.reopenProjectMenuCount' config", () => {
      historyManager.getProjects.andReturn(
        numberRange(1, 100).map(i => ({ paths: ['/test/' + i] }))
      );
      reopenProjects.update();
      expect(menuManager.add).toHaveBeenCalled();
      const menu = menuManager.add.calls[0].args[0][0];
      expect(menu.label).toBe('File');
      expect(menu.submenu.length).toBe(1);
      expect(menu.submenu[0].label).toBe('Reopen Project');
      expect(menu.submenu[0].submenu.length).toBe(10);
    });

    it('disposes the previously menu built', () => {
      const menuDisposable = jasmine.createSpyObj('Disposable', ['dispose']);
      menuManager.add.andReturn(menuDisposable);
      reopenProjects.update();
      expect(menuDisposable.dispose).not.toHaveBeenCalled();
      reopenProjects.update();
      expect(menuDisposable.dispose).toHaveBeenCalled();
    });

    it("is called when the Config changes for 'core.reopenProjectMenuCount'", () => {
      historyManager.getProjects.andReturn(
        numberRange(1, 100).map(i => ({ paths: ['/test/' + i] }))
      );
      reopenProjects.update();
      config.get.andReturn(25);
      config.didChangeListener['core.reopenProjectMenuCount']({
        oldValue: 10,
        newValue: 25
      });

      const finalArgs = menuManager.add.calls[1].args[0];
      const projectsMenu = finalArgs[0].submenu[0].submenu;

      expect(projectsMenu.length).toBe(25);
    });

    it("is called when the HistoryManager's projects change", () => {
      reopenProjects.update();
      historyManager.getProjects.andReturn([
        { paths: ['/a'] },
        { paths: ['/b', 'c:\\'] }
      ]);
      historyManager.changeProjectsListener();
      expect(menuManager.add.calls.length).toBe(2);

      const finalArgs = menuManager.add.calls[1].args[0];
      const projectsMenu = finalArgs[0].submenu[0];

      const first = projectsMenu.submenu[0];
      expect(first.label).toBe('/a');
      expect(first.command).toBe('application:reopen-project');
      expect(first.commandDetail).toEqual({ index: 0, paths: ['/a'] });

      const second = projectsMenu.submenu[1];
      expect(second.label).toBe('b, c:\\');
      expect(second.command).toBe('application:reopen-project');
      expect(second.commandDetail).toEqual({ index: 1, paths: ['/b', 'c:\\'] });
    });
  });

  describe('updateProjects', () => {
    it('creates correct menu items commands for recent projects', () => {
      const projects = [
        { paths: ['/users/neila'] },
        { paths: ['/users/buzza', 'users/michaelc'] }
      ];

      const menu = ReopenProjectMenuManager.createProjectsMenu(projects);
      expect(menu.label).toBe('File');
      expect(menu.submenu.length).toBe(1);

      const recentMenu = menu.submenu[0];
      expect(recentMenu.label).toBe('Reopen Project');
      expect(recentMenu.submenu.length).toBe(2);

      const first = recentMenu.submenu[0];
      expect(first.label).toBe('/users/neila');
      expect(first.command).toBe('application:reopen-project');
      expect(first.commandDetail).toEqual({
        index: 0,
        paths: ['/users/neila']
      });

      const second = recentMenu.submenu[1];
      expect(second.label).toBe('buzza, michaelc');
      expect(second.command).toBe('application:reopen-project');
      expect(second.commandDetail).toEqual({
        index: 1,
        paths: ['/users/buzza', 'users/michaelc']
      });
    });
  });

  describe('createLabel', () => {
    it('returns the Unix path unchanged if there is only one', () => {
      const label = ReopenProjectMenuManager.createLabel({
        paths: ['/a/b/c/d/e/f']
      });
      expect(label).toBe('/a/b/c/d/e/f');
    });

    it('returns the Windows path unchanged if there is only one', () => {
      const label = ReopenProjectMenuManager.createLabel({
        paths: ['c:\\missions\\apollo11']
      });
      expect(label).toBe('c:\\missions\\apollo11');
    });

    it('returns the URL unchanged if there is only one', () => {
      const label = ReopenProjectMenuManager.createLabel({
        paths: ['https://launch.pad/apollo/11']
      });
      expect(label).toBe('https://launch.pad/apollo/11');
    });

    it('returns a comma-separated list of base names if there are multiple', () => {
      const project = {
        paths: ['/var/one', '/usr/bin/two', '/etc/mission/control/three']
      };
      const label = ReopenProjectMenuManager.createLabel(project);
      expect(label).toBe('one, two, three');
    });

    describe('betterBaseName', () => {
      it('returns the standard base name for an absolute Unix path', () => {
        const name = ReopenProjectMenuManager.betterBaseName('/one/to/three');
        expect(name).toBe('three');
      });

      it('returns the standard base name for a relative Windows path', () => {
        if (process.platform === 'win32') {
          const name = ReopenProjectMenuManager.betterBaseName('.\\one\\two');
          expect(name).toBe('two');
        }
      });

      it('returns the standard base name for an absolute Windows path', () => {
        if (process.platform === 'win32') {
          const name = ReopenProjectMenuManager.betterBaseName(
            'c:\\missions\\apollo\\11'
          );
          expect(name).toBe('11');
        }
      });

      it('returns the drive root for a Windows drive name', () => {
        const name = ReopenProjectMenuManager.betterBaseName('d:');
        expect(name).toBe('d:\\');
      });

      it('returns the drive root for a Windows drive root', () => {
        const name = ReopenProjectMenuManager.betterBaseName('e:\\');
        expect(name).toBe('e:\\');
      });

      it('returns the final path for a URI', () => {
        const name = ReopenProjectMenuManager.betterBaseName(
          'https://something/else'
        );
        expect(name).toBe('else');
      });
    });
  });
});
