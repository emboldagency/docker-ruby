# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org).

## [Unreleased]

[What's this section for?](https://keepachangelog.com/en/1.1.0/#effort)

<!-- ### Added -->

<!-- ### Changed -->

<!-- ### Deprecated -->

<!-- ### Removed -->

<!-- ### Fixed -->

<!-- ### Security -->

## [v1.2.0](https://github.com/emboldagency/docker-ruby/tree/v1.2.0) - 2024-08-07

Added GitHub Actions workflows for DockerHub and Coder template publishing, and updated Coder provider, default parameter versions, fixed deprecations, and used locals to reduce repetition.

### Added

- GitHub Actions workflows to push to DockerHub & publish the Coder template
- Workflow can be run manually, with options to skip a job by name

### Changed

- Updated Coder provider
- Updated default parameter versions
- Fix deprecations
- Use locals to help avoid repetition and make it easier to change references when Coder provider makes breaking changes

[Full Changelog](https://github.com/emboldagency/docker-ruby/compare/v1.1.2...v1.2.0)

## [v1.1.2] - 2024-04-08

Ensure our gems get installed before dotfiles

### Fixed

- Move gem home creation and gem install code into base

[Full Changelog](https://github.com/emboldagency/docker-ruby/compare/v1.1.1...v1.1.2)

## [v1.1.1] - 2024-04-05

Fix master key assignment

### Fixed

- Don't set rails master key if param is empty, so that config/master.key will get used instead

[Full Changelog](https://github.com/emboldagency/docker-ruby/compare/v1.1.0...v1.1.1)

## [v1.1.0] - 2024-04-05

Added dynamic template options to customize the workspace.

### Added

- Added this changelog!
- New workspace parameters
  - _Ruby Version_: Gems are stored in versioned folders now so Ruby versions can be changed with a rebuild
  - _Pulsar App Name_: Workspace name can now be different than the Pulsar app name
  - _Rails Master Key_: Can be set instead of creating a config/master.key file
  - _Postgres Version_: Select which Postgres image the database container uses. **This is immutable for now, since changing the version when the database volume has already been initialized will cause the Postgres container to fail due to mismatched version**
  - _Ubuntu Version_: Choose a different version of our base image by the Ubuntu version number

### Changed

- Move images back to DockerHub, stop building the images during workspace startup.

### Fixed

- Docker Registry authentication now works using `TF_VAR` provided to the Coder stack
- Removed stats to avoid confusion since they show the host stats instead of the stats for the workspace

## [v1.0.0] - 2023-11-17

Initial release
