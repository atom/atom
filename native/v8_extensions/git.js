var $git = {};
(function() {

  native function isRepository(path);
  $git.isRepository = isRepository;

  native function getRepository(path);
  $git.getRepository = getRepository;

  native function getCurrentBranch(repository);
  $git.getCurrentBranch = getCurrentBranch;

})();
