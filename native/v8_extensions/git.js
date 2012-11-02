var $git = {};
(function() {

  native function getRepository(pathInRepo);
  native function getHead();
  native function getPath();
  native function isIgnored(path);

  function GitRepository(path) {
    var repo = getRepository(path);
    repo.constructor = GitRepository;
    repo.__proto__ = GitRepository.prototype;
    return repo;
  }

  GitRepository.prototype.getHead = getHead;
  GitRepository.prototype.getPath = getPath;
  GitRepository.prototype.isIgnored = isIgnored;
  this.GitRepository = GitRepository;
})();
