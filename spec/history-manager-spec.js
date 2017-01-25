/** @babel */

import {it, fit, ffit, fffit, beforeEach, afterEach} from './async-spec-helpers' // eslint-disable-line no-unused-vars

import {HistoryManager, HistoryProject} from '../src/history-manager'

describe('HistoryManager', () => {
  let historyManager, commandRegistry, project, localStorage
  let commandDisposable, projectDisposable

  beforeEach(() => {
    commandDisposable = jasmine.createSpyObj('Disposable', ['dispose'])
    commandRegistry = jasmine.createSpyObj('CommandRegistry', ['add'])
    commandRegistry.add.andReturn(commandDisposable)

    localStorage = jasmine.createSpyObj('LocalStorage', ['getItem', 'setItem'])
    localStorage.items = {
      history: JSON.stringify({
        projects: [
          { paths: ['/1', 'c:\\2'], lastOpened: new Date(2016, 9, 17, 17, 16, 23) },
          { paths: ['/test'], lastOpened: new Date(2016, 9, 17, 11, 12, 13) }
        ]
      })
    }
    localStorage.getItem.andCallFake((key) => localStorage.items[key])
    localStorage.setItem.andCallFake((key, value) => (localStorage.items[key] = value))

    projectDisposable = jasmine.createSpyObj('Disposable', ['dispose'])
    project = jasmine.createSpyObj('Project', ['onDidChangePaths'])
    project.onDidChangePaths.andCallFake((f) => {
      project.didChangePathsListener = f
      return projectDisposable
    })

    historyManager = new HistoryManager({project, commands: commandRegistry, localStorage})
  })

  describe('constructor', () => {
    it('registers the "clear-project-history" command function', () => {
      expect(commandRegistry.add).toHaveBeenCalled()
      const cmdCall = commandRegistry.add.calls[0]
      expect(cmdCall.args.length).toBe(2)
      expect(cmdCall.args[0]).toBe('atom-workspace')
      expect(typeof cmdCall.args[1]['application:clear-project-history']).toBe('function')
    })

    describe('getProjects', () => {
      it('returns an array of HistoryProjects', () => {
        expect(historyManager.getProjects()).toEqual([
          new HistoryProject(['/1', 'c:\\2'], new Date(2016, 9, 17, 17, 16, 23)),
          new HistoryProject(['/test'], new Date(2016, 9, 17, 11, 12, 13))
        ])
      })

      it('returns an array of HistoryProjects that is not mutable state', () => {
        const firstProjects = historyManager.getProjects()
        firstProjects.pop()
        firstProjects[0].path = 'modified'

        const secondProjects = historyManager.getProjects()
        expect(secondProjects.length).toBe(2)
        expect(secondProjects[0].path).not.toBe('modified')
      })
    })

    describe('clearProjects', () => {
      it('clears the list of projects', () => {
        expect(historyManager.getProjects().length).not.toBe(0)
        historyManager.clearProjects()
        expect(historyManager.getProjects().length).toBe(0)
      })

      it('saves the state', () => {
        expect(localStorage.setItem).not.toHaveBeenCalled()
        historyManager.clearProjects()
        expect(localStorage.setItem).toHaveBeenCalled()
        expect(localStorage.setItem.calls[0].args[0]).toBe('history')
        expect(historyManager.getProjects().length).toBe(0)
      })

      it('fires the onDidChangeProjects event', () => {
        expect(localStorage.setItem).not.toHaveBeenCalled()
        historyManager.clearProjects()
        expect(localStorage.setItem).toHaveBeenCalled()
        expect(localStorage.setItem.calls[0].args[0]).toBe('history')
        expect(historyManager.getProjects().length).toBe(0)
      })
    })

    it('loads state', () => {
      expect(localStorage.getItem).toHaveBeenCalledWith('history')
    })

    it('listens to project.onDidChangePaths adding a new project', () => {
      const start = new Date()
      project.didChangePathsListener(['/a/new', '/path/or/two'])
      const projects = historyManager.getProjects()
      expect(projects.length).toBe(3)
      expect(projects[0].paths).toEqual(['/a/new', '/path/or/two'])
      expect(projects[0].lastOpened).not.toBeLessThan(start)
    })

    it('listens to project.onDidChangePaths updating an existing project', () => {
      const start = new Date()
      project.didChangePathsListener(['/test'])
      const projects = historyManager.getProjects()
      expect(projects.length).toBe(2)
      expect(projects[0].paths).toEqual(['/test'])
      expect(projects[0].lastOpened).not.toBeLessThan(start)
    })
  })

  describe('loadState', () => {
    it('defaults to an empty array if no state', () => {
      localStorage.items.history = null
      historyManager.loadState()
      expect(historyManager.getProjects()).toEqual([])
    })

    it('defaults to an empty array if no projects', () => {
      localStorage.items.history = JSON.stringify('')
      historyManager.loadState()
      expect(historyManager.getProjects()).toEqual([])
    })
  })

  describe('addProject', () => {
    it('adds a new project to the end', () => {
      const date = new Date(2010, 10, 9, 8, 7, 6)
      historyManager.addProject(['/a/b'], date)
      const projects = historyManager.getProjects()
      expect(projects.length).toBe(3)
      expect(projects[2].paths).toEqual(['/a/b'])
      expect(projects[2].lastOpened).toBe(date)
    })

    it('adds a new project to the start', () => {
      const date = new Date()
      historyManager.addProject(['/so/new'], date)
      const projects = historyManager.getProjects()
      expect(projects.length).toBe(3)
      expect(projects[0].paths).toEqual(['/so/new'])
      expect(projects[0].lastOpened).toBe(date)
    })

    it('updates an existing project and moves it to the start', () => {
      const date = new Date()
      historyManager.addProject(['/test'], date)
      const projects = historyManager.getProjects()
      expect(projects.length).toBe(2)
      expect(projects[0].paths).toEqual(['/test'])
      expect(projects[0].lastOpened).toBe(date)
    })

    it('fires the onDidChangeProjects event when adding a project', () => {
      const didChangeSpy = jasmine.createSpy()
      const beforeCount = historyManager.getProjects().length
      historyManager.onDidChangeProjects(didChangeSpy)
      historyManager.addProject(['/test-new'], new Date())
      expect(didChangeSpy).toHaveBeenCalled()
      expect(historyManager.getProjects().length).toBe(beforeCount + 1)
    })

    it('fires the onDidChangeProjects event when updating a project', () => {
      const didChangeSpy = jasmine.createSpy()
      const beforeCount = historyManager.getProjects().length
      historyManager.onDidChangeProjects(didChangeSpy)
      historyManager.addProject(['/test'], new Date())
      expect(didChangeSpy).toHaveBeenCalled()
      expect(historyManager.getProjects().length).toBe(beforeCount)
    })
  })

  describe('getProject', () => {
    it('returns a project that matches the paths', () => {
      const project = historyManager.getProject(['/1', 'c:\\2'])
      expect(project).not.toBeNull()
      expect(project.paths).toEqual(['/1', 'c:\\2'])
    })

    it('returns null when it can\'t find the project', () => {
      const project = historyManager.getProject(['/1'])
      expect(project).toBeNull()
    })
  })

  describe('saveState', () => {
    it('saves the state', () => {
      historyManager.addProject(['/save/state'])
      historyManager.saveState()
      expect(localStorage.setItem).toHaveBeenCalled()
      expect(localStorage.setItem.calls[0].args[0]).toBe('history')
      expect(localStorage.items['history']).toContain('/save/state')
      historyManager.loadState()
      expect(historyManager.getProjects()[0].paths).toEqual(['/save/state'])
    })
  })
})
