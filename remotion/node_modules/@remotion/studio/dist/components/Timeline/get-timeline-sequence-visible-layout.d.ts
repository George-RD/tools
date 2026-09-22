type TimelineSequenceVisibleLayout = {
    readonly marginLeft: number;
    readonly width: number;
    readonly cropLeft: number;
    readonly leftEdgeVisible: boolean;
    readonly rightEdgeVisible: boolean;
    readonly negativeStart: {
        readonly left: number;
        readonly width: number;
    } | null;
    readonly premount: {
        readonly left: number;
        readonly width: number;
    } | null;
    readonly postmount: {
        readonly left: number;
        readonly width: number;
    } | null;
    readonly media: {
        readonly left: number;
        readonly width: number;
        readonly offset: number;
        readonly fullWidth: number;
    } | null;
};
export declare const getTimelineSequenceVisibleLayout: ({ marginLeft, width, negativeStartWidth, premountWidth, postmountWidth, renderWindowLeft, renderWindowWidth, }: {
    readonly marginLeft: number;
    readonly width: number;
    readonly negativeStartWidth: number;
    readonly premountWidth: number;
    readonly postmountWidth: number;
    readonly renderWindowLeft: number;
    readonly renderWindowWidth: number;
}) => TimelineSequenceVisibleLayout | null;
export {};
