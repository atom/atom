'use strict';

const path = require('path');
const { BlobServiceClient } = require('@azure/storage-blob');

module.exports = function upload(connStr, directory, assets) {
  const blobServiceClient = BlobServiceClient.fromConnectionString(connStr);
  const containerName = 'atom-build';
  const containerClient = blobServiceClient.getContainerClient(containerName);

  async function listExistingAssetsForDirectory() {
    return containerClient.listBlobsFlat({ prefix: directory });
  }

  async function deleteExistingAssets(existingAssets = []) {
    try {
      for await (const asset of existingAssets) {
        console.log(`Deleting blob ${asset.name}`);
        containerClient.deleteBlob(asset.name);
      }
      return Promise.resolve(true);
    } catch (ex) {
      return Promise.reject(ex.message);
    }
  }

  function uploadAssets(assets) {
    return assets.reduce(function(promise, asset) {
      return promise.then(() => uploadAsset(asset));
    }, Promise.resolve());
  }

  function uploadAsset(assetPath) {
    return new Promise(async (resolve, reject) => {
      try {
        console.info(`Uploading ${assetPath}`);
        const blockBlobClient = containerClient.getBlockBlobClient(
          path.join(directory, path.basename(assetPath))
        );
        const result = await blockBlobClient.uploadFile(assetPath);
        resolve(result);
      } catch (ex) {
        reject(ex.message);
      }
    });
  }

  return listExistingAssetsForDirectory()
    .then(deleteExistingAssets)
    .then(() => uploadAssets(assets));
};
