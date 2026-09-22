"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.inferZodSchemaFromValue = inferZodSchemaFromValue;
exports.resolveCompositionSchema = resolveCompositionSchema;
const zod_schema_type_1 = require("./zod-schema-type");
const hasUnambiguousColorSyntax = (value) => {
    return /^(?:#|(?:rgb|hsl|hwb|lab|lch|oklab|oklch|color)\()/i.test(value.trim());
};
const isPlainObject = (value) => {
    if (value === null || typeof value !== 'object') {
        return false;
    }
    const prototype = Object.getPrototypeOf(value);
    return prototype === Object.prototype || prototype === null;
};
function inferZodSchemaFromValue({ value, z, zodTypes, path, }) {
    var _a;
    if (typeof value === 'string') {
        const key = (_a = path.at(-1)) === null || _a === void 0 ? void 0 : _a.toLowerCase();
        if (key === 'type') {
            return z.literal(value);
        }
        const keySuggestsColor = key === null || key === void 0 ? void 0 : key.includes('color');
        if (zodTypes && (keySuggestsColor || hasUnambiguousColorSyntax(value))) {
            try {
                zodTypes.ZodZypesInternals.parseColor(value);
                return zodTypes.zColor();
            }
            catch (_b) { }
        }
        return z.string();
    }
    if (typeof value === 'number') {
        return z.number();
    }
    if (typeof value === 'boolean') {
        return z.boolean();
    }
    if (value === null) {
        return z.null();
    }
    if (typeof value === 'undefined') {
        return z.undefined();
    }
    if (value instanceof Date) {
        return z.date();
    }
    if (Array.isArray(value)) {
        if (value.length === 0) {
            return z.any();
        }
        const elementSchema = inferZodSchemaFromValue({
            value: value[0],
            z,
            zodTypes,
            path,
        });
        if (!value.every((item) => (0, zod_schema_type_1.zodSafeParse)(elementSchema, item).success)) {
            return z.any();
        }
        return z.array(elementSchema);
    }
    if (isPlainObject(value)) {
        return z.object(Object.fromEntries(Object.entries(value).map(([key, child]) => [
            key,
            inferZodSchemaFromValue({
                value: child,
                z,
                zodTypes,
                path: [...path, key],
            }),
        ])));
    }
    return z.any();
}
function resolveCompositionSchema({ explicitSchema, defaultProps, z, zodTypes, }) {
    if (!z) {
        return 'no-zod';
    }
    if (explicitSchema) {
        if (typeof explicitSchema.safeParse !== 'function') {
            throw new Error('A value which is not a Zod schema was passed to `schema`');
        }
        return explicitSchema;
    }
    if (Object.keys(defaultProps).length === 0) {
        return 'no-schema';
    }
    return inferZodSchemaFromValue({
        value: defaultProps,
        z,
        zodTypes,
        path: [],
    });
}
