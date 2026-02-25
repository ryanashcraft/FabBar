# Changelog

All notable changes to FabBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-24

### Changed
- Accent color now clips to the glass indicator position in real time, matching native tab bar behavior during drag

## [1.0.2] - 2026-02-24

### Changed
- Inject content views directly into segment subtrees for proper Liquid Glass magnification, replacing the overlay-based tab rendering
- Support dynamic tab changes (count, order, identity)
- Leading-align tabs with fixed segment width when fewer than 3 tabs, matching native tab bar behavior
- Improved alignment and font weight for more accurate reproduction of the native tab bar

## [1.0.1] - 2026-01-26

### Fixed
- Fix tab staying dimmed after sheet dismissal

## [1.0.0] - 2026-01-23

Initial release.
