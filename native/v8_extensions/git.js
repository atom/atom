var $git = {};
(function() {

  native function getRepository(pathInRepo);
  native function getHead();
  native function getPath();
  native function getStatus(path);
  native function isIgnored(path);
  native function checkoutHead(path);
  native function getDiffStats(path);

  function GitRepository(path) {
    var repo = getRepository(path);
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
  this.GitRepository = GitRepository;
})();
