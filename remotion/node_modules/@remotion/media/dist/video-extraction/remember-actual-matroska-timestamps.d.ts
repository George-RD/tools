export declare const rememberActualMatroskaTimestamps: (isMatroska: boolean) => {
    observeTimestamp: (startTime: number) => void;
    getRealTimestamp: (observedTimestamp: number) => number | null;
};
export type RememberActualMatroskaTimestamps = ReturnType<typeof rememberActualMatroskaTimestamps>;
