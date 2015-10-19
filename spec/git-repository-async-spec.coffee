temp = require 'temp'
GitRepositoryAsync = require '../src/git-repository-async'
Git = require 'nodegit'
fs = require 'fs-plus'
os = require 'os'
path = require 'path'
Task = require '../src/task'
Project = require '../src/project'

# Clean up when the process exits
temp.track()

copyRepository = ->
  workingDirPath = temp.mkdirSync('atom-working-dir')
  fs.copySync(path.join(__dirname, 'fixtures', 'git', 'working-dir'), workingDirPath)
  fs.renameSync(path.join(workingDirPath, 'git.git'), path.join(workingDirPath, '.git'))
  fs.realpathSync(workingDirPath)

openFixture = (fixture)->
  GitRepositoryAsync.open(path.join(__dirname, 'fixtures', 'git', fixture))

describe "GitRepositoryAsync", ->
  repo = null

  # beforeEach ->
  #   gitPath = path.join(temp.dir, '.git')
  #   fs.removeSync(gitPath) if fs.isDirectorySync(gitPath)
  #
  # afterEach ->
  #   repo.destroy() if repo?.repo?

  describe "@open(path)", ->

    # This just exercises the framework, but I'm trying to match the sync specs to start
    it "repo is null when no repository is found", ->
      repo = GitRepositoryAsync.open(path.join(temp.dir, 'nogit.txt'))

      waitsForPromise {shouldReject: true}, ->
        repo.repoPromise

      runs ->
        expect(repo.repo).toBe null

  describe ".getPath()", ->
    # XXX HEAD isn't a git directory.. what's this spec supposed to be about?
    xit "returns the repository path for a .git directory path", ->
      # Rejects as malformed
      repo = GitRepositoryAsync.open(path.join(__dirname, 'fixtures', 'git', 'master.git', 'HEAD'))

      onSuccess = jasmine.createSpy('onSuccess')

      waitsForPromise ->
        repo.getPath().then(onSuccess)

      runs ->
        expectedPath = path.join(__dirname, 'fixtures', 'git', 'master.git')
        expect(onSuccess.mostRecentCall.args[0]).toBe(expectedPath)

    it "returns the repository path for a repository path", ->
      repo = openFixture('master.git')

      onSuccess = jasmine.createSpy('onSuccess')

      waitsForPromise ->
        repo.getPath().then(onSuccess)

      runs ->
        expectedPath = path.join(__dirname, 'fixtures', 'git', 'master.git')
        expect(onSuccess.mostRecentCall.args[0]).toBe(expectedPath)

  describe ".isPathIgnored(path)", ->
    it "resolves true for an ignored path", ->
      repo = openFixture('ignore.git')
      onSuccess = jasmine.createSpy('onSuccess')
      waitsForPromise ->
        repo.isPathIgnored('a.txt').then(onSuccess).catch (e) -> console.log e

      runs ->
        expect(onSuccess.mostRecentCall.args[0]).toBeTruthy()

    it "resolves false for a non-ignored path", ->
      repo = openFixture('ignore.git')
      onSuccess = jasmine.createSpy('onSuccess')
      waitsForPromise ->
        repo.isPathIgnored('b.txt').then(onSuccess)
      runs ->
        expect(onSuccess.mostRecentCall.args[0]).toBeFalsy()


  describe ".isPathModified(path)", ->
    [repo, filePath, newPath, emptyPath] = []

    beforeEach ->
      workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
      newPath = path.join(workingDirPath, 'new-path.txt')
      fs.writeFileSync(newPath, "i'm new here")
      emptyPath = path.join(workingDirPath, 'empty-path.txt')

    describe "when the path is unstaged", ->
      it "resolves false if the path has not been modified", ->
        onSuccess = jasmine.createSpy('onSuccess')
        waitsForPromise ->
          repo.isPathModified(filePath).then(onSuccess)
        runs ->
          expect(onSuccess.mostRecentCall.args[0]).toBeFalsy()

      it "resolves true if the path is modified", ->
        fs.writeFileSync(filePath, "change")
        onSuccess = jasmine.createSpy('onSuccess')
        waitsForPromise ->
          repo.isPathModified(filePath).then(onSuccess)
        runs ->
          expect(onSuccess.mostRecentCall.args[0]).toBeTruthy()

      it "resolves false if the path is new", ->
        onSuccess = jasmine.createSpy('onSuccess')
        waitsForPromise ->
          repo.isPathModified(newPath).then(onSuccess)
        runs ->
          expect(onSuccess.mostRecentCall.args[0]).toBeFalsy()

      it "resolves false if the path is invalid", ->
        onSuccess = jasmine.createSpy('onSuccess')
        waitsForPromise ->
          repo.isPathModified(emptyPath).then(onSuccess)
        runs ->
          expect(onSuccess.mostRecentCall.args[0]).toBeFalsy()

  describe ".isPathNew(path)", ->
    [filePath, newPath] = []

    beforeEach ->
      workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
      newPath = path.join(workingDirPath, 'new-path.txt')
      fs.writeFileSync(newPath, "i'm new here")

    describe "when the path is unstaged", ->
      it "returns true if the path is new", ->
        onSuccess = jasmine.createSpy('onSuccess')
        waitsForPromise ->
          repo.isPathNew(newPath).then(onSuccess)
        runs ->
          expect(onSuccess.mostRecentCall.args[0]).toBeTruthy()

      it "returns false if the path isn't new", ->
        onSuccess = jasmine.createSpy('onSuccess')
        waitsForPromise ->
          repo.isPathModified(newPath).then(onSuccess)
        runs ->
          expect(onSuccess.mostRecentCall.args[0]).toBeFalsy()


  describe ".checkoutHead(path)", ->
    # XXX this is failing sporadically with various errors around not finding the
    # repo / files in the repo
    [filePath] = []

    beforeEach ->
      workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')

    it "no longer reports a path as modified after checkout", ->
      onSuccess = jasmine.createSpy('onSuccess')
      waitsForPromise ->
        repo.isPathModified(filePath).then(onSuccess)
      runs ->
        expect(onSuccess.mostRecentCall.args[0]).toBeFalsy()
        fs.writeFileSync(filePath, 'ch ch changes')

      onSuccess = jasmine.createSpy('onSuccess')
      waitsForPromise ->
        repo.isPathModified(filePath).then(onSuccess)
      runs ->
        expect(onSuccess.mostRecentCall.args[0]).toBeTruthy()

      # Don't need to assert that this succeded because waitsForPromise should
      # fail if it was rejected..
      waitsForPromise ->
        repo.checkoutHead(filePath)

      runs ->
        onSuccess = jasmine.createSpy('onSuccess')
        waitsForPromise ->
          repo.isPathModified(filePath).then(onSuccess)
        runs ->
          expect(onSuccess.mostRecentCall.args[0]).toBeFalsy()

    it "restores the contents of the path to the original text", ->
      fs.writeFileSync(filePath, 'ch ch changes')
      waitsForPromise ->
        repo.checkoutHead(filePath)
      runs ->
        expect(fs.readFileSync(filePath, 'utf8')).toBe ''

    xit "fires a status-changed event if the checkout completes successfully", ->
      fs.writeFileSync(filePath, 'ch ch changes')
      repo.getPathStatus(filePath)
      statusHandler = jasmine.createSpy('statusHandler')
      repo.onDidChangeStatus statusHandler
      repo.checkoutHead(filePath)
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler.argsForCall[0][0]).toEqual {path: filePath, pathStatus: 0}

      repo.checkoutHead(filePath)
      expect(statusHandler.callCount).toBe 1

  xdescribe ".checkoutHeadForEditor(editor)", ->
    [filePath, editor] = []

    beforeEach ->
      workingDirPath = copyRepository()
      repo = new GitRepository(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
      fs.writeFileSync(filePath, 'ch ch changes')

      waitsForPromise ->
        atom.workspace.open(filePath)

      runs ->
        editor = atom.workspace.getActiveTextEditor()

    it "displays a confirmation dialog by default", ->
      spyOn(atom, 'confirm').andCallFake ({buttons}) -> buttons.OK()
      atom.config.set('editor.confirmCheckoutHeadRevision', true)

      repo.checkoutHeadForEditor(editor)

      expect(fs.readFileSync(filePath, 'utf8')).toBe ''

    it "does not display a dialog when confirmation is disabled", ->
      spyOn(atom, 'confirm')
      atom.config.set('editor.confirmCheckoutHeadRevision', false)

      repo.checkoutHeadForEditor(editor)

      expect(fs.readFileSync(filePath, 'utf8')).toBe ''
      expect(atom.confirm).not.toHaveBeenCalled()

  xdescribe ".destroy()", ->
    it "throws an exception when any method is called after it is called", ->
      repo = new GitRepository(require.resolve('./fixtures/git/master.git/HEAD'))
      repo.destroy()
      expect(-> repo.getShortHead()).toThrow()

  describe ".getPathStatus(path)", ->
    [filePath] = []

    beforeEach ->
      workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
      filePath = path.join(workingDirectory, 'file.txt')

    it "trigger a status-changed event when the new status differs from the last cached one", ->
      statusHandler = jasmine.createSpy("statusHandler")
      repo.onDidChangeStatus statusHandler
      fs.writeFileSync(filePath, '')

      waitsForPromise ->
        repo.getPathStatus(filePath)

      runs ->
        expect(statusHandler.callCount).toBe 1
        status = Git.Status.STATUS.WT_MODIFIED
        expect(statusHandler.argsForCall[0][0]).toEqual {path: filePath, pathStatus: status}
        fs.writeFileSync(filePath, 'abc')

      waitsForPromise ->
        status = repo.getPathStatus(filePath)

      runs ->
        expect(statusHandler.callCount).toBe 1

  describe ".getDirectoryStatus(path)", ->
    [directoryPath, filePath] = []

    beforeEach ->
      workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
      directoryPath = path.join(workingDirectory, 'dir')
      filePath = path.join(directoryPath, 'b.txt')

    it "gets the status based on the files inside the directory", ->
      onSuccess = jasmine.createSpy('onSuccess')
      onSuccess2 = jasmine.createSpy('onSuccess2')

      waitsForPromise ->
        repo.getDirectoryStatus(directoryPath).then(onSuccess)

      runs ->
        expect(onSuccess.callCount).toBe 1
        console.log onSuccess.mostRecentCall.args
        expect(repo.isStatusModified(onSuccess.mostRecentCall)).toBe false
        fs.writeFileSync(filePath, 'abc')

      waitsForPromise ->
        repo.getDirectoryStatus(directoryPath).then(onSuccess2)
      runs ->
        expect(onSuccess2.callCount).toBe 1
        expect(repo.isStatusModified(onSuccess2.argsForCall[0][0])).toBe true


  xdescribe ".refreshStatus()", ->
    [newPath, modifiedPath, cleanPath, originalModifiedPathText] = []

    beforeEach ->
      workingDirectory = copyRepository()
      repo = new GitRepository(workingDirectory)
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

  xdescribe "buffer events", ->
    [editor] = []

    beforeEach ->
      atom.project.setPaths([copyRepository()])

      waitsForPromise ->
        atom.workspace.open('other.txt').then (o) -> editor = o

    it "emits a status-changed event when a buffer is saved", ->
      editor.insertNewline()

      statusHandler = jasmine.createSpy('statusHandler')
      atom.project.getRepositories()[0].onDidChangeStatus statusHandler
      editor.save()
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler).toHaveBeenCalledWith {path: editor.getPath(), pathStatus: 256}

    it "emits a status-changed event when a buffer is reloaded", ->
      fs.writeFileSync(editor.getPath(), 'changed')

      statusHandler = jasmine.createSpy('statusHandler')
      atom.project.getRepositories()[0].onDidChangeStatus statusHandler
      editor.getBuffer().reload()
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler).toHaveBeenCalledWith {path: editor.getPath(), pathStatus: 256}
      editor.getBuffer().reload()
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

  xdescribe "when a project is deserialized", ->
    [buffer, project2] = []

    afterEach ->
      project2?.destroy()

    it "subscribes to all the serialized buffers in the project", ->
      atom.project.setPaths([copyRepository()])

      waitsForPromise ->
        atom.workspace.open('file.txt')

      runs ->
        project2 = Project.deserialize(atom.project.serialize())
        buffer = project2.getBuffers()[0]

      waitsFor ->
        buffer.loaded

      runs ->
        originalContent = buffer.getText()
        buffer.append('changes')

        statusHandler = jasmine.createSpy('statusHandler')
        project2.getRepositories()[0].onDidChangeStatus statusHandler
        buffer.save()
        expect(statusHandler.callCount).toBe 1
        expect(statusHandler).toHaveBeenCalledWith {path: buffer.getPath(), pathStatus: 256}
