"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.mergeInlineAudioTracks = exports.inlineAudioTrackToPreprocessedAudioTrack = void 0;
const node_path_1 = __importDefault(require("node:path"));
const chunk_1 = require("./chunk");
const delete_directory_1 = require("./delete-directory");
const merge_audio_track_1 = require("./merge-audio-track");
const MAX_INLINE_AUDIO_INPUTS = 10;
const inlineAudioTrackToPreprocessedAudioTrack = ({ track, relativeToInSamples, padToDurationInSamples, }) => {
    const delayInSamples = Math.max(0, track.startInSamples - relativeToInSamples);
    const padAtEndInSamples = padToDurationInSamples === null
        ? 0
        : Math.max(0, padToDurationInSamples - delayInSamples - track.durationInSamples);
    return {
        outName: track.outName,
        filter: {
            pad_start: delayInSamples === 0
                ? null
                : `adelay=${new Array(3).fill(`${delayInSamples}S`).join('|')}`,
            pad_end: padAtEndInSamples === 0 ? null : `apad=pad_len=${padAtEndInSamples}`,
        },
    };
};
exports.inlineAudioTrackToPreprocessedAudioTrack = inlineAudioTrackToPreprocessedAudioTrack;
const mergeInlineAudioTracks = async ({ tracks, downloadMap, remotionRoot, indent, logLevel, binariesDirectory, cancelSignal, fps, chunkLengthInSeconds, sampleRate, }) => {
    var _a;
    let currentTracks = tracks.sort((a, b) => a.startInSamples - b.startInSamples);
    let level = 0;
    while (currentTracks.length > 1) {
        const groups = (0, chunk_1.chunk)(currentTracks, MAX_INLINE_AUDIO_INPUTS);
        currentTracks = await Promise.all(groups.map(async (group, index) => {
            if (group.length === 1) {
                return group[0];
            }
            const [{ startInSamples }] = group;
            const durationInSamples = Math.max(...group.map((track) => {
                return (track.startInSamples - startInSamples + track.durationInSamples);
            }));
            const outName = node_path_1.default.join(downloadMap.audioMixing, `inline-${level}-${index}.wav`);
            await (0, merge_audio_track_1.mergeAudioTrack)({
                files: group.map((track) => (0, exports.inlineAudioTrackToPreprocessedAudioTrack)({
                    track,
                    relativeToInSamples: startInSamples,
                    padToDurationInSamples: null,
                })),
                outName,
                downloadMap,
                remotionRoot,
                indent,
                logLevel,
                binariesDirectory,
                cancelSignal,
                onProgress: () => undefined,
                fps,
                chunkLengthInSeconds,
                sampleRate,
            });
            for (const track of group) {
                (0, delete_directory_1.deleteDirectory)(track.outName);
            }
            return {
                outName,
                startInSamples,
                durationInSamples,
            };
        }));
        level++;
    }
    return (_a = currentTracks[0]) !== null && _a !== void 0 ? _a : null;
};
exports.mergeInlineAudioTracks = mergeInlineAudioTracks;
