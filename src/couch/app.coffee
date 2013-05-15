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

        latestVersion = doc['dist-tags']?.latest
        return unless latestVersion?
        latestRelease = doc.versions[latestVersion]
        atomVersion = latestRelease?.engines?.atom
        emit(doc._id, atomVersion) if atomVersion?
