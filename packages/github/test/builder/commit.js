import moment from 'moment';

import Commit from '../../lib/models/commit';
import Author from '../../lib/models/author';
import {multiFilePatchBuilder} from './patch';

class CommitBuilder {
  constructor() {
    this._sha = '0123456789abcdefghij0123456789abcdefghij';
    this._author = new Author('default@email.com', 'Tilde Ann Thurium');
    this._authorDate = moment('2018-11-28T12:00:00', moment.ISO_8601).unix();
    this._coAuthors = [];
    this._messageSubject = 'subject';
    this._messageBody = 'body';

    this._multiFileDiff = null;
  }

  sha(newSha) {
    this._sha = newSha;
    return this;
  }

  addAuthor(newEmail, newName) {
    this._author = new Author(newEmail, newName);
    return this;
  }

  authorDate(timestamp) {
    this._authorDate = timestamp;
    return this;
  }

  messageSubject(subject) {
    this._messageSubject = subject;
    return this;
  }

  messageBody(body) {
    this._messageBody = body;
    return this;
  }

  setMultiFileDiff(block = () => {}) {
    const builder = multiFilePatchBuilder();
    block(builder);
    this._multiFileDiff = builder.build().multiFilePatch;
    return this;
  }

  addCoAuthor(email, name) {
    this._coAuthors.push(new Author(email, name));
    return this;
  }

  build() {
    const commit = new Commit({
      sha: this._sha,
      author: this._author,
      authorDate: this._authorDate,
      coAuthors: this._coAuthors,
      messageSubject: this._messageSubject,
      messageBody: this._messageBody,
    });

    if (this._multiFileDiff !== null) {
      commit.setMultiFileDiff(this._multiFileDiff);
    }

    return commit;
  }
}

export function commitBuilder() {
  return new CommitBuilder();
}
