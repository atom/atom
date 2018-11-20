/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as stream from 'vs/base/node/stream';
import * as iconv from 'iconv-lite';
import { isLinux, isMacintosh } from 'vs/base/common/platform';
import { exec } from 'child_process';
import { Readable, Writable, WritableOptions } from 'stream';

export const UTF8 = 'utf8';
export const UTF8_with_bom = 'utf8bom';
export const UTF16be = 'utf16be';
export const UTF16le = 'utf16le';

export interface IDecodeStreamOptions {
	guessEncoding?: boolean;
	minBytesRequiredForDetection?: number;
	overwriteEncoding?(detectedEncoding: string | null): string;
}

export function toDecodeStream(readable: Readable, options: IDecodeStreamOptions): Promise<{ detected: IDetectedEncodingResult, stream: NodeJS.ReadableStream }> {
	if (!options.minBytesRequiredForDetection) {
		options.minBytesRequiredForDetection = options.guessEncoding ? AUTO_GUESS_BUFFER_MAX_LEN : NO_GUESS_BUFFER_MAX_LEN;
	}

	if (!options.overwriteEncoding) {
		options.overwriteEncoding = detected => detected || UTF8;
	}

	return new Promise<{ detected: IDetectedEncodingResult, stream: NodeJS.ReadableStream }>((resolve, reject) => {

		readable.on('error', reject);

		readable.pipe(new class extends Writable {

			private _decodeStream: NodeJS.ReadWriteStream;
			private _decodeStreamConstruction: Thenable<any>;
			private _buffer: Buffer[] = [];
			private _bytesBuffered = 0;

			constructor(opts?: WritableOptions) {
				super(opts);
				this.once('finish', () => this._finish());
			}

			_write(chunk: any, encoding: string, callback: Function): void {
				if (!Buffer.isBuffer(chunk)) {
					callback(new Error('data must be a buffer'));
				}

				if (this._decodeStream) {
					// just a forwarder now
					this._decodeStream.write(chunk, callback);
					return;
				}

				this._buffer.push(chunk);
				this._bytesBuffered += chunk.length;

				if (this._decodeStreamConstruction) {
					// waiting for the decoder to be ready
					this._decodeStreamConstruction.then(_ => callback(), err => callback(err));

				} else if (typeof options.minBytesRequiredForDetection === 'number' && this._bytesBuffered >= options.minBytesRequiredForDetection) {
					// buffered enough data, create stream and forward data
					this._startDecodeStream(callback);

				} else {
					// only buffering
					callback();
				}
			}

			_startDecodeStream(callback: Function): void {

				this._decodeStreamConstruction = Promise.resolve(detectEncodingFromBuffer({
					buffer: Buffer.concat(this._buffer), bytesRead: this._bytesBuffered
				}, options.guessEncoding)).then(detected => {
					if (options.overwriteEncoding) {
						detected.encoding = options.overwriteEncoding(detected.encoding);
					}
					this._decodeStream = decodeStream(detected.encoding);
					for (const buffer of this._buffer) {
						this._decodeStream.write(buffer);
					}
					callback();
					resolve({ detected, stream: this._decodeStream });

				}, err => {
					this.emit('error', err);
					callback(err);
				});
			}

			_finish(): void {
				if (this._decodeStream) {
					// normal finish
					this._decodeStream.end();
				} else {
					// we were still waiting for data...
					this._startDecodeStream(() => this._decodeStream.end());
				}
			}
		});
	});
}

export function bomLength(encoding: string): number {
	switch (encoding) {
		case UTF8:
			return 3;
		case UTF16be:
		case UTF16le:
			return 2;
	}

	return 0;
}

export function decode(buffer: Buffer, encoding: string): string {
	return iconv.decode(buffer, toNodeEncoding(encoding));
}

export function encode(content: string | Buffer, encoding: string, options?: { addBOM?: boolean }): Buffer {
	return iconv.encode(content, toNodeEncoding(encoding), options);
}

export function encodingExists(encoding: string): boolean {
	return iconv.encodingExists(toNodeEncoding(encoding));
}

export function decodeStream(encoding: string | null): NodeJS.ReadWriteStream {
	return iconv.decodeStream(toNodeEncoding(encoding));
}

export function encodeStream(encoding: string, options?: { addBOM?: boolean }): NodeJS.ReadWriteStream {
	return iconv.encodeStream(toNodeEncoding(encoding), options);
}

function toNodeEncoding(enc: string | null): string {
	if (enc === UTF8_with_bom || enc === null) {
		return UTF8; // iconv does not distinguish UTF 8 with or without BOM, so we need to help it
	}

	return enc;
}

