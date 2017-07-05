temp = require('temp').track()
GitRepository = require '../src/git-repository'
fs = require 'fs-plus'
path = require 'path'
Project = require '../src/project'

copyRepository = ->
  workingDirPath = temp.mkdirSync('atom-spec-git')
  fs.copySync(path.join(__dirname, 'fixtures', 'git', 'working-dir'), workingDirPath)
  fs.renameSync(path.join(workingDirPath, 'git.git'), path.join(workingDirPath, '.git'))
  workingDirPath

describe "GitRepository", ->
  repo = null

  beforeEach ->
    gitPath = path.join(temp.dir, '.git')
    fs.removeSync(gitPath) if fs.isDirectorySync(gitPath)

  afterEach ->
    repo.destroy() if repo?.repo?
    try
      temp.cleanupSync() # These tests sometimes lag at shutting down resources

  describe "@open(path)", ->
    it "returns null when no repository is found", ->
      expect(GitRepository.open(path.join(temp.dir, 'nogit.txt'))).toBeNull()

  describe "new GitRepository(path)", ->
    it "throws an exception when no repository is found", ->
      expect(-> new GitRepository(path.join(temp.dir, 'nogit.txt'))).toThrow()

  describe ".getPath()", ->
    it "returns the repository path for a .git directory path with a directory", ->
      repo = new GitRepository(path.join(__dirname, 'fixtures', 'git', 'master.git', 'objects'))
      expect(repo.getPath()).toBe path.join(__dirname, 'fixtures', 'git', 'master.git')

    it "returns the repository path for a repository path", ->
      repo = new GitRepository(path.join(__dirname, 'fixtures', 'git', 'master.git'))
      expect(repo.getPath()).toBe path.join(__dirname, 'fixtures', 'git', 'master.git')

  describe ".isPathIgnored(path)", ->
    it "returns true for an ignored path", ->
      repo = new GitRepository(path.join(__dirname, 'fixtures', 'git', 'ignore.git'))
      expect(repo.isPathIgnored('a.txt')).toBeTruthy()

    it "returns false for a non-ignored path", ->
      repo = new GitRepository(path.join(__dirname, 'fixtures', 'git', 'ignore.git'))
      expect(repo.isPathIgnored('b.txt')).toBeFalsy()

  describe ".isPathModified(path)", ->
    [repo, filePath, newPath] = []

    beforeEach ->
      workingDirPath = copyRepository()
      repo = new GitRepository(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
      newPath = path.join(workingDirPath, 'new-path.txt')

    describe "when the path is unstaged", ->
      it "returns false if the path has not been modified", ->
        expect(repo.isPathModified(filePath)).toBeFalsy()

      it "returns true if the path is modified", ->
        fs.writeFileSync(filePath, "change")
        expect(repo.isPathModified(filePath)).toBeTruthy()

      it "returns true if the path is deleted", ->
        fs.removeSync(filePath)
        expect(repo.isPathModified(filePath)).toBeTruthy()

      it "returns false if the path is new", ->
        expect(repo.isPathModified(newPath)).toBeFalsy()

  describe ".isPathNew(path)", ->
    [filePath, newPath] = []

    beforeEach ->
      workingDirPath = copyRepository()
      repo = new GitRepository(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
      newPath = path.join(workingDirPath, 'new-path.txt')
      fs.writeFileSync(newPath, "i'm new here")

    describe "when the path is unstaged", ->
      it "returns true if the path is new", ->
        expect(repo.isPathNew(newPath)).toBeTruthy()

      it "returns false if the path isn't new", ->
        expect(repo.isPathNew(filePath)).toBeFalsy()

  describe ".checkoutHead(path)", ->
    [filePath] = []

    beforeEach ->
      workingDirPath = copyRepository()
      repo = new GitRepository(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')

    it "no longer reports a path as modified after checkout", ->
      expect(repo.isPathModified(filePath)).toBeFalsy()
      fs.writeFileSync(filePath, 'ch ch changes')
      expect(repo.isPathModified(filePath)).toBeTruthy()
      expect(repo.checkoutHead(filePath)).toBeTruthy()
      expect(repo.isPathModified(filePath)).toBeFalsy()

    it "restores the contents of the path to the original text", ->
      fs.writeFileSync(filePath, 'ch ch changes')
      expect(repo.checkoutHead(filePath)).toBeTruthy()
      expect(fs.readFileSync(filePath, 'utf8')).toBe ''

    it "fires a status-changed event if the checkout completes successfully", ->
      fs.writeFileSync(filePath, 'ch ch changes')
      repo.getPathStatus(filePath)
      statusHandler = jasmine.createSpy('statusHandler')
      repo.onDidChangeStatus statusHandler
      repo.checkoutHead(filePath)
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler.argsForCall[0][0]).toEqual {path: filePath, pathStatus: 0}

      repo.checkoutHead(filePath)
      expect(statusHandler.callCount).toBe 1

  describe ".checkoutHeadForEditor(editor)", ->
    [filePath, editor] = []

    beforeEach ->
      spyOn(atom, "confirm")

      workingDirPath = copyRepository()
      repo = new GitRepository(workingDirPath, {project: atom.project, config: atom.config, confirm: atom.confirm})
      filePath = path.join(workingDirPath, 'a.txt')
      fs.writeFileSync(filePath, 'ch ch changes')

      waitsForPromise ->
        atom.workspace.open(filePath)

      runs ->
        editor = atom.workspace.getActiveTextEditor()

    it "displays a confirmation dialog by default", ->
      return if process.platform is 'win32' # Permissions issues with this test on Windows

      atom.confirm.andCallFake ({buttons}) -> buttons.OK()
      atom.config.set('editor.confirmCheckoutHeadRevision', true)

      repo.checkoutHeadForEditor(editor)

      expect(fs.readFileSync(filePath, 'utf8')).toBe ''

    it "does not display a dialog when confirmation is disabled", ->
      return if process.platform is 'win32' # Flakey EPERM opening a.txt on Win32
      atom.config.set('editor.confirmCheckoutHeadRevision', false)

      repo.checkoutHeadForEditor(editor)

      expect(fs.readFileSync(filePath, 'utf8')).toBe ''
      expect(atom.confirm).not.toHaveBeenCalled()

  describe ".destroy()", ->
    it "throws an exception when any method is called after it is called", ->
      repo = new GitRepository(path.join(__dirname, 'fixtures', 'git', 'master.git'))
      repo.destroy()
      expect(-> repo.getShortHead()).toThrow()

  describe ".getPathStatus(path)", ->
    [filePath] = []

    beforeEach ->
      workingDirectory = copyRepository()
      repo = new GitRepository(workingDirectory)
      filePath = path.join(workingDirectory, 'file.txt')

    it "trigger a status-changed event when the new status differs from the last cached one", ->
      statusHandler = jasmine.createSpy("statusHandler")
      repo.onDidChangeStatus statusHandler
      fs.writeFileSync(filePath, '')
      status = repo.getPathStatus(filePath)
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler.argsForCall[0][0]).toEqual {path: filePath, pathStatus: status}

      fs.writeFileSync(filePath, 'abc')
      status = repo.getPathStatus(filePath)
      expect(statusHandler.callCount).toBe 1

  describe ".getDirectoryStatus(path)", ->
    [directoryPath, filePath] = []

    beforeEach ->
      workingDirectory = copyRepository()
      repo = new GitRepository(workingDirectory)
      directoryPath = path.join(workingDirectory, 'dir')
      filePath = path.join(directoryPath, 'b.txt')

    it "gets the status based on the files inside the directory", ->
      expect(repo.isStatusModified(repo.getDirectoryStatus(directoryPath))).toBe false
      fs.writeFileSync(filePath, 'abc')
      repo.getPathStatus(filePath)
      expect(repo.isStatusModified(repo.getDirectoryStatus(directoryPath))).toBe true

  describe ".refreshStatus()", ->
    [newPath, modifiedPath, cleanPath, workingDirectory] = []

    beforeEach ->
      workingDirectory = copyRepository()
      repo = new GitRepository(workingDirectory, {project: atom.project, config: atom.config})
      modifiedPath = path.join(workingDirectory, 'file.txt')
      newPath = path.join(workingDirectory, 'untracked.txt')
      cleanPath = path.join(workingDirectory, 'other.txt')
      fs.writeFileSync(cleanPath, 'Full of text')
      fs.writeFileSync(newPath, '')
      newPath = fs.absolute newPath  # specs could be running under symbol path.

    it "returns status information for all new and modified files", ->
      fs.writeFileSync(modifiedPath, 'making this path modified')
      statusHandler = jasmine.createSpy('statusHandler')
      repo.onDidChangeStatuses statusHandler
      repo.refreshStatus()

      waitsFor ->
        statusHandler.callCount > 0

      runs ->
        expect(repo.getCachedPathStatus(cleanPath)).toBeUndefined()
        expect(repo.isStatusNew(repo.getCachedPathStatus(newPath))).toBeTruthy()
        expect(repo.isStatusModified(repo.getCachedPathStatus(modifiedPath))).toBeTruthy()

    it 'caches the proper statuses when a subdir is open', ->
      subDir = path.join(workingDirectory, 'dir')
      fs.mkdirSync(subDir)

      filePath = path.join(subDir, 'b.txt')
      fs.writeFileSync(filePath, '')

      atom.project.setPaths([subDir])

      waitsForPromise ->
        atom.workspace.open('b.txt')

      statusHandler = null
      runs ->
        repo = atom.project.getRepositories()[0]

        statusHandler = jasmine.createSpy('statusHandler')
        repo.onDidChangeStatuses statusHandler
        repo.refreshStatus()

      waitsFor ->
        statusHandler.callCount > 0

      runs ->
        status = repo.getCachedPathStatus(filePath)
        expect(repo.isStatusModified(status)).toBe false
        expect(repo.isStatusNew(status)).toBe false

    it "works correctly when the project has multiple folders (regression)", ->
      atom.project.addPath(workingDirectory)
      atom.project.addPath(path.join(__dirname, 'fixtures', 'dir'))
      statusHandler = jasmine.createSpy('statusHandler')
      repo.onDidChangeStatuses statusHandler

      repo.refreshStatus()

      waitsFor ->
        statusHandler.callCount > 0

      runs ->
        expect(repo.getCachedPathStatus(cleanPath)).toBeUndefined()
        expect(repo.isStatusNew(repo.getCachedPathStatus(newPath))).toBeTruthy()
        expect(repo.isStatusModified(repo.getCachedPathStatus(modifiedPath))).toBeTruthy()

    it 'caches statuses that were looked up synchronously', ->
      originalContent = 'undefined'
      fs.writeFileSync(modifiedPath, 'making this path modified')
      repo.getPathStatus('file.txt')

      fs.writeFileSync(modifiedPath, originalContent)
      waitsForPromise -> repo.refreshStatus()
      runs ->
        expect(repo.isStatusModified(repo.getCachedPathStatus(modifiedPath))).toBeFalsy()

  describe "buffer events", ->
    [editor] = []

    beforeEach ->
      atom.project.setPaths([copyRepository()])

      waitsForPromise ->
        atom.workspace.open('other.txt').then (o) -> editor = o

    it "emits a status-changed event when a buffer is saved", ->
      editor.insertNewline()

      statusHandler = jasmine.createSpy('statusHandler')
      atom.project.getRepositories()[0].onDidChangeStatus statusHandler

      waitsForPromise ->
        editor.save()

      runs ->
        expect(statusHandler.callCount).toBe 1
        expect(statusHandler).toHaveBeenCalledWith {path: editor.getPath(), pathStatus: 256}

    it "emits a status-changed event when a buffer is reloaded", ->
      fs.writeFileSync(editor.getPath(), 'changed')

      statusHandler = jasmine.createSpy('statusHandler')
      atom.project.getRepositories()[0].onDidChangeStatus statusHandler

      waitsForPromise ->
        editor.getBuffer().reload()

      runs ->
        expect(statusHandler.callCount).toBe 1
        expect(statusHandler).toHaveBeenCalledWith {path: editor.getPath(), pathStatus: 256}

      waitsForPromise ->
        editor.getBuffer().reload()

      runs ->
        expect(statusHandler.callCount).toBe 1

    it "emits a status-changed event when a buffer's path changes", ->
      fs.writeFileSync(editor.getPath(), 'changed')

      statusHandler = jasmine.createSpy('statusHandler')
      atom.project.getRepositories()[0].onDidChangeStatus statusHandler
      editor.getBuffer().emitter.emit 'did-change-path'
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler).toHaveBeenCalledWith {path: editor.getPath(), pathStatus: 256}
      editor.getBuffer().emitter.emit 'did-change-path'
      expect(statusHandler.callCount).toBe 1

    it "stops listening to the buffer when the repository is destroyed (regression)", ->
      atom.project.getRepositories()[0].destroy()
      expect(-> editor.save()).not.toThrow()

  describe "when a project is deserialized", ->
    [buffer, project2, statusHandler] = []

    afterEach ->
      project2?.destroy()

    it "subscribes to all the serialized buffers in the project", ->
      atom.project.setPaths([copyRepository()])

      waitsForPromise ->
        atom.workspace.open('file.txt')

      waitsForPromise ->
        project2 = new Project({notificationManager: atom.notifications, packageManager: atom.packages, confirm: atom.confirm, applicationDelegate: atom.applicationDelegate})
        project2.deserialize(atom.project.serialize({isUnloading: false}))

      waitsFor ->
        buffer = project2.getBuffers()[0]

      waitsForPromise ->
        originalContent = buffer.getText()
        buffer.append('changes')

        statusHandler = jasmine.createSpy('statusHandler')
        project2.getRepositories()[0].onDidChangeStatus statusHandler
        buffer.save()

      runs ->
        expect(statusHandler.callCount).toBe 1
        expect(statusHandler).toHaveBeenCalledWith {path: buffer.getPath(), pathStatus: 256}
