var $git = {};
(function() {

  native function getRepository(path);
  native function getHead();

  function GitRepository(path) {
    var repo = getRepository(path);
    repo.constructor = GitRepository;
    repo.__proto__ = GitRepository.prototype;
    return repo;
  }

  GitRepository.prototype.getHead = getHead;
  this.GitRepository = GitRepository;
})();
