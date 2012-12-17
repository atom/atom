var $tags = {};
(function() {

  native function find(path, tag);
  $tags.find = find;

  native function getAllTagsAsync(path, callback);
  $tags.getAllTagsAsync = getAllTagsAsync;

})();
