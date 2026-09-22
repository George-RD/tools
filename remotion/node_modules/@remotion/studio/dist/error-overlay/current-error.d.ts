import type { ErrorRecord } from './react-overlay/listen-to-runtime-errors';
type CurrentError = {
    readonly error: Error;
    readonly symbolication: Promise<ErrorRecord | null>;
};
declare global {
    interface Window {
        remotion_currentErrors: CurrentError[] | undefined;
    }
}
export declare const registerCurrentError: (error: CurrentError) => () => void;
export declare const getCurrentError: () => CurrentError | null;
export {};
