export interface ValidationResult {
    valid: boolean;
    error?: string;
    line?: number;
}

export function validateLuauSyntax(source: string): ValidationResult {
    const lines = source.split('\n');
    
    // Stack for blocks: function, do, if, for, while, repeat
    // We'll keep it simple: just count block openers vs block closers (end, until)
    // Note: This is a heuristic pre-commit check. It doesn't replace a full AST parser,
    // Bracket stacks
    let parenDepth = 0; // ()
    let braceDepth = 0; // {}
    let bracketDepth = 0; // []

    let inString = false;
    let stringChar = '';
    let inMultilineString = false;
    let multilineEqCount = 0;

    let inMultilineComment = false;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        let j = 0;

        while (j < line.length) {
            const char = line[j];
            const nextChar = line[j + 1] || '';

            // Handle multiline comments
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
                    // Single line comment, skip rest of line
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

            // Handle strings
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

            // At this point, we are outside strings and comments.
            // Check brackets
            if (!inString && !inMultilineString && !inMultilineComment) {
                if (char === '(') parenDepth++;
                else if (char === ')') {
                    parenDepth--;
                    if (parenDepth < 0) return { valid: false, error: 'Kelebihan tutup kurung ")"', line: i + 1 };
                }
                else if (char === '{') braceDepth++;
                else if (char === '}') {
                    braceDepth--;
                    if (braceDepth < 0) return { valid: false, error: 'Kelebihan tutup kurawal "}"', line: i + 1 };
                }
                else if (char === '[') bracketDepth++;
                else if (char === ']') {
                    bracketDepth--;
                    if (bracketDepth < 0) return { valid: false, error: 'Kelebihan tutup siku "]"', line: i + 1 };
                }
            }

            j++;
        }
        
        if (inString) {
            return { valid: false, error: 'String tidak ditutup (unclosed string literal)', line: i + 1 };
        }
    }

    if (inMultilineString) return { valid: false, error: 'Multiline string tidak ditutup (unclosed [[ ]])' };
    if (inMultilineComment) return { valid: false, error: 'Multiline comment tidak ditutup (unclosed --[[ ]])' };
    
    if (parenDepth > 0) return { valid: false, error: 'Kekurangan tutup kurung ")"' };
    if (braceDepth > 0) return { valid: false, error: 'Kekurangan tutup kurawal "}"' };
    if (bracketDepth > 0) return { valid: false, error: 'Kekurangan tutup siku "]"' };

    return { valid: true };
}
