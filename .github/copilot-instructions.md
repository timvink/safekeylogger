

- Making a release:
  1. Update the version number in `package.json` according to semantic versioning rules.
  3. Commit the changes with a message like "chore: release vX.Y.Z".
  4. Tag the commit with the version number (e.g., `git tag vX.Y.Z`).
  5. Push the commit and tags to the remote repository.
  2. Run `make release` to generate production-ready files and create a release on github
  6. Use the `gh` CLI tool to update the release description with relevant notes and changes since the last version (use `git diff <last_version> <new_version>`).