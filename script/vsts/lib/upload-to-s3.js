'use strict';

const fs = require('fs');
const path = require('path');
const aws = require('aws-sdk');

module.exports = function(
  s3Key,
  s3Secret,
  s3Bucket,
  directory,
  assets,
  acl = 'public-read'
) {
  const s3 = new aws.S3({
    accessKeyId: s3Key,
    secretAccessKey: s3Secret,
    params: { Bucket: s3Bucket }
  });

  function listExistingAssetsForDirectory(directory) {
    return s3
      .listObjectsV2({ Prefix: directory })
      .promise()
      .then(res => {
        return res.Contents.map(obj => {
          return { Key: obj.Key };
        });
      });
  }

  function deleteExistingAssets(existingAssets) {
    if (existingAssets.length > 0) {
      return s3
        .deleteObjects({ Delete: { Objects: existingAssets } })
        .promise();
    } else {
      return Promise.resolve(true);
    }
  }

  function uploadAssets(assets, directory) {
    return assets.reduce(function(promise, asset) {
      return promise.then(() => uploadAsset(directory, asset));
    }, Promise.resolve());
  }

  function uploadAsset(directory, assetPath) {
    return new Promise((resolve, reject) => {
      console.info(`Uploading ${assetPath}`);
      const params = {
        Key: `${directory}${path.basename(assetPath)}`,
        ACL: acl,
        Body: fs.createReadStream(assetPath)
      };

      s3.upload(params, error => {
        if (error) {
          reject(error);
        } else {
          resolve();
        }
      });
    });
  }

  return listExistingAssetsForDirectory(directory)
    .then(deleteExistingAssets)
    .then(() => uploadAssets(assets, directory));
};
