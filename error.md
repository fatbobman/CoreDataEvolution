# CoreDataEvolution Tooling Error Catalog (WIP)

## Exit Codes

- `0`: Success
- `1`: User-fixable error (invalid args, invalid input, conflict, missing file, permission)
- `2`: Runtime/internal error (I/O failure, encode/decode failure, unexpected internal state)

## Global Rules

- Error output uses stderr.
- Success output uses stdout.
- Error message format:
  - `error[<CODE>]: <message>`
- Optional details:
  - `hint: <how to fix>`

## Error Codes

| Code | Exit | Command | Message Template |
| --- | --- | --- | --- |
| `TOOL-CONFIG-CONFLICT` | `1` | `init-config` | `error[TOOL-CONFIG-CONFLICT]: --output and --stdout cannot be used together.` |
| `TOOL-CONFIG-EXISTS` | `1` | `init-config` | `error[TOOL-CONFIG-EXISTS]: config file already exists at '<path>'. Use --force to overwrite.` |
| `TOOL-CONFIG-SCHEMA-UNSUPPORTED` | `1` | `generate`, `validate` | `error[TOOL-CONFIG-SCHEMA-UNSUPPORTED]: config schema version '<version>' is newer than supported '<supported-version>'. Please upgrade cde-tool.` |
| `TOOL-PRESET-INVALID` | `1` | `init-config` | `error[TOOL-PRESET-INVALID]: unsupported preset '<value>'. Allowed: minimal, full.` |
| `TOOL-OUTPUT-DIR-MISSING` | `1` | `init-config`, `generate` | `error[TOOL-OUTPUT-DIR-MISSING]: output directory does not exist: '<dir>'.` |
| `TOOL-WRITE-DENIED` | `1` | `init-config`, `generate` | `error[TOOL-WRITE-DENIED]: cannot write to '<path>' (permission denied).` |
| `TOOL-MODEL-PATH-MISSING` | `1` | `generate`, `validate` | `error[TOOL-MODEL-PATH-MISSING]: model path does not exist: '<path>'.` |
| `TOOL-SOURCE-DIR-MISSING` | `1` | `validate` | `error[TOOL-SOURCE-DIR-MISSING]: source directory does not exist: '<path>'.` |
| `TOOL-MODEL-VERSION-NOT-FOUND` | `1` | `generate`, `validate` | `error[TOOL-MODEL-VERSION-NOT-FOUND]: model version '<name>' not found in '<model-path>'.` |
| `TOOL-OVERWRITE-PROTECTED` | `1` | `generate` | `error[TOOL-OVERWRITE-PROTECTED]: target file exists and overwrite mode is 'none': '<path>'.` |
| `TOOL-CLEAN-STALE-REFUSED` | `1` | `generate` | `error[TOOL-CLEAN-STALE-REFUSED]: refusing to delete file outside output-dir: '<path>'.` |
| `TOOL-VALIDATION-FAILED` | `1` | `validate` | `error[TOOL-VALIDATION-FAILED]: validation failed with <count> error(s).` |
| `TOOL-JSON-ENCODE-FAILED` | `2` | `init-config` | `error[TOOL-JSON-ENCODE-FAILED]: failed to encode config template as JSON.` |
| `TOOL-MODEL-LOAD-FAILED` | `2` | `generate`, `validate` | `error[TOOL-MODEL-LOAD-FAILED]: failed to load model from '<path>'.` |
| `TOOL-MOMC-FAILED` | `2` | `generate`, `validate` | `error[TOOL-MOMC-FAILED]: model compilation failed (momc exit <status>).` |
| `TOOL-IO-FAILED` | `2` | all | `error[TOOL-IO-FAILED]: I/O operation failed: <reason>.` |
| `TOOL-INTERNAL` | `2` | all | `error[TOOL-INTERNAL]: unexpected internal error.` |

## Notes For Implementation

- Keep `Code` stable for machine parsing.
- Human-readable message can evolve, but placeholders should stay consistent.
- JSON/SARIF output should include:
  - `code`
  - `message`
  - `path` (if any)
  - `line` / `column` (if any)
  - `severity` (`error`/`warning`)
