const fs = require('fs');
const path = require('path');
const request = require('request-promise-native');

module.exports = async function(packageRepoName, apiToken, version, artifacts) {
  for (let artifact of artifacts) {
    let fileExt = path.extname(artifact);
    switch (fileExt) {
      case '.deb':
        await uploadDebPackage(version, artifact);
        break;
      case '.rpm':
        await uploadRpmPackage(version, artifact);
        break;
      default:
        continue;
    }
  }

  async function uploadDebPackage(version, filePath) {
    // NOTE: Not sure if distro IDs update over time, might need
    // to query the following endpoint dynamically to find the right IDs:
    //
    // https://{apiToken}:@packagecloud.io/api/v1/distributions.json
    await uploadPackage({
      version,
      filePath,
      type: 'deb',
      arch: 'amd64',
      fileName: 'atom-amd64.deb',
      distroId: 35 /* Any .deb distribution */,
      distroName: 'any',
      distroVersion: 'any'
    });
  }

  async function uploadRpmPackage(version, filePath) {
    await uploadPackage({
      version,
      filePath,
      type: 'rpm',
      arch: 'x86_64',
      fileName: 'atom.x86_64.rpm',
      distroId: 140 /* Enterprise Linux 7 */,
      distroName: 'el',
      distroVersion: '7'
    });
  }

  async function uploadPackage(packageDetails) {
    // Infer the package suffix from the version
    if (/-beta\d+/.test(packageDetails.version)) {
      packageDetails.releaseSuffix = '-beta';
    } else if (/-nightly\d+/.test(packageDetails.version)) {
      packageDetails.releaseSuffix = '-nightly';
    }

    await removePackageIfExists(packageDetails);
    await uploadToPackageCloud(packageDetails);
  }

  function uploadToPackageCloud(packageDetails) {
    return new Promise(async (resolve, reject) => {
      console.log(
        `Uploading ${
          packageDetails.fileName
        } to https://packagecloud.io/AtomEditor/${packageRepoName}`
      );
      var uploadOptions = {
        url: `https://${apiToken}:@packagecloud.io/api/v1/repos/AtomEditor/${packageRepoName}/packages.json`,
        formData: {
          'package[distro_version_id]': packageDetails.distroId,
          'package[package_file]': fs.createReadStream(packageDetails.filePath)
        }
      };

      request.post(uploadOptions, (error, uploadResponse, body) => {
        if (error || uploadResponse.statusCode !== 201) {
          console.log(
            `Error while uploading '${packageDetails.fileName}' v${
              packageDetails.version
            }: ${uploadResponse}`
          );
          reject(uploadResponse);
        } else {
          console.log(`Successfully uploaded ${packageDetails.fileName}!`);
          resolve(uploadResponse);
        }
      });
    });
  }

  async function removePackageIfExists({
    version,
    type,
    arch,
    fileName,
    distroName,
    distroVersion,
    releaseSuffix
  }) {
    // RPM URI paths have an extra '/0.1' thrown in
    let versionJsonPath =
      type === 'rpm' ? `${version.replace('-', '.')}/0.1` : version;

    try {
      const existingPackageDetails = await request({
        uri: `https://${apiToken}:@packagecloud.io/api/v1/repos/AtomEditor/${packageRepoName}/package/${type}/${distroName}/${distroVersion}/atom${releaseSuffix ||
          ''}/${arch}/${versionJsonPath}.json`,
        method: 'get',
        json: true
      });

      if (existingPackageDetails && existingPackageDetails.destroy_url) {
        console.log(
          `Deleting pre-existing package ${fileName} in ${packageRepoName}`
        );
        await request({
          uri: `https://${apiToken}:@packagecloud.io/${
            existingPackageDetails.destroy_url
          }`,
          method: 'delete'
        });
      }
    } catch (err) {
      if (err.statusCode !== 404) {
        console.log(
          `Error while checking for existing '${fileName}' v${version}:\n\n`,
          err
        );
      }
    }
  }
};
