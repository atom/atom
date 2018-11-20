/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

'use strict';

import * as es from 'event-stream';
import * as fs from 'fs';
import * as gulp from 'gulp';
import * as bom from 'gulp-bom';
import * as sourcemaps from 'gulp-sourcemaps';
import * as tsb from 'gulp-tsb';
import * as path from 'path';
import * as _ from 'underscore';
import * as monacodts from '../monaco/api';
import * as nls from './nls';
import { createReporter } from './reporter';
import * as util from './util';
import * as util2 from 'gulp-util';
const watch = require('./watch');

const reporter = createReporter();

function getTypeScriptCompilerOptions(src: string) {
	const rootDir = path.join(__dirname, `../../${src}`);
	const tsconfig = require(`../../${src}/tsconfig.json`);
	let options: { [key: string]: any };
	if (tsconfig.extends) {
		options = Object.assign({}, require(path.join(rootDir, tsconfig.extends)).compilerOptions, tsconfig.compilerOptions);
	} else {
		options = tsconfig.compilerOptions;
	}
	options.verbose = false;
	options.sourceMap = true;
	if (process.env['VSCODE_NO_SOURCEMAP']) { // To be used by developers in a hurry
		options.sourceMap = false;
	}
	options.rootDir = rootDir;
	options.baseUrl = rootDir;
	options.sourceRoot = util.toFileUri(rootDir);
	options.newLine = /\r\n/.test(fs.readFileSync(__filename, 'utf8')) ? 'CRLF' : 'LF';
	return options;
}

function createCompile(src: string, build: boolean, emitError?: boolean): (token?: util.ICancellationToken) => NodeJS.ReadWriteStream {
	const opts = _.clone(getTypeScriptCompilerOptions(src));
	opts.inlineSources = !!build;
	opts.noFilesystemLookup = true;

	const ts = tsb.create(opts, true, undefined, err => reporter(err.toString()));

	return function (token?: util.ICancellationToken) {

		const utf8Filter = util.filter(data => /(\/|\\)test(\/|\\).*utf8/.test(data.path));
		const tsFilter = util.filter(data => /\.ts$/.test(data.path));
		const noDeclarationsFilter = util.filter(data => !(/\.d\.ts$/.test(data.path)));

		const input = es.through();
		const output = input
			.pipe(utf8Filter)
			.pipe(bom())
			.pipe(utf8Filter.restore)
			.pipe(tsFilter)
			.pipe(util.loadSourcemaps())
			.pipe(ts(token))
			.pipe(noDeclarationsFilter)
			.pipe(build ? nls() : es.through())
			.pipe(noDeclarationsFilter.restore)
			.pipe(sourcemaps.write('.', {
				addComment: false,
				includeContent: !!build,
				sourceRoot: opts.sourceRoot
			}))
			.pipe(tsFilter.restore)
			.pipe(reporter.end(!!emitError));

		return es.duplex(input, output);
	};
}

const typesDts = [
	'node_modules/typescript/lib/*.d.ts',
	'node_modules/@types/**/*.d.ts',
	'!node_modules/@types/webpack/**/*',
	'!node_modules/@types/uglify-js/**/*',
];

export function compileTask(src: string, out: string, build: boolean): () => NodeJS.ReadWriteStream {

	return function () {
		const compile = createCompile(src, build, true);

		const srcPipe = es.merge(
			gulp.src(`${src}/**`, { base: `${src}` }),
			gulp.src(typesDts),
		);

		let generator = new MonacoGenerator(false);
		if (src === 'src') {
			generator.execute();
		}

		return srcPipe
			.pipe(generator.stream)
			.pipe(compile())
			.pipe(gulp.dest(out));
	};
}

export function watchTask(out: string, build: boolean): () => NodeJS.ReadWriteStream {

	return function () {
		const compile = createCompile('src', build);

		const src = es.merge(
			gulp.src('src/**', { base: 'src' }),
			gulp.src(typesDts),
		);
		const watchSrc = watch('src/**', { base: 'src' });

		let generator = new MonacoGenerator(true);
		generator.execute();

		return watchSrc
			.pipe(generator.stream)
			.pipe(util.incremental(compile, src, true))
			.pipe(gulp.dest(out));
	};
}

const REPO_SRC_FOLDER = path.join(__dirname, '../../src');

class MonacoGenerator {
	private readonly _isWatch: boolean;
	public readonly stream: NodeJS.ReadWriteStream;

	private readonly _watchers: fs.FSWatcher[];
	private readonly _watchedFiles: { [filePath: string]: boolean; };
	private readonly _fsProvider: monacodts.FSProvider;
	private readonly _declarationResolver: monacodts.DeclarationResolver;

	constructor(isWatch: boolean) {
		this._isWatch = isWatch;
		this.stream = es.through();
		this._watchers = [];
		this._watchedFiles = {};
		let onWillReadFile = (moduleId: string, filePath: string) => {
			if (!this._isWatch) {
				return;
			}
			if (this._watchedFiles[filePath]) {
				return;
			}
			this._watchedFiles[filePath] = true;

			const watcher = fs.watch(filePath);
			watcher.addListener('change', () => {
				this._declarationResolver.invalidateCache(moduleId);
				this._executeSoon();
			});
			this._watchers.push(watcher);
		};
		this._fsProvider = new class extends monacodts.FSProvider {
			public readFileSync(moduleId: string, filePath: string): Buffer {
				onWillReadFile(moduleId, filePath);
				return super.readFileSync(moduleId, filePath);
			}
		};
		this._declarationResolver = new monacodts.DeclarationResolver(this._fsProvider);

		if (this._isWatch) {
			const recipeWatcher = fs.watch(monacodts.RECIPE_PATH);
			recipeWatcher.addListener('change', () => {
				this._executeSoon();
			});
			this._watchers.push(recipeWatcher);
		}
	}

	private _executeSoonTimer: NodeJS.Timer | null = null;
	private _executeSoon(): void {
		if (this._executeSoonTimer !== null) {
			clearTimeout(this._executeSoonTimer);
			this._executeSoonTimer = null;
		}
		this._executeSoonTimer = setTimeout(() => {
			this._executeSoonTimer = null;
			this.execute();
		}, 20);
	}

	public dispose(): void {
		this._watchers.forEach(watcher => watcher.close());
	}

	private _run(): monacodts.IMonacoDeclarationResult | null {
		let r = monacodts.run3(this._declarationResolver);
		if (!r && !this._isWatch) {
			// The build must always be able to generate the monaco.d.ts
			throw new Error(`monaco.d.ts generation error - Cannot continue`);
		}
		return r;
	}

	private _log(message: any, ...rest: any[]): void {
		util2.log(util2.colors.cyan('[monaco.d.ts]'), message, ...rest);
	}

	public execute(): void {
		const startTime = Date.now();
		const result = this._run();
		if (!result) {
			// nothing really changed
			return;
		}
		if (result.isTheSame) {
			return;
		}

		fs.writeFileSync(result.filePath, result.content);
		fs.writeFileSync(path.join(REPO_SRC_FOLDER, 'vs/editor/common/standalone/standaloneEnums.ts'), result.enums);
		this._log(`monaco.d.ts is changed - total time took ${Date.now() - startTime} ms`);
		if (!this._isWatch) {
			this.stream.emit('error', 'monaco.d.ts is no longer up to date. Please run gulp watch and commit the new file.');
		}
	}
}
