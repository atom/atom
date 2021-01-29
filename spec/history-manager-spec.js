const { HistoryManager, HistoryProject } = require('../src/history-manager');
const StateStore = require('../src/state-store');

describe('HistoryManager', () => {
  let historyManager, commandRegistry, project, stateStore;
  let commandDisposable, projectDisposable;

  beforeEach(async () => {
    commandDisposable = jasmine.createSpyObj('Disposable', ['dispose']);
    commandRegistry = jasmine.createSpyObj('CommandRegistry', ['add']);
    commandRegistry.add.andReturn(commandDisposable);

    stateStore = new StateStore('history-manager-test', 1);
    await stateStore.save('history-manager', {
      projects: [
        {
          paths: ['/1', 'c:\\2'],
          lastOpened: new Date(2016, 9, 17, 17, 16, 23)
        },
        { paths: ['/test'], lastOpened: new Date(2016, 9, 17, 11, 12, 13) }
      ]
    });

    projectDisposable = jasmine.createSpyObj('Disposable', ['dispose']);
    project = jasmine.createSpyObj('Project', ['onDidChangePaths']);
    project.onDidChangePaths.andCallFake(f => {
      project.didChangePathsListener = f;
      return projectDisposable;
    });

    historyManager = new HistoryManager({
      stateStore,
      project,
      commands: commandRegistry
    });
    await historyManager.loadState();
  });

  afterEach(async () => {
    await stateStore.clear();
  });

  describe('constructor', () => {
    it("registers the 'clear-project-history' command function", () => {
      expect(commandRegistry.add).toHaveBeenCalled();
      const cmdCall = commandRegistry.add.calls[0];
      expect(cmdCall.args.length).toBe(3);
      expect(cmdCall.args[0]).toBe('atom-workspace');
      expect(typeof cmdCall.args[1]['application:clear-project-history']).toBe(
        'function'
      );
    });

    describe('getProjects', () => {
      it('returns an array of HistoryProjects', () => {
        expect(historyManager.getProjects()).toEqual([
          new HistoryProject(
            ['/1', 'c:\\2'],
            new Date(2016, 9, 17, 17, 16, 23)
          ),
          new HistoryProject(['/test'], new Date(2016, 9, 17, 11, 12, 13))
        ]);
      });

      it('returns an array of HistoryProjects that is not mutable state', () => {
        const firstProjects = historyManager.getProjects();
        firstProjects.pop();
        firstProjects[0].path = 'modified';

        const secondProjects = historyManager.getProjects();
        expect(secondProjects.length).toBe(2);
        expect(secondProjects[0].path).not.toBe('modified');
      });
    });

    describe('clearProjects', () => {
      it('clears the list of projects', async () => {
        expect(historyManager.getProjects().length).not.toBe(0);
        await historyManager.clearProjects();
        expect(historyManager.getProjects().length).toBe(0);
      });

      it('saves the state', async () => {
        await historyManager.clearProjects();
        const historyManager2 = new HistoryManager({
          stateStore,
          project,
          commands: commandRegistry
        });
        await historyManager2.loadState();
        expect(historyManager.getProjects().length).toBe(0);
      });

      it('fires the onDidChangeProjects event', async () => {
        const didChangeSpy = jasmine.createSpy();
        historyManager.onDidChangeProjects(didChangeSpy);
        await historyManager.clearProjects();
        expect(historyManager.getProjects().length).toBe(0);
        expect(didChangeSpy).toHaveBeenCalled();
      });
    });

    it('listens to project.onDidChangePaths adding a new project', () => {
      const start = new Date();
      project.didChangePathsListener(['/a/new', '/path/or/two']);
      const projects = historyManager.getProjects();
      expect(projects.length).toBe(3);
      expect(projects[0].paths).toEqual(['/a/new', '/path/or/two']);
      expect(projects[0].lastOpened).not.toBeLessThan(start);
    });

    it('listens to project.onDidChangePaths updating an existing project', () => {
      const start = new Date();
      project.didChangePathsListener(['/test']);
      const projects = historyManager.getProjects();
      expect(projects.length).toBe(2);
      expect(projects[0].paths).toEqual(['/test']);
      expect(projects[0].lastOpened).not.toBeLessThan(start);
    });
  });

  describe('loadState', () => {
    it('defaults to an empty array if no state', async () => {
      await stateStore.clear();
      await historyManager.loadState();
      expect(historyManager.getProjects()).toEqual([]);
    });

    it('defaults to an empty array if no projects', async () => {
      await stateStore.save('history-manager', {});
      await historyManager.loadState();
      expect(historyManager.getProjects()).toEqual([]);
    });
  });

  describe('addProject', () => {
    it('adds a new project to the end', async () => {
      const date = new Date(2010, 10, 9, 8, 7, 6);
      await historyManager.addProject(['/a/b'], date);
      const projects = historyManager.getProjects();
      expect(projects.length).toBe(3);
      expect(projects[2].paths).toEqual(['/a/b']);
      expect(projects[2].lastOpened).toBe(date);
    });

    it('adds a new project to the start', async () => {
      const date = new Date();
      await historyManager.addProject(['/so/new'], date);
      const projects = historyManager.getProjects();
      expect(projects.length).toBe(3);
      expect(projects[0].paths).toEqual(['/so/new']);
      expect(projects[0].lastOpened).toBe(date);
    });

    it('updates an existing project and moves it to the start', async () => {
      const date = new Date();
      await historyManager.addProject(['/test'], date);
      const projects = historyManager.getProjects();
      expect(projects.length).toBe(2);
      expect(projects[0].paths).toEqual(['/test']);
      expect(projects[0].lastOpened).toBe(date);
    });

    it('fires the onDidChangeProjects event when adding a project', async () => {
      const didChangeSpy = jasmine.createSpy();
      const beforeCount = historyManager.getProjects().length;
      historyManager.onDidChangeProjects(didChangeSpy);
      await historyManager.addProject(['/test-new'], new Date());
      expect(didChangeSpy).toHaveBeenCalled();
      expect(historyManager.getProjects().length).toBe(beforeCount + 1);
    });

    it('fires the onDidChangeProjects event when updating a project', async () => {
      const didChangeSpy = jasmine.createSpy();
      const beforeCount = historyManager.getProjects().length;
      historyManager.onDidChangeProjects(didChangeSpy);
      await historyManager.addProject(['/test'], new Date());
      expect(didChangeSpy).toHaveBeenCalled();
      expect(historyManager.getProjects().length).toBe(beforeCount);
    });
  });

  describe('getProject', () => {
    it('returns a project that matches the paths', () => {
      const project = historyManager.getProject(['/1', 'c:\\2']);
      expect(project).not.toBeNull();
      expect(project.paths).toEqual(['/1', 'c:\\2']);
    });

    it("returns null when it can't find the project", () => {
      const project = historyManager.getProject(['/1']);
      expect(project).toBeNull();
    });
  });

  describe('saveState', () => {
    let savedHistory;
    beforeEach(() => {
      // historyManager.saveState is spied on globally to prevent specs from
      // modifying the shared project history. Since these tests depend on
      // saveState, we unspy it but in turn spy on the state store instead
      // so that no data is actually stored to it.
      jasmine.unspy(historyManager, 'saveState');

      spyOn(historyManager.stateStore, 'save').andCallFake((name, history) => {
        savedHistory = history;
        return Promise.resolve();
      });
    });

    it('saves the state', async () => {
      await historyManager.addProject(['/save/state']);
      await historyManager.saveState();
      const historyManager2 = new HistoryManager({
        stateStore,
        project,
        commands: commandRegistry
      });
      spyOn(historyManager2.stateStore, 'load').andCallFake(name =>
        Promise.resolve(savedHistory)
      );
      await historyManager2.loadState();
      expect(historyManager2.getProjects()[0].paths).toEqual(['/save/state']);
    });
  });
});
