# Change Log

**[Keep a Changelog](http://keepachangelog.com/) | [Semantic Versioning](http://semver.org/)**

## [1.1.1] - 2024-04-05

Fix master key assignment

### Fixed

- Don't set rails master key if param is empty, so that config/master.key will get used instead

## [1.1] - 2024-04-05

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

## [1.0] - 2023-11-17

Initial release
