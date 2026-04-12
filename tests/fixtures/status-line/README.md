# Status Line Test Fixtures

These fixtures contain intentional attack payloads for testing the `/serious-code` progress segment in `statusline-command.sh`.

## Files

- `valid_status.json` -- Well-formed status.json with active agents
- `empty_status.json` -- Empty JSON object `{}`
- `malicious_status.json` -- Contains ANSI escape sequences (`\x1b[2J\x1b[H`, clear-screen attack) in plan_name
- `bidi_status.json` -- Contains U+202E (RLO, right-to-left override) bidi codepoint in plan_name
- `oversized_status.json` -- 10KB+ plan_name field to test truncation

## Security Note

Do NOT remove the attack payloads from these fixtures. They are required for security regression testing. The malicious and bidi fixtures test that the sanitization pipeline in statusline-command.sh correctly strips dangerous byte sequences before rendering to the terminal.
