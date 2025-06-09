# 🧪 Eliot Testing Guide 🧪

Welcome to the Eliot testing documentation! This guide explains how to run tests, understand the test suite, and create new tests for the Eliot system.

## 📋 Table of Contents

- [Test Suite Overview](#test-suite-overview)
- [Running Tests](#running-tests)
- [Understanding Test Types](#understanding-test-types)
- [Test Framework (ExUnit)](#test-framework-exunit)
- [Writing New Tests](#writing-new-tests)
- [Test Coverage](#test-coverage)
- [Continuous Integration](#continuous-integration)
- [Testing Best Practices](#testing-best-practices)

## Test Suite Overview

Eliot includes a comprehensive test suite that validates:

- **Core Functionality**: Correctness of module logic and public APIs.
- **OTP Behavior**: Proper GenServer/Supervisor initialization, state changes, and shutdown.
- **Error Handling**: Circuit breaker and retry logic correctness.
- **Integration**: How different components of the system interact.

Tests are organized into two main categories:
- **Unit Tests**: Testing individual modules and functions in isolation.
- **Integration Tests**: Testing the interaction between different components (e.g., `ErrorHandler` and `Logger`).

## Running Tests

### Running All Tests

The simplest way to run all tests is using the standard `mix` command:

```
mix test
```

This will compile the project if needed and run all tests found in the `test/` directory.

### Running a Single Test File

To run tests from a single file:

```
mix test test/eliot/error_handler_test.exs
```

### Running a Single Test

To run a specific test case from a file, you can specify the line number:

```
mix test test/eliot/error_handler_test.exs:25
```

### Excluding or Including Tests with Tags

You can tag tests to run specific categories. For example, integration tests are tagged with `:integration`.

```
# Run only integration tests
mix test --only integration

# Run all tests except integration tests
mix test --exclude integration
```

## Understanding Test Types

### Unit Tests

Unit tests check individual modules and functions in isolation. These tests focus on:
- Public function return values for given inputs.
- GenServer callbacks and state transitions.
- Logic inside private functions (tested via their public-facing callers).

Sample unit test files:
- `test/eliot/elixir_test.exs`
- `test/eliot/error_handler_test.exs`
- `test/eliot/logger_test.exs`

### Integration Tests

Integration tests verify that different components work together correctly. For Eliot, this includes:
- Ensuring an error handled by `ErrorHandler` is correctly logged by `Eliot.Logger`.
- Verifying the `Eliot.Application` correctly starts and supervises its children.

Sample integration test files:
- `test/eliot/integration/mqtt_integration_test.exs`

## Test Framework (ExUnit)

Eliot uses Elixir's built-in testing framework, ExUnit.

### Test Structure

Tests are defined inside modules using `use ExUnit.Case`. The `describe` block groups related tests, and each `test` block defines a single test case.

```
defmodule Eliot.MyModuleTest do
  use ExUnit.Case, async: true

  describe "my_function/2" do
    test "does something correctly" do
      assert Eliot.MyModule.my_function(:a, :b) == :ok
    end
  end
end
```

### Setup

You can use `setup` or `setup_all` blocks to run setup code before tests. `setup` runs before each test in a block, while `setup_all` runs once for the entire block.

```
defmodule Eliot.MyModuleTest do
  use ExUnit.Case, async: true

  setup do
    # This runs before each test
    {:ok, pid} = MyGenServer.start_link()
    # The returned value is passed to the test context
    %{pid: pid}
  end

  test "sends a message to the genserver", context do
    assert :ok == MyGenServer.do_something(context.pid)
  end
end
```

### Assertions

ExUnit provides various assertion macros:
- `assert some_condition == true`
- `refute some_condition == true`
- `assert_raise(MyError, fn -> ... end)`
- `assert_receive(:my_message, 100)`
- `assert_received(:my_message)`

### Mocking

For isolating components from their dependencies, we recommend using a library like [Mox](https://hex.pm/packages/mox). Mox allows you to define mock implementations of your modules' behaviors for testing.

## Writing New Tests

To create a new unit test:

1. Create a new file in the `test/eliot/` directory, ending with `_test.exs`.
2. Follow this basic structure:
```
defmodule Eliot.NewFeatureTest do
  use ExUnit.Case, async: true

  describe "new_feature_function/1" do
    test "handles valid input correctly" do
      # Given valid input
      input = "valid"
      
      # When the function is called
      result = Eliot.NewFeature.new_feature_function(input)
      
      # Then the result is correct
      assert result == :ok
    end

    test "handles invalid input with an error tuple" do
      assert Eliot.NewFeature.new_feature_function(nil) == {:error, :invalid_input}
    end
  end
end
```
3. Run `mix test` to ensure your new tests are picked up and pass.

## Test Coverage

We aim for high code coverage across the codebase.

### Measuring Coverage

You can generate a test coverage report by running:
```
mix test --cover
```
This generates a report in `cover/index.html` which you can open in your browser to see which lines of code are covered by tests.

### Coverage Requirements

- Core functionality in `Eliot`, `Eliot.ErrorHandler`, and `Eliot.Logger` should have >95% coverage.
- All public API functions must have tests.
- Error handling paths must be tested explicitly.

## Continuous Integration

Eliot uses GitHub Actions for continuous integration. The workflow runs automatically on pull requests and includes:
- Running `mix test`
- Checking formatting with `mix format --check-formatted`
- Running static analysis with `mix credo`

## Testing Best Practices

1. **Test One Thing at a Time**: Each test should verify a single, specific behavior.
2. **Use Descriptive Names**: Test names should clearly describe what is being tested.
3. **Isolate Tests**: Use `async: true` where possible to run tests concurrently and ensure they don't depend on shared state.
4. **Test the Public API**: Focus tests on the public-facing functions of your modules, not the private implementation details.
5. **Test Failure Cases**: Verify that your functions fail appropriately with invalid inputs and that your application recovers gracefully from errors.

---

<p align="center">
  <i>If you have questions about testing, please reach out via GitHub issues.</i>
</p>
