export declare class StaleWaiterError extends Error {
    constructor();
}
export declare const processNext: () => void;
export declare const waitForTurn: <T>({ getPriority, fn, onDone, onError, }: {
    getPriority: () => number | null;
    fn: () => Promise<T>;
    onDone: (result: T, triggerNext: () => void) => void;
    onError: (err: unknown) => void;
}) => void;
