---
description: "Conventional Commits format and commit message guidelines"
alwaysApply: true
---

# Commit Message Rules

This project uses Conventional Commits format. All commit messages must follow this structure:

```
<type>(<scope>): <subject>

<body>

<footer>
```

## Commit Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, missing semicolons, etc.)
- `refactor`: Code refactoring (neither bug fix nor feature)
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks (dependencies, build, etc.)
- `revert`: Revert a previous commit
- `ci`: CI/CD changes
- `build`: Build system changes

## Commit Message Rules

- **Type**: Must be lowercase, one of the allowed types
- **Subject**:
  - Must be lowercase
  - Must not be empty
  - Must not end with a period
  - Max 100 characters for the entire header (type + scope + subject)
- **Body**:
  - Optional, separated by blank line from header
  - Each line must not exceed 100 characters
  - Must start with a blank line after the header
- **Footer**:
  - Optional, for breaking changes or issue references
  - Must start with a blank line after the body

## Examples

✅ **Good commit messages:**

```
feat(auth): add JWT authentication
fix(api): resolve rate limiting issue
docs(readme): update installation instructions
chore(deps): update dependencies
refactor(users): simplify user service logic
```

❌ **Bad commit messages:**

```
Add feature  # Missing type
feat: Add feature  # Subject should be lowercase
feat: add feature.  # Should not end with period
feat: add  # Subject too short/empty
```

## Commit Guidelines

1. **Write clear, descriptive commit messages**
2. **Use present tense** ("add" not "added")
3. **Use imperative mood** ("fix bug" not "fixes bug")
4. **Keep subject line concise** (under 50 characters when possible)
5. **Use body for detailed explanation** if needed
6. **Reference issues** in footer if applicable

## Verification

Before committing, verify:

- [ ] Commit message follows Conventional Commits format
- [ ] Type is lowercase and valid
- [ ] Subject is lowercase and descriptive
- [ ] Subject is under 100 characters
- [ ] Header (type + scope + subject) is under 100 characters
- [ ] Body lines (if present) are under 100 characters each
- [ ] Body starts with a blank line after the header
- [ ] Footer (if present) starts with a blank line after the body
