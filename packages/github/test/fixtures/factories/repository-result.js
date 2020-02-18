import IDGenerator from './id-generator';

export function createRepositoryResult(attrs = {}) {
  const idGen = IDGenerator.fromOpts(attrs);

  const o = {
    id: idGen.generate('repository'),
    defaultRefPrefix: 'refs/heads/',
    defaultRefName: 'master',
    defaultRefID: 'ref0',
    ...attrs,
  }

  return {
    defaultBranchRef: {
      prefix: o.defaultRefPrefix,
      name: o.defaultRefName,
      id: o.defaultRefID,
    },
    id: o.id,
  }
}
