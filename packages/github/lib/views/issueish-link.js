import url from 'url';
import {shell} from 'electron';

import React from 'react';
import PropTypes from 'prop-types';

import IssueishDetailItem from '../items/issueish-detail-item';
import {addEvent} from '../reporter-proxy';

// eslint-disable-next-line no-shadow
export default function IssueishLink({url, children, ...others}) {
  function clickHandler(event) {
    handleClickEvent(event, url);
  }

  return <a {...others} onClick={clickHandler}>{children}</a>;
}

IssueishLink.propTypes = {
  url: PropTypes.string.isRequired,
  children: PropTypes.node,
};


// eslint-disable-next-line no-shadow
export function handleClickEvent(event, url) {
  event.preventDefault();
  event.stopPropagation();
  if (!event.shiftKey) {
    return openIssueishLinkInNewTab(url, {activate: !(event.metaKey || event.ctrlKey)});
  } else {
    // Open in browser if shift key held
    return openLinkInBrowser(url);
  }
}

// eslint-disable-next-line no-shadow
export function openIssueishLinkInNewTab(url, options = {}) {
  const uri = getAtomUriForGithubUrl(url);
  if (uri) {
    return openInNewTab(uri, options);
  } else {
    return null;
  }
}

export function openLinkInBrowser(uri) {
  return new Promise((resolve, reject) => {
    shell.openExternal(uri, {}, err => {
      if (err) {
        reject(err);
      } else {
        addEvent('open-issueish-in-browser', {package: 'github', from: 'issueish-link'});
        resolve();
      }
    });
  });
}

function getAtomUriForGithubUrl(githubUrl) {
  return getUriForData(getDataFromGithubUrl(githubUrl));
}

export function getDataFromGithubUrl(githubUrl) {
  const {hostname, pathname} = url.parse(githubUrl);
  const [repoOwner, repoName, type, issueishNumber] = pathname.split('/').filter(s => s);
  return {hostname, repoOwner, repoName, type, issueishNumber: parseInt(issueishNumber, 10)};
}

function getUriForData({hostname, repoOwner, repoName, type, issueishNumber}) {
  if (hostname !== 'github.com' || !['pull', 'issues'].includes(type) || !issueishNumber || isNaN(issueishNumber)) {
    return null;
  } else {
    return IssueishDetailItem.buildURI({
      host: 'github.com',
      owner: repoOwner,
      repo: repoName,
      number: issueishNumber,
    });
  }
}

function openInNewTab(uri, {activate} = {activate: true}) {
  return atom.workspace.open(uri, {activateItem: activate}).then(() => {
    addEvent('open-issueish-in-pane', {package: 'github', from: 'issueish-link', target: 'new-tab'});
  });
}
