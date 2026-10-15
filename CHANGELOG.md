# Changelog

All notable changes to this repository are documented here. Dates are the
release/commit date, not the build date of the bundled Chromium binary.

## Unreleased

### Added

- `verify.sh` smoke-test script — extracts the zip, launches the bundled
  Chromium in `--headless=new` against a `data:text/html,...` URL, and
  confirms the page rendered. Exits non-zero with a diagnostic message on
  any failure. Safe to wire into CI or Lambda build pipelines.
- `Build Info` block in README surfaces the SHA256 of
  `chromium-lambda.zip`, the binary build date (2025-06-27, Chromium ~137
  stable), and the `verify.sh` one-liner so users can confirm their
  download before building a layer.

### Changed

- Version-history note: previous README listed "v1.0.0 / Chromium 114" as
  the bundled version. The current `chromium-lambda.zip` binary was built
  2025-06-27 and reports as Chromium ~137. Version-history wording has been
  corrected to reflect the actual artifact in the zip.
- Python usage examples now use `./bin/chromium` (relative to the extracted
  directory) instead of the placeholder `/path/to/chromium-lambda/bin/chromium`.

## 2025-07-14

### Added

- Initial public release with Chromium binary (built 2025-06-27) and
  supporting shared libraries for AWS Lambda.

[1]: https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/VERSION
