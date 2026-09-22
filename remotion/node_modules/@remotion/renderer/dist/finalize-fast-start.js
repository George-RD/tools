"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.finalizeFastStart = void 0;
const node_crypto_1 = require("node:crypto");
const node_fs_1 = require("node:fs");
const node_path_1 = __importDefault(require("node:path"));
const call_ffmpeg_1 = require("./call-ffmpeg");
const logger_1 = require("./logger");
const finalizeFastStart = async ({ input, output, muxer, force, indent, logLevel, binariesDirectory, cancelSignal, }) => {
    var _a;
    let fastStartFile = null;
    for (let attempt = 0; attempt < 3; attempt++) {
        const candidate = node_path_1.default.join(node_path_1.default.dirname(output), `${node_path_1.default.basename(output)}.${(0, node_crypto_1.randomUUID)()}.remotion-in-progress`);
        const task = (0, call_ffmpeg_1.callFf)({
            bin: 'ffmpeg',
            args: [
                '-hide_banner',
                '-i',
                input,
                '-c',
                'copy',
                '-movflags',
                'faststart',
                '-y',
                '-f',
                muxer,
                candidate,
            ],
            indent,
            logLevel,
            binariesDirectory,
            cancelSignal: cancelSignal !== null && cancelSignal !== void 0 ? cancelSignal : undefined,
        });
        let stderr = '';
        (_a = task.stderr) === null || _a === void 0 ? void 0 : _a.on('data', (data) => {
            stderr += data.toString();
        });
        try {
            await task;
            fastStartFile = candidate;
            break;
        }
        catch (error) {
            await node_fs_1.promises.rm(candidate, { force: true }).catch(() => undefined);
            const isReopenFailure = stderr.includes('Unable to re-open') &&
                stderr.includes('output file for shifting data');
            if (!isReopenFailure || attempt === 2) {
                throw error;
            }
            logger_1.Log.verbose({ indent, logLevel, tag: 'stitchFramesToVideo()' }, `Retrying Fast Start finalization (attempt ${attempt + 2} of 3)`);
        }
    }
    if (fastStartFile === null) {
        throw new Error('Fast Start finalization did not produce an output file');
    }
    if (force) {
        await node_fs_1.promises.rename(fastStartFile, output);
        return;
    }
    try {
        await node_fs_1.promises.link(fastStartFile, output);
    }
    finally {
        await node_fs_1.promises.rm(fastStartFile, { force: true });
    }
};
exports.finalizeFastStart = finalizeFastStart;
