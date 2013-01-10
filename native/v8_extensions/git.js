var $git = {};
(function() {

  native function getRepository(pathInRepo);
  native function getHead();
  native function getPath();
  native function getStatus(path);
  native function isIgnored(path);
  native function checkoutHead(path);
  native function getDiffStats(path);
  native function isSubmodule(path);
  native function refreshIndex();
  native function destroy();

  function GitRepository(path) {
    var repo = getRepository(path);
    if (!repo)
      throw new Error("No Git repository found searching path: " + path);

    repo.constructor = GitRepository;
    repo.__proto__ = GitRepository.prototype;
    return repo;
  }

  GitRepository.prototype.getHead = getHead;
  GitRepository.prototype.getPath = getPath;
  GitRepository.prototype.getStatus = getStatus;
  GitRepository.prototype.isIgnored = isIgnored;
  GitRepository.prototype.checkoutHead = checkoutHead;
  GitRepository.prototype.getDiffStats = getDiffStats;
  GitRepository.prototype.isSubmodule = isSubmodule;
  GitRepository.prototype.refreshIndex = refreshIndex;
  GitRepository.prototype.destroy = destroy;
  this.GitRepository = GitRepository;
})();
