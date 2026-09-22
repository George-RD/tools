import type { AudioSample } from 'mediabunny';
export declare const makeAudioCache: () => {
    addFrame: (sample: AudioSample) => void;
    clearBeforeThreshold: (threshold: number) => void;
    deleteAll: () => void;
    getSamples: (timestamp: number, durationInSeconds: number) => AudioSample[];
    getOldestTimestamp: () => number;
    getNewestTimestamp: () => number | null;
    getOpenTimestamps: () => number[];
    getTotalSize: () => number;
};
export type AudioCache = ReturnType<typeof makeAudioCache>;
