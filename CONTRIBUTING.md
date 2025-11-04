# Contributing to Rehab Exercise Tracking System

Thank you for your interest in contributing to the Rehab Exercise Tracking System! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Security Guidelines](#security-guidelines)

## Code of Conduct

This project adheres to a code of conduct that promotes a welcoming and inclusive environment. By participating, you agree to:

- Be respectful and professional in all interactions
- Accept constructive criticism gracefully
- Focus on what's best for the community and project
- Report any unacceptable behavior to the maintainers

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Elixir 1.16+ and Erlang/OTP 27+
- PostgreSQL 15+
- Node.js 18+ (for frontend/mobile development)
- Git configured with your identity
- Familiarity with event sourcing and CQRS patterns

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/YOUR_USERNAME/rehab-exercise-tracking-app.git
   cd rehab-exercise-tracking-app
   ```

2. **Install Dependencies**
   ```bash
   cd backend/rehab_tracking
   mix deps.get
   mix ecto.setup
   mix event_store.init
   ```

3. **Run Tests**
   ```bash
   mix test
   ```

4. **Start Development Server**
   ```bash
   iex -S mix phx.server
   ```

## Development Workflow

### Branch Naming

Use descriptive branch names following this pattern:

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring
- `test/description` - Test improvements

Example: `feature/add-rep-quality-alerts`

### Commit Messages

Follow the conventional commits specification:

```
type(scope): brief description

Longer description explaining the change and why it was necessary.

Refs: #issue-number
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Test additions or changes
- `chore`: Maintenance tasks

**Example:**
```
feat(projectors): add error handling to quality projector

Adds try-rescue blocks and proper error logging to quality projector
to prevent pipeline crashes from malformed events.

Refs: #42
```

## Coding Standards

### Elixir Style Guide

- Follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- Run `mix format` before committing
- Use `@spec` type specifications for all public functions
- Use `@moduledoc` for module documentation
- Add comprehensive `@doc` for public functions
- Keep functions small and focused (< 20 lines preferred)

### Type Specifications

**Always include type specs for public functions:**

```elixir
@spec evaluate_event(event()) :: :ok | {:error, term()}
def evaluate_event(%{kind: kind} = event) do
  # implementation
end
```

### Documentation

**Module documentation should include:**

```elixir
@moduledoc """
Brief description of the module's purpose.

## Responsibilities
- List key responsibilities
- One per line

## Examples

    iex> MyModule.function(arg)
    :ok
"""
```

### Error Handling

**Always handle errors gracefully:**

```elixir
def process_event(event) do
  try do
    # processing logic
    :ok
  rescue
    e ->
      Logger.error("Failed to process event: #{inspect(e)}")
      {:error, e}
  end
end
```

## Testing Requirements

### Test Coverage

- All new features must include tests
- Aim for 80%+ test coverage
- Run `mix test --cover` to check coverage

### Test Types

1. **Unit Tests** - Test individual functions
   ```elixir
   # test/lib/rehab_tracking/policy/nudges_test.exs
   test "generates nudge for missed sessions" do
     assert Nudges.evaluate_event(event) == :ok
   end
   ```

2. **Integration Tests** - Test event flows
   ```elixir
   # test/integration/event_pipeline_test.exs
   test "exercise session flows through projectors" do
     # test event sourcing pipeline
   end
   ```

3. **Contract Tests** - Test API contracts
   ```elixir
   # test/contract/api_schema_test.exs
   test "POST /api/v1/events matches schema" do
     # validate API contract
   end
   ```

### Running Tests

```bash
# All tests
mix test

# Specific test suite
mix test test/contract
mix test test/integration

# With coverage report
mix test --cover

# Watch mode during development
mix test.watch
```

## Pull Request Process

### Before Submitting

1. **Update tests** - Add/update tests for your changes
2. **Run quality checks**
   ```bash
   mix format --check-formatted  # Code formatting
   mix credo --strict            # Code quality
   mix sobelow                   # Security checks
   mix test --cover              # Test coverage
   ```

3. **Update documentation** - Update README, moduledocs, and inline docs
4. **Check for breaking changes** - Document any breaking API changes

### PR Template

When creating a PR, include:

```markdown
## Description
Brief description of the changes and motivation.

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] All tests pass locally
- [ ] Code coverage maintained/improved

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings introduced

## Related Issues
Fixes #(issue number)
```

### Review Process

1. At least one maintainer review required
2. All CI checks must pass
3. Code coverage must not decrease
4. No merge conflicts with main branch

### After Approval

- Maintainers will merge using squash merge
- Your commits will be squashed into one with a clean message
- Branch will be automatically deleted

## Security Guidelines

### Handling PHI (Protected Health Information)

**CRITICAL:** This system handles PHI and must comply with HIPAA:

1. **Never log PHI** - Use generic identifiers only
2. **Encrypt sensitive data** - Use AES-256-GCM encryption
3. **Consent tracking** - Verify consent before accessing PHI
4. **Access control** - Implement proper RBAC
5. **Audit logging** - Log all PHI access attempts

### Security Best Practices

- Never commit secrets or API keys
- Use environment variables for configuration
- Sanitize all user inputs
- Follow OWASP security guidelines
- Report security issues privately to maintainers

### Reporting Security Vulnerabilities

**DO NOT create public issues for security vulnerabilities.**

Email security concerns to: security@rehabtracking.example.com

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Questions or Need Help?

- **Documentation**: Check the [Wiki](https://github.com/jmanhype/rehab-exercise-tracking-app/wiki)
- **Discussions**: Use [GitHub Discussions](https://github.com/jmanhype/rehab-exercise-tracking-app/discussions)
- **Issues**: Search existing [Issues](https://github.com/jmanhype/rehab-exercise-tracking-app/issues)
- **Chat**: Join our [Discord](https://discord.gg/rehab-tracking) (if available)

## Recognition

Contributors are recognized in our:
- README.md contributors section
- Release notes
- Annual contributor highlights

Thank you for contributing to improving patient rehabilitation outcomes!

---

**Last Updated**: 2025-01-XX
**Version**: 1.0
