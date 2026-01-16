# Contributing

Thanks for being interested in contributing!

## How to submit issues
Please use the issue templates provided in the issue tracker.

## How to submit PRs
1. Fork the repo
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes. Ensure your commit messages follow **Conventional Commits**:
   - Format: `<type>(<scope>): <subject>`
   - Example: `feat: add new feature`, `fix: resolve crash on startup`
   - **Rules**:
     - Subject must be lowercase.
     - No period at the end.
     - Max length of 100 characters.
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Commit Message Guidelines
We use [Commitlint](https://commitlint.js.org/) to enforce [Conventional Commits](https://www.conventionalcommits.org/).
- **Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- **Length**: Maximum 100 characters for the header.
- **Formatting**:
  - Lowercase subject.
  - No trailing period.

## Coding Standards
- Please ensure your code communicates its intent clearly.
- Run tests before submitting.
