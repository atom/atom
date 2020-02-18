import React from 'react';
import PropTypes from 'prop-types';
import fs from 'fs-extra';

import CreateDialogContainer from '../containers/create-dialog-container';
import createRepositoryMutation from '../mutations/create-repository';
import {GithubLoginModelPropType} from '../prop-types';
import {addEvent} from '../reporter-proxy';

export default class CreateDialog extends React.Component {
  static propTypes = {
    // Model
    loginModel: GithubLoginModelPropType.isRequired,
    request: PropTypes.object.isRequired,
    error: PropTypes.instanceOf(Error),
    inProgress: PropTypes.bool.isRequired,

    // Atom environment
    currentWindow: PropTypes.object.isRequired,
    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,
  }

  render() {
    return <CreateDialogContainer {...this.props} />;
  }
}

export async function createRepository(
  {ownerID, name, visibility, localPath, protocol, sourceRemoteName},
  {clone, relayEnvironment},
) {
  await fs.ensureDir(localPath, 0o755);
  const result = await createRepositoryMutation(relayEnvironment, {name, ownerID, visibility});
  const sourceURL = result.createRepository.repository[protocol === 'ssh' ? 'sshUrl' : 'url'];
  await clone(sourceURL, localPath, sourceRemoteName);
  addEvent('create-github-repository', {package: 'github'});
}

export async function publishRepository(
  {ownerID, name, visibility, protocol, sourceRemoteName},
  {repository, relayEnvironment},
) {
  let defaultBranchName, wasEmpty;
  if (repository.isEmpty()) {
    wasEmpty = true;
    await repository.init();
    defaultBranchName = 'master';
  } else {
    wasEmpty = false;
    const branchSet = await repository.getBranches();
    const branchNames = new Set(branchSet.getNames());
    if (branchNames.has('master')) {
      defaultBranchName = 'master';
    } else {
      const head = branchSet.getHeadBranch();
      if (head.isPresent()) {
        defaultBranchName = head.getName();
      }
    }
  }
  if (!defaultBranchName) {
    throw new Error('Unable to determine the desired default branch from the repository');
  }

  const result = await createRepositoryMutation(relayEnvironment, {name, ownerID, visibility});
  const sourceURL = result.createRepository.repository[protocol === 'ssh' ? 'sshUrl' : 'url'];
  const remote = await repository.addRemote(sourceRemoteName, sourceURL);
  if (wasEmpty) {
    addEvent('publish-github-repository', {package: 'github'});
  } else {
    await repository.push(defaultBranchName, {remote, setUpstream: true});
    addEvent('init-publish-github-repository', {package: 'github'});
  }
}
