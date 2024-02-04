# Changelog
<!--
Copyright © 2019-2024 Pleroma Authors
SPDX-License-Identifier: MIT
-->

## 0.6.0 - 2024-??-??

### Changed

- No longer strips periods from the end of a link as it may break the link

### Fixed

- Incorrectly linked URLs where the domain part has a trailing character such as ,;:>?!


## 0.5.2 - 2022-01-09

### Fixed

- Fixed hashtags getting stripped at the end of lines.

## 0.5.1 - 2021-07-07

### Fixed

- Parsing crash with URLs ending in unbalanced closed paren, no path separator, and no query parameters

## 0.5.0 - 2021-03-02

### Added

- More robust detection of URLs inside a parenthetical
- Only link ip addresses with a scheme
- Fix mentions in markdown
- Fix mentions with apostrophe endings

## 0.4.1 - 2020-12-21

### Fixed

- Incorrect detection of IPv4 addresses causing random numbers (e.g., $123.45) to get linked
- Inability to link mentions with a trailing apostrophe. e.g., @user@example's

## 0.4.0 - 2020-11-24

### Added

- Support for linking URLs with FQDNs (e.g., "google.com.")

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
