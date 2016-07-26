url = require 'url'

# Package helpers
module.exports =
  # Parse the repository in `name/owner` format from the package metadata.
  #
  # pack - The package metadata object.
  #
  # Returns a name/owner string or null if not parseable.
  getRepository: (pack={}) ->
    if repository = pack.repository?.url ? pack.repository
      repoPath = url.parse(repository.replace(/\.git$/, '')).pathname
      [name, owner] = repoPath.split('/')[-2..]
      return "#{name}/#{owner}" if name and owner
    null
