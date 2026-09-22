import type { TimelineTrackData } from '../../helpers/get-timeline-sequence-sort-key';
export type TimelineDisplayGroup = {
    readonly key: string;
    readonly numberOfSequences: number;
};
export type TimelineTrackWithDisplayGroup = TimelineTrackData & {
    readonly displayGroup: TimelineDisplayGroup | null;
};
export declare const addTimelineDisplayGroups: (tracks: readonly TimelineTrackData[]) => TimelineTrackWithDisplayGroup[];
