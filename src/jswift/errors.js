export class JSwiftError extends Error {
  /**
   * @param {string} message
   * @param {{ line?: number; column?: number; phase?: string }} [loc]
   */
  constructor(message, loc = {}) {
    super(message);
    this.name = "JSwiftError";
    this.line = loc.line;
    this.column = loc.column;
    this.phase = loc.phase ?? "compile";
  }

  format() {
    if (this.line != null && this.column != null) {
      return `${this.phase} error at ${this.line}:${this.column}: ${this.message}`;
    }
    return `${this.phase} error: ${this.message}`;
  }
}

export function syntaxError(message, token, phase = "parse") {
  const line = token?.line ?? 1;
  const column = token?.column ?? 1;
  return new JSwiftError(message, { line, column, phase });
}