export function detectEncodingByBOMFromBuffer(buffer: Buffer | null, bytesRead: number): string | null {
	if (!buffer || bytesRead < 2) {
		return null;
	}

	const b0 = buffer.readUInt8(0);
	const b1 = buffer.readUInt8(1);

	// UTF-16 BE
	if (b0 === 0xFE && b1 === 0xFF) {
		return UTF16be;
	}

	// UTF-16 LE
	if (b0 === 0xFF && b1 === 0xFE) {
		return UTF16le;
	}

	if (bytesRead < 3) {
		return null;
	}

	const b2 = buffer.readUInt8(2);

	// UTF-8
	if (b0 === 0xEF && b1 === 0xBB && b2 === 0xBF) {
		return UTF8;
	}

	return null;
}

/**
 * Detects the Byte Order Mark in a given file.
 * If no BOM is detected, null will be passed to callback.
 */
export function detectEncodingByBOM(file: string): Promise<string | null> {
	return stream.readExactlyByFile(file, 3).then(({ buffer, bytesRead }) => detectEncodingByBOMFromBuffer(buffer, bytesRead));
}

const MINIMUM_THRESHOLD = 0.2;
const IGNORE_ENCODINGS = ['ascii', 'utf-8', 'utf-16', 'utf-32'];

/**
 * Guesses the encoding from buffer.
 */
export function guessEncodingByBuffer(buffer: Buffer): Promise<string | null> {
	return import('jschardet').then(jschardet => {
		jschardet.Constants.MINIMUM_THRESHOLD = MINIMUM_THRESHOLD;

		const guessed = jschardet.detect(buffer);
		if (!guessed || !guessed.encoding) {
			return null;
		}

		const enc = guessed.encoding.toLowerCase();

		// Ignore encodings that cannot guess correctly
		// (http://chardet.readthedocs.io/en/latest/supported-encodings.html)
		if (0 <= IGNORE_ENCODINGS.indexOf(enc)) {
			return null;
		}

		return toIconvLiteEncoding(guessed.encoding);
	});
}

const JSCHARDET_TO_ICONV_ENCODINGS: { [name: string]: string } = {
	'ibm866': 'cp866',
	'big5': 'cp950'
};

function toIconvLiteEncoding(encodingName: string): string {
	const normalizedEncodingName = encodingName.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
	const mapped = JSCHARDET_TO_ICONV_ENCODINGS[normalizedEncodingName];

	return mapped || normalizedEncodingName;
}

/**
 * The encodings that are allowed in a settings file don't match the canonical encoding labels specified by WHATWG.
 * See https://encoding.spec.whatwg.org/#names-and-labels
 * Iconv-lite strips all non-alphanumeric characters, but ripgrep doesn't. For backcompat, allow these labels.
 */
export function toCanonicalName(enc: string): string {
	switch (enc) {
		case 'shiftjis':
			return 'shift-jis';
		case 'utf16le':
			return 'utf-16le';
		case 'utf16be':
			return 'utf-16be';
		case 'big5hkscs':
			return 'big5-hkscs';
		case 'eucjp':
			return 'euc-jp';
		case 'euckr':
			return 'euc-kr';
		case 'koi8r':
			return 'koi8-r';
		case 'koi8u':
			return 'koi8-u';
		case 'macroman':
			return 'x-mac-roman';
		case 'utf8bom':
			return 'utf8';
		default:
			const m = enc.match(/windows(\d+)/);
			if (m) {
				return 'windows-' + m[1];
			}

			return enc;
	}
}

const ZERO_BYTE_DETECTION_BUFFER_MAX_LEN = 512; // number of bytes to look at to decide about a file being binary or not
const NO_GUESS_BUFFER_MAX_LEN = 512; 			// when not auto guessing the encoding, small number of bytes are enough
const AUTO_GUESS_BUFFER_MAX_LEN = 512 * 8; 		// with auto guessing we want a lot more content to be read for guessing

export interface IDetectedEncodingResult {
	encoding: string | null;
	seemsBinary: boolean;
}

