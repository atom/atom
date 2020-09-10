const path = require('path');
const fetchOutdatedDependencies = require('../fetch-outdated-dependencies');
const { nativeDependencies } = require('./helpers');
const repositoryRootPath = path.resolve('.', 'fixtures', 'dummy');
const packageJSON = require(path.join(repositoryRootPath, 'package.json'));

describe('Fetch outdated dependencies', function() {
  it('should fetch outdated native dependencies', async () => {
    spyOn(fetchOutdatedDependencies, 'npm').andReturn(
      Promise.resolve(nativeDependencies)
    );

    expect(await fetchOutdatedDependencies.npm(repositoryRootPath)).toEqual(
      nativeDependencies
    );
  });

  it('should fetch outdated core dependencies', async () => {
    spyOn(fetchOutdatedDependencies, 'apm').andReturn(
      Promise.resolve(nativeDependencies)
    );

    expect(await fetchOutdatedDependencies.apm(packageJSON)).toEqual(
      nativeDependencies
    );
  });
});
