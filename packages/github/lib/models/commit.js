import {buildMultiFilePatch} from './patch';

const UNBORN = Symbol('unborn');

// Truncation elipsis styles
const WORD_ELIPSES = '...';
const NEWLINE_ELIPSES = '\n...';
const PARAGRAPH_ELIPSES = '\n\n...';

export default class Commit {
  static LONG_MESSAGE_THRESHOLD = 400;

  static NEWLINE_THRESHOLD = 5;

  static createUnborn() {
    return new Commit({unbornRef: UNBORN});
  }

  constructor({sha, author, coAuthors, authorDate, messageSubject, messageBody, unbornRef, patch}) {
    this.sha = sha;
    this.author = author;
    this.coAuthors = coAuthors || [];
    this.authorDate = authorDate;
    this.messageSubject = messageSubject;
    this.messageBody = messageBody;
    this.unbornRef = unbornRef === UNBORN;

    this.multiFileDiff = patch ? buildMultiFilePatch(patch) : buildMultiFilePatch([]);
  }

  getSha() {
    return this.sha;
  }

  getAuthor() {
    return this.author;
  }

  getAuthorEmail() {
    return this.author.getEmail();
  }

  getAuthorAvatarUrl() {
    return this.author.getAvatarUrl();
  }

  getAuthorName() {
    return this.author.getFullName();
  }

  getAuthorDate() {
    return this.authorDate;
  }

  getCoAuthors() {
    return this.coAuthors;
  }

  getMessageSubject() {
    return this.messageSubject;
  }

  getMessageBody() {
    return this.messageBody;
  }

  isBodyLong() {
    if (this.getMessageBody().length > this.constructor.LONG_MESSAGE_THRESHOLD) {
      return true;
    }

    if ((this.getMessageBody().match(/\r?\n/g) || []).length > this.constructor.NEWLINE_THRESHOLD) {
      return true;
    }

    return false;
  }

  getFullMessage() {
    return `${this.getMessageSubject()}\n\n${this.getMessageBody()}`.trim();
  }

  /*
   * Return the messageBody truncated to at most LONG_MESSAGE_THRESHOLD characters or NEWLINE_THRESHOLD newlines,
   * whichever comes first.
   *
   * If NEWLINE_THRESHOLD newlines are encountered before LONG_MESSAGE_THRESHOLD characters, the body will be truncated
   * at the last counted newline and elipses added.
   *
   * If a paragraph boundary is found before LONG_MESSAGE_THRESHOLD characters, the message will be truncated at the end
   * of the previous paragraph and an elipses added. If no paragraph boundary is found, but a word boundary is, the text
   * is truncated at the last word boundary and an elipsis added. If neither are found, the text is truncated hard at
   * LONG_MESSAGE_THRESHOLD - 3 characters and an elipsis is added.
   */
  abbreviatedBody() {
    if (!this.isBodyLong()) {
      return this.getMessageBody();
    }

    const {LONG_MESSAGE_THRESHOLD, NEWLINE_THRESHOLD} = this.constructor;

    let lastNewlineCutoff = null;
    let lastParagraphCutoff = null;
    let lastWordCutoff = null;

    const searchText = this.getMessageBody().substring(0, LONG_MESSAGE_THRESHOLD);
    const boundaryRx = /\s+/g;
    let result;
    let lineCount = 0;
    while ((result = boundaryRx.exec(searchText)) !== null) {
      const newlineCount = (result[0].match(/\r?\n/g) || []).length;

      lineCount += newlineCount;
      if (lineCount > NEWLINE_THRESHOLD) {
        lastNewlineCutoff = result.index;
        break;
      }

      if (newlineCount < 2 && result.index <= LONG_MESSAGE_THRESHOLD - WORD_ELIPSES.length) {
        lastWordCutoff = result.index;
      } else if (result.index < LONG_MESSAGE_THRESHOLD - PARAGRAPH_ELIPSES.length) {
        lastParagraphCutoff = result.index;
      }
    }

    let elipses = WORD_ELIPSES;
    let cutoffIndex = LONG_MESSAGE_THRESHOLD - WORD_ELIPSES.length;
    if (lastNewlineCutoff !== null) {
      elipses = NEWLINE_ELIPSES;
      cutoffIndex = lastNewlineCutoff;
    } else if (lastParagraphCutoff !== null) {
      elipses = PARAGRAPH_ELIPSES;
      cutoffIndex = lastParagraphCutoff;
    } else if (lastWordCutoff !== null) {
      cutoffIndex = lastWordCutoff;
    }

    return this.getMessageBody().substring(0, cutoffIndex) + elipses;
  }

  setMultiFileDiff(multiFileDiff) {
    this.multiFileDiff = multiFileDiff;
  }

  getMultiFileDiff() {
    return this.multiFileDiff;
  }

  isUnbornRef() {
    return this.unbornRef;
  }

  isPresent() {
    return true;
  }

  isEqual(other) {
    // Directly comparable properties
    const properties = ['sha', 'authorDate', 'messageSubject', 'messageBody', 'unbornRef'];
    for (const property of properties) {
      if (this[property] !== other[property]) {
        return false;
      }
    }

    // Author
    if (this.author.getEmail() !== other.getAuthorEmail() || this.author.getFullName() !== other.getAuthorName()) {
      return false;
    }

    // Co-author array
    if (this.coAuthors.length !== other.coAuthors.length) {
      return false;
    }
    for (let i = 0; i < this.coAuthors.length; i++) {
      const thisCoAuthor = this.coAuthors[i];
      const otherCoAuthor = other.coAuthors[i];

      if (
        thisCoAuthor.getFullName() !== otherCoAuthor.getFullName()
        || thisCoAuthor.getEmail() !== otherCoAuthor.getEmail()
      ) {
        return false;
      }
    }

    // Multi-file patch
    if (!this.multiFileDiff.isEqual(other.multiFileDiff)) {
      return false;
    }

    return true;
  }
}

export const nullCommit = {
  getSha() {
    return '';
  },

  getMessageSubject() {
    return '';
  },

  isUnbornRef() {
    return false;
  },

  isPresent() {
    return false;
  },

  isBodyLong() {
    return false;
  },
};
