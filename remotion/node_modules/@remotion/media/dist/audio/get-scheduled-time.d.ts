export declare const getScheduledTime: ({ mediaTimestamp, targetTime, currentTime, sequenceStartTime, }: {
    mediaTimestamp: number;
    targetTime: number;
    currentTime: number;
    sequenceStartTime: number;
}) => number;
export declare const getDurationOfNode: ({ sourceDurationInSeconds, sourceOffsetInSeconds, offset, }: {
    sourceDurationInSeconds: number;
    sourceOffsetInSeconds: number;
    offset: number;
}) => number;
export declare const getTrimStartForAudioNode: ({ mediaTimestamp, targetTime, sequenceStartTime, combinedPlaybackRate, sourceStartOffsetInSeconds, }: {
    mediaTimestamp: number;
    targetTime: number;
    sequenceStartTime: number;
    combinedPlaybackRate: number;
    sourceStartOffsetInSeconds: number;
}) => number;
