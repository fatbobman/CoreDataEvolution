# CoreDataEvolution CLI Error Catalog (WIP)

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
| `CLI-CONFIG-CONFLICT` | `1` | `init-config` | `error[CLI-CONFIG-CONFLICT]: --output and --stdout cannot be used together.` |
| `CLI-CONFIG-EXISTS` | `1` | `init-config` | `error[CLI-CONFIG-EXISTS]: config file already exists at '<path>'. Use --force to overwrite.` |
| `CLI-CONFIG-SCHEMA-UNSUPPORTED` | `1` | `generate`, `validate` | `error[CLI-CONFIG-SCHEMA-UNSUPPORTED]: config schema version '<version>' is newer than supported '<supported-version>'. Please upgrade cde-tool.` |
| `CLI-PRESET-INVALID` | `1` | `init-config` | `error[CLI-PRESET-INVALID]: unsupported preset '<value>'. Allowed: minimal, full.` |
| `CLI-OUTPUT-DIR-MISSING` | `1` | `init-config`, `generate` | `error[CLI-OUTPUT-DIR-MISSING]: output directory does not exist: '<dir>'.` |
| `CLI-WRITE-DENIED` | `1` | `init-config`, `generate` | `error[CLI-WRITE-DENIED]: cannot write to '<path>' (permission denied).` |
| `CLI-MODEL-PATH-MISSING` | `1` | `generate`, `validate` | `error[CLI-MODEL-PATH-MISSING]: model path does not exist: '<path>'.` |
| `CLI-SOURCE-DIR-MISSING` | `1` | `validate` | `error[CLI-SOURCE-DIR-MISSING]: source directory does not exist: '<path>'.` |
| `CLI-MODEL-VERSION-NOT-FOUND` | `1` | `generate`, `validate` | `error[CLI-MODEL-VERSION-NOT-FOUND]: model version '<name>' not found in '<model-path>'.` |
| `CLI-OVERWRITE-PROTECTED` | `1` | `generate` | `error[CLI-OVERWRITE-PROTECTED]: target file exists and overwrite mode is 'none': '<path>'.` |
| `CLI-CLEAN-STALE-REFUSED` | `1` | `generate` | `error[CLI-CLEAN-STALE-REFUSED]: refusing to delete file outside output-dir: '<path>'.` |
| `CLI-VALIDATION-FAILED` | `1` | `validate` | `error[CLI-VALIDATION-FAILED]: validation failed with <count> error(s).` |
| `CLI-JSON-ENCODE-FAILED` | `2` | `init-config` | `error[CLI-JSON-ENCODE-FAILED]: failed to encode config template as JSON.` |
| `CLI-MODEL-LOAD-FAILED` | `2` | `generate`, `validate` | `error[CLI-MODEL-LOAD-FAILED]: failed to load model from '<path>'.` |
| `CLI-MOMC-FAILED` | `2` | `generate`, `validate` | `error[CLI-MOMC-FAILED]: model compilation failed (momc exit <status>).` |
| `CLI-IO-FAILED` | `2` | all | `error[CLI-IO-FAILED]: I/O operation failed: <reason>.` |
| `CLI-INTERNAL` | `2` | all | `error[CLI-INTERNAL]: unexpected internal error.` |

## Notes For Implementation

- Keep `Code` stable for machine parsing.
- Human-readable message can evolve, but placeholders should stay consistent.
- JSON/SARIF output should include:
  - `code`
  - `message`
  - `path` (if any)
  - `line` / `column` (if any)
  - `severity` (`error`/`warning`)
