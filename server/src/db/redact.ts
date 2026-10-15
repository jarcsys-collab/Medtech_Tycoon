/** Strips connection-string credentials and query strings from text before it is logged. */
export function redact(text: string): string {
  return text
    .replace(/(mongodb(?:\+srv)?:\/\/)[^@\s/]*@/gi, "$1***@")
    .replace(/(mongodb(?:\+srv)?:\/\/[^\s?]*)\?\S*/gi, "$1?***");
}

/** Error summary that is safe to log: class name, driver code and a redacted message. */
export function describeError(err: unknown): { name: string; code?: string | number; message: string } {
  if (err instanceof Error) {
    const code = (err as { code?: string | number }).code;
    return { name: err.name, ...(code !== undefined && { code }), message: redact(err.message) };
  }
  return { name: "UnknownError", message: "non-Error value thrown" };
}