export function detectEncodingFromBuffer(readResult: stream.ReadResult, autoGuessEncoding?: false): IDetectedEncodingResult;
export function detectEncodingFromBuffer(readResult: stream.ReadResult, autoGuessEncoding?: boolean): Promise<IDetectedEncodingResult>;
export function detectEncodingFromBuffer({ buffer, bytesRead }: stream.ReadResult, autoGuessEncoding?: boolean): Promise<IDetectedEncodingResult> | IDetectedEncodingResult {

	// Always first check for BOM to find out about encoding
	let encoding = detectEncodingByBOMFromBuffer(buffer, bytesRead);

	// Detect 0 bytes to see if file is binary or UTF-16 LE/BE
	// unless we already know that this file has a UTF-16 encoding
	let seemsBinary = false;
	if (encoding !== UTF16be && encoding !== UTF16le && buffer) {
		let couldBeUTF16LE = true; // e.g. 0xAA 0x00
		let couldBeUTF16BE = true; // e.g. 0x00 0xAA
		let containsZeroByte = false;

		// This is a simplified guess to detect UTF-16 BE or LE by just checking if
		// the first 512 bytes have the 0-byte at a specific location. For UTF-16 LE
		// this would be the odd byte index and for UTF-16 BE the even one.
		// Note: this can produce false positives (a binary file that uses a 2-byte
		// encoding of the same format as UTF-16) and false negatives (a UTF-16 file
		// that is using 4 bytes to encode a character).
		for (let i = 0; i < bytesRead && i < ZERO_BYTE_DETECTION_BUFFER_MAX_LEN; i++) {
			const isEndian = (i % 2 === 1); // assume 2-byte sequences typical for UTF-16
			const isZeroByte = (buffer.readInt8(i) === 0);

			if (isZeroByte) {
				containsZeroByte = true;
			}

			// UTF-16 LE: expect e.g. 0xAA 0x00
			if (couldBeUTF16LE && (isEndian && !isZeroByte || !isEndian && isZeroByte)) {
				couldBeUTF16LE = false;
			}

			// UTF-16 BE: expect e.g. 0x00 0xAA
			if (couldBeUTF16BE && (isEndian && isZeroByte || !isEndian && !isZeroByte)) {
				couldBeUTF16BE = false;
			}

			// Return if this is neither UTF16-LE nor UTF16-BE and thus treat as binary
			if (isZeroByte && !couldBeUTF16LE && !couldBeUTF16BE) {
				break;
			}
		}

		// Handle case of 0-byte included
		if (containsZeroByte) {
			if (couldBeUTF16LE) {
				encoding = UTF16le;
			} else if (couldBeUTF16BE) {
				encoding = UTF16be;
			} else {
				seemsBinary = true;
			}
		}
	}

	// Auto guess encoding if configured
	if (autoGuessEncoding && !seemsBinary && !encoding && buffer) {
		return guessEncodingByBuffer(buffer.slice(0, bytesRead)).then(guessedEncoding => {
			return {
				seemsBinary: false,
				encoding: guessedEncoding
			};
		});
	}

	return { seemsBinary, encoding };
}

// https://ss64.com/nt/chcp.html
const windowsTerminalEncodings = {
	'437': 'cp437', // United States
	'850': 'cp850', // Multilingual(Latin I)
	'852': 'cp852', // Slavic(Latin II)
	'855': 'cp855', // Cyrillic(Russian)
	'857': 'cp857', // Turkish
	'860': 'cp860', // Portuguese
	'861': 'cp861', // Icelandic
	'863': 'cp863', // Canadian - French
	'865': 'cp865', // Nordic
	'866': 'cp866', // Russian
	'869': 'cp869', // Modern Greek
	'936': 'cp936', // Simplified Chinese
	'1252': 'cp1252' // West European Latin
};

export function resolveTerminalEncoding(verbose?: boolean): Promise<string> {
	let rawEncodingPromise: Promise<string>;

	// Support a global environment variable to win over other mechanics
	const cliEncodingEnv = process.env['VSCODE_CLI_ENCODING'];
	if (cliEncodingEnv) {
		if (verbose) {
			console.log(`Found VSCODE_CLI_ENCODING variable: ${cliEncodingEnv}`);
		}

		rawEncodingPromise = Promise.resolve(cliEncodingEnv);
	}

	// Linux/Mac: use "locale charmap" command
	else if (isLinux || isMacintosh) {
		rawEncodingPromise = new Promise<string>(resolve => {
			if (verbose) {
				console.log('Running "locale charmap" to detect terminal encoding...');
			}

			exec('locale charmap', (err, stdout, stderr) => resolve(stdout));
		});
	}

	// Windows: educated guess
	else {
		rawEncodingPromise = new Promise<string>(resolve => {
			if (verbose) {
				console.log('Running "chcp" to detect terminal encoding...');
			}

			exec('chcp', (err, stdout, stderr) => {
				if (stdout) {
					const windowsTerminalEncodingKeys = Object.keys(windowsTerminalEncodings);
					for (let i = 0; i < windowsTerminalEncodingKeys.length; i++) {
						const key = windowsTerminalEncodingKeys[i];
						if (stdout.indexOf(key) >= 0) {
							return resolve(windowsTerminalEncodings[key]);
						}
					}
				}

				return resolve(void 0);
			});
		});
	}

	return rawEncodingPromise.then(rawEncoding => {
		if (verbose) {
			console.log(`Detected raw terminal encoding: ${rawEncoding}`);
		}

		if (!rawEncoding || rawEncoding.toLowerCase() === 'utf-8' || rawEncoding.toLowerCase() === UTF8) {
			return UTF8;
		}

		const iconvEncoding = toIconvLiteEncoding(rawEncoding);
		if (iconv.encodingExists(iconvEncoding)) {
			return iconvEncoding;
		}

		if (verbose) {
			console.log('Unsupported terminal encoding, falling back to UTF-8.');
		}

		return UTF8;
	});
}
