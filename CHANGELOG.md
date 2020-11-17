# Changelog

## [Unreleased]

## 0.3.0 - 2020-11-17

### Added

- Support returning result as iodata and as safe iodata

### Fixed

- Hashtags followed by HTML tags "a", "code" and "pre" were not detected
- Incorrect parsing of HTML links inside HTML tags
- Punctuation marks in the end of urls were included in the html links
- Incorrect parsing of mentions with symbols before them

## 0.2.0 - 2020-07-21

### Added

- Added a `do_parse/4` clause to skip mentions when we're already skipping something else (eg, when inside a link)

### Fixed

- Fixed a typo in the readme

### Changed

- Refactored `Linkify.Parser.parse/2` to enumerate over the types instead of the opts
- Update dependencies

## 0.1.0 - 2019-07-11

- Initial release
