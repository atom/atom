module.exports =
  _id: '_design/apm'
  views:
    atom_packages:
      map: (doc) ->
        return unless doc?
        return unless doc.versions?
        return if doc.deprecated
        return if doc._id.match(/^npm-test-.+$/) and
                  doc.maintainers?[0]?.name is 'isaacs'
        return unless doc['releases']?.latest?

        releases = {}
        hasAtomRelease = false
        for version, metadata of doc.versions
          if metadata?.engines?.atom
            releases[version] = metadata
            hasAtomRelease = true
        emit(doc._id, {releases}) if hasAtomRelease
