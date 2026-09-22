import type { Writable } from 'node:stream';
export declare const writeWithBackpressure: ({ data, writable, }: {
    data: Buffer;
    writable: Writable;
}) => Promise<void>;
