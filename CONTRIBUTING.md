# Contributing to Eliot

Thank you for considering contributing to Eliot! This document outlines the process for contributing to the project and helps to ensure your contributions can be efficiently reviewed and potentially integrated into the codebase.

## Code of Conduct

This project adheres to the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior via [https://christimahu.com/contact](https://christimahu.com/contact).

## How Can I Contribute?

### Reporting Bugs

Bug reports are tracked as [GitHub issues](https://github.com/christimahu/eliot/issues). When creating a bug report, please include as much detail as possible:

1. **Use a clear and descriptive title** for the issue to identify the problem.
2. **Describe the exact steps to reproduce the problem** in as much detail as possible.
3. **Provide specific examples** or code snippets to demonstrate the steps.
4. **Describe the behavior you observed** after following the steps and why you consider it a bug.
5. **Explain the behavior you expected** to see instead and why.
6. **Include details about your environment** (Elixir version, Erlang/OTP version, OS).

### Suggesting Enhancements

Enhancement suggestions are also tracked as [GitHub issues](https://github.com/christimahu/eliot/issues). When suggesting an enhancement:

1. **Use a clear and descriptive title** for the issue.
2. **Provide a detailed description of the suggested enhancement** and its expected behavior.
3. **Explain why this enhancement would be useful** to IoT developers and the broader Elixir community.
4. **List similar libraries or tools where this enhancement exists**, if applicable.

### Code Contributions

#### Development Workflow

1. **Fork the repository** on GitHub.
2. **Clone your fork** to your local machine.
3. **Create a new branch** from the `main` branch for your changes (`git checkout -b feature/my-new-feature`).
4. **Make your changes** following the coding conventions described below.
5. **Write or adapt tests** as necessary.
6. **Ensure all tests pass** by running `mix test`.
7. **Ensure code is formatted** by running `mix format`.
8. **Check code quality** with `mix credo`.
9. **Commit your changes** with clear commit messages.
10. **Push your branch** to your fork on GitHub.
11. **Submit a Pull Request** from your branch to the project's `main` branch.

#### Pull Request Process

1. Ensure your code follows the coding conventions.
2. Update documentation as necessary.
3. Add tests that verify your changes.
4. Make sure all tests pass and that test coverage is maintained or improved.
5. The PR should clearly describe the problem and solution.
6. The PR will be reviewed by at least one maintainer.

#### Coding Conventions

- **Code Style**: The codebase follows the official [Elixir Style Guide](https://github.com/elixir-lang/elixir/blob/main/lib/elixir/pages/Style%20Guide.md). We use [Credo](https://github.com/rrrene/credo) for static analysis to enforce these standards.
- **Formatting**: We use `mix format` for automated code formatting. Please run it before committing your changes.
- **Naming Conventions**:
  - Use `snake_case` for variables and function names.
  - Use `CamelCase` for module names.
- **Comments and Documentation**:
  - Use ExDoc-style comments for all public modules and functions (`@moduledoc` and `@doc`).
  - Write clear comments to explain complex or non-obvious code.
  - Keep comments up-to-date with code changes.
- **Error Handling**:
  - Use `{:ok, value}` and `{:error, reason}` tuples for functions that can fail.
  - Use exceptions primarily for programmer errors (e.g., invalid arguments).
  - Document expected error returns in the function's documentation.

#### Test Requirements

- All new code must have comprehensive tests using [ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html).
- Pull requests must maintain or improve the current test coverage. We aim for >95% coverage.
- Tests should cover:
  - Basic functionality (the "happy path").
  - Edge cases (e.g., empty lists, zero values, nils).
  - Error handling (invalid inputs, expected failures).

Example test structure:

```
defmodule Eliot.MyModuleTest do
  use ExUnit.Case, async: true

  describe "my_function/1" do
    test "returns :ok for valid input" do
      # Given: valid input
      input = "valid"

      # When: the function is called
      result = Eliot.MyModule.my_function(input)

      # Then: the result is as expected
      assert {:ok, "processed"} == result
    end

    test "returns :error for invalid input" do
      assert {:error, :invalid_input} == Eliot.MyModule.my_function(nil)
    end
  end
end
```

## Development Setup

### Prerequisites

- Elixir 1.14+
- Erlang/OTP 25+

### Building for Development

1. Clone your fork:
```
   git clone [https://github.com/yourusername/eliot.git](https://github.com/yourusername/eliot.git)
   cd eliot
```
2. Install dependencies:
```
   mix deps.get
```
3. Run the tests to ensure everything is working:
```
   mix test
```
4. To run the application in an interactive shell:
```
   iex -S mix
```

## Community Priorities

As a project focused on IoT data ingestion, contributions that enhance these aspects are particularly welcome:

1. **Reliability improvements** in the `ErrorHandler` or supervision tree.
2. **Performance enhancements** for high-throughput message processing.
3. **Additional protocol support** or improved MQTT feature handling.
4. **Documentation and examples** that help people integrate Eliot into their systems.
5. **Security features** that protect against common IoT vulnerabilities.

## Additional Notes

### Git Workflow Tips

- Keep your commits atomic and focused on a single issue.
- Write meaningful commit messages explaining the "what" and "why" of your changes.
- Rebase your branch onto the latest `main` before submitting a PR to maintain a clean history.

## Questions?

If you have any questions about contributing, please open an issue and tag it with `question`.

Thank you for contributing to Eliot and helping create a more robust open-source IoT ecosystem!
