/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as fs from 'fs';
import * as crypto from 'crypto';
import * as stream from 'stream';
import { once } from 'vs/base/common/functional';

export function checksum(path: string, sha1hash: string): Promise<void> {
	const promise = new Promise<string | undefined>((c, e) => {
		const input = fs.createReadStream(path);
		const hash = crypto.createHash('sha1');
		const hashStream = hash as any as stream.PassThrough;
		input.pipe(hashStream);

		const done = once((err?: Error, result?: string) => {
			input.removeAllListeners();
			hashStream.removeAllListeners();

			if (err) {
				e(err);
			} else {
				c(result);
			}
		});

		input.once('error', done);
		input.once('end', done);
		hashStream.once('error', done);
		hashStream.once('data', (data: Buffer) => done(undefined, data.toString('hex')));
	});

	return promise.then(hash => {
		if (hash !== sha1hash) {
			return Promise.reject(new Error('Hash mismatch'));
		}

		return Promise.resolve();
	});
}
