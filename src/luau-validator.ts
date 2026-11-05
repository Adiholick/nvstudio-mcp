export interface ValidationResult {
    valid: boolean;
    error?: string;
    line?: number;
}

/**
 * Heuristic pre-commit syntax validator for Luau.
 * Validates bracket parity, string literals, multiline comments,
 * and block keywords (function, do, statement if ... then, repeat ... until, end).
 */
export function validateLuauSyntax(source: string): ValidationResult {
    const lines = source.split('\n');
    let parenDepth = 0;   // ()
    let braceDepth = 0;   // {}
    let bracketDepth = 0; // []
    let blockDepth = 0;   // function, do, if ... then -> end
    let repeatDepth = 0;  // repeat -> until

    let inString = false;
    let stringChar = '';
    let inMultilineString = false;
    let multilineEqCount = 0;
    let inMultilineComment = false;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        let j = 0;
        const lineTokens: string[] = [];

        while (j < line.length) {
            const char = line[j];
            const nextChar = line[j + 1] || '';

            // Multiline comment start: --[[ or --[===[
            if (!inString && !inMultilineString && !inMultilineComment) {
                if (char === '-' && nextChar === '-') {
                    const nextNextChar = line[j + 2] || '';
                    if (nextNextChar === '[') {
                        let k = j + 3;
                        let eq = 0;
                        while (line[k] === '=') { eq++; k++; }
                        if (line[k] === '[') {
                            inMultilineComment = true;
                            multilineEqCount = eq;
                            j = k + 1;
                            continue;
                        }
                    }
                    // Single-line comment, ignore rest of line
                    break;
                }
            }

            if (inMultilineComment) {
                if (char === ']') {
                    let k = j + 1;
                    let eq = 0;
                    while (line[k] === '=') { eq++; k++; }
                    if (line[k] === ']' && eq === multilineEqCount) {
                        inMultilineComment = false;
                        j = k + 1;
                        continue;
                    }
                }
                j++;
                continue;
            }

            // String literals
            if (!inString && !inMultilineString) {
                if (char === '"' || char === "'") {
                    inString = true;
                    stringChar = char;
                    j++;
                    continue;
                }
                if (char === '[') {
                    let k = j + 1;
                    let eq = 0;
                    while (line[k] === '=') { eq++; k++; }
                    if (line[k] === '[') {
                        inMultilineString = true;
                        multilineEqCount = eq;
                        j = k + 1;
                        continue;
                    }
                }
            }

            if (inString) {
                if (char === '\\' && (nextChar === '"' || nextChar === "'" || nextChar === '\\')) {
                    j += 2;
                    continue;
                }
                if (char === stringChar) {
                    inString = false;
                }
                j++;
                continue;
            }

            if (inMultilineString) {
                if (char === ']') {
                    let k = j + 1;
                    let eq = 0;
                    while (line[k] === '=') { eq++; k++; }
                    if (line[k] === ']' && eq === multilineEqCount) {
                        inMultilineString = false;
                        j = k + 1;
                        continue;
                    }
                }
                j++;
                continue;
            }

            // Outside strings & comments: collect bracket depth & tokens
            if (char === '(') { 
                parenDepth++; 
                lineTokens.push('('); 
            } else if (char === ')') {
                parenDepth--;
                lineTokens.push(')');
                if (parenDepth < 0) return { valid: false, error: 'Kelebihan tutup kurung ")"', line: i + 1 };
            } else if (char === '{') { 
                braceDepth++; 
                lineTokens.push('{'); 
            } else if (char === '}') {
                braceDepth--;
                lineTokens.push('}');
                if (braceDepth < 0) return { valid: false, error: 'Kelebihan tutup kurawal "}"', line: i + 1 };
            } else if (char === '[') { 
                bracketDepth++; 
                lineTokens.push('['); 
            } else if (char === ']') {
                bracketDepth--;
                lineTokens.push(']');
                if (bracketDepth < 0) return { valid: false, error: 'Kelebihan tutup siku "]"', line: i + 1 };
            } else if (char === '=') {
                lineTokens.push('=');
            } else if (char === ',') {
                lineTokens.push(',');
            } else if (/[a-zA-Z_]/.test(char)) {
                let start = j;
                while (j < line.length && /[a-zA-Z0-9_]/.test(line[j])) {
                    j++;
                }
                lineTokens.push(line.substring(start, j));
                continue;
            }

            j++;
        }

        if (inString) {
            return { valid: false, error: 'String tidak ditutup (unclosed string literal)', line: i + 1 };
        }

        // Process line tokens for block balance
        let statementIfCount = 0;
        for (let t = 0; t < lineTokens.length; t++) {
            const tok = lineTokens[t];
            const prevTok = t > 0 ? lineTokens[t - 1] : null;

            if (tok === 'function') {
                blockDepth++;
            } else if (tok === 'do') {
                blockDepth++;
            } else if (tok === 'if') {
                // Luau expression if is preceded by '=', 'return', '(', ',', '{', '[', 'and', 'or', 'not'
                const isExpr = prevTok && ['=', 'return', '(', ',', '{', '[', 'and', 'or', 'not'].includes(prevTok);
                if (!isExpr) {
                    statementIfCount++;
                }
            } else if (tok === 'then') {
                const isElseIf = lineTokens.includes('elseif');
                if (!isElseIf) {
                    if (statementIfCount > 0) {
                        blockDepth++;
                        statementIfCount--;
                    }
                }
            } else if (tok === 'repeat') {
                repeatDepth++;
            } else if (tok === 'until') {
                repeatDepth--;
                if (repeatDepth < 0) return { valid: false, error: 'Kelebihan kata kunci "until"', line: i + 1 };
            } else if (tok === 'end') {
                blockDepth--;
                if (blockDepth < 0) return { valid: false, error: 'Kelebihan kata kunci "end"', line: i + 1 };
            }
        }
    }

    if (inMultilineString) return { valid: false, error: 'Multiline string tidak ditutup (unclosed [[ ]])' };
    if (inMultilineComment) return { valid: false, error: 'Multiline comment tidak ditutup (unclosed --[[ ]])' };
    
    if (parenDepth > 0) return { valid: false, error: 'Kekurangan tutup kurung ")"' };
    if (braceDepth > 0) return { valid: false, error: 'Kekurangan tutup kurawal "}"' };
    if (bracketDepth > 0) return { valid: false, error: 'Kekurangan tutup siku "]"' };

    if (repeatDepth > 0) return { valid: false, error: 'Kekurangan kata kunci "until"' };
    if (blockDepth > 0) return { valid: false, error: 'Kekurangan kata kunci "end" (blok tidak ditutup)' };

    return { valid: true };
}
