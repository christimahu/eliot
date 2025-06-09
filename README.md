# Eliot - IoT Data Ingestion System

> *"Hello, friend. Welcome to the world of connected devices."*

Eliot is a production-ready IoT data ingestion system built with Elixir/OTP, designed for high-throughput sensor data processing and real-time fleet management. Born from the need to handle massive scale device communication with fault-tolerance and observability at its core.

## 🤖 Features

- **Real-time MQTT Communication** - Handle thousands of concurrent device connections
- **Fault-Tolerant Architecture** - Supervisor trees that never sleep, built to survive any crash
- **Structured Logging** - Every event tracked, every anomaly detected
- **Circuit Breaker Patterns** - Automatic recovery from network failures
- **Environment-Specific Configuration** - Seamless deployment from development to production
- **Comprehensive Test Suite** - High coverage with integration tests covering error scenarios and edge cases
- **Clean Code Quality** - Idiomatic Elixir following industry best practices

## 🏗️ Architecture

Eliot follows the **"let it crash"** philosophy - embrace failure, isolate it, and recover gracefully. The system is built around an OTP application with isolated supervision trees for maximum resilience.

```
┌─────────────────────────────────────────────────────────────┐
│                    Eliot Supervisor                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ Error Handler   │  │ Message Parser  │  │ Logger       │ │
│  │ (Retry Logic)   │  │ (JSON Processing)│  │ (Telemetry)  │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

The architecture demonstrates understanding of:
- **Distributed Systems** - Handle network partitions and node failures
- **Event-Driven Design** - React to device events in real-time  
- **Observability** - Full system visibility through structured logging
- **Scalability** - Process millions of messages without breaking a sweat

## 🚀 Quick Start

### Prerequisites

- **Elixir 1.14+** - [Install Elixir](https://elixir-lang.org/install.html)
- **Erlang/OTP 25+** - [Erlang Downloads](https://www.erlang.org/downloads)
- **Git** - [Install Git](https://git-scm.com/downloads)
- **MQTT Broker** (optional for development) - [Eclipse Mosquitto](https://mosquitto.org/)

### Installation

```bash
# Clone the repository
git clone https://github.com/christimahu/eliot.git
cd eliot

# Install dependencies
mix deps.get

# Run tests to verify everything works
mix test

# Start the application
mix run --no-halt
```

### Development

```bash
# Run with interactive shell
iex -S mix

# Run linting (if configured)
mix credo

# Format code
mix format

# Build production release
MIX_ENV=prod mix release
```

### Learning Resources

- **[Elixir Official Guide](https://elixir-lang.org/getting-started/introduction.html)** - Learn Elixir fundamentals
- **[OTP Design Principles](https://www.erlang.org/doc/design_principles/users_guide.html)** - Understanding supervision trees
- **[MQTT Protocol](https://mqtt.org/)** - IoT messaging protocol documentation
- **[Phoenix Framework](https://phoenixframework.org/)** - If adding web interfaces
- **[Nerves Project](https://nerves-project.org/)** - For embedded IoT devices

## 🔧 Configuration

Eliot supports environment-specific configuration:

```elixir
# config/prod.exs
config :eliot,
  mqtt: [
    broker_host: System.get_env("MQTT_BROKER_HOST"),
    broker_port: 8883,
    ssl: true,
    keepalive: 300
  ]
```

### Environment Variables

- `MQTT_BROKER_HOST` - Production MQTT broker hostname
- `MQTT_USERNAME` - Authentication username  
- `MQTT_PASSWORD` - Authentication password
- `MQTT_CLIENT_CERT_FILE` - Client certificate for mutual TLS

## 📊 Message Format

All device messages follow a standardized JSON schema:

```json
{
  "device_id": "robot_001",
  "timestamp": "2025-06-05T14:30:00Z", 
  "sensor_type": "gps",
  "data": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "accuracy": 3.2
  }
}
```

## 🛡️ Error Handling

Eliot implements sophisticated error handling patterns:

- **Exponential Backoff** - Automatic retry with increasing delays
- **Circuit Breakers** - Fail fast when services are down
- **Dead Letter Queues** - Preserve unprocessable messages for analysis
- **Graceful Degradation** - Continue operating with reduced functionality

```elixir
# Example: Device connection timeout handling
{:retry, %{device_id: "robot_001", backoff_ms: 2000}}

# Example: Authentication failure handling  
{:circuit_break, %{device_id: "robot_002", reason: :auth_failure}}
```

## 📈 Monitoring & Observability

Every operation generates structured logs for production monitoring:

```elixir
# Device connection events
Eliot.Logger.log_device_event("robot_001", :connected)

# Message processing metrics
Eliot.Logger.log_processing_event("message_123", 150, :ok)

# Security events
Eliot.Logger.log_error("Authentication failure", %{device_id: "unknown", reason: :auth_failure})
```

## 🧪 Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run integration tests only
mix test test/eliot/integration/

# Run tests excluding integration tests
mix test --exclude integration
```

The test suite covers:
- **Unit Tests** - Individual module functionality
- **Integration Tests** - MQTT connection lifecycle
- **Error Scenarios** - Network failures and malformed data
- **Configuration Validation** - Environment-specific settings

See [TESTING.md](TESTING.md) for detailed testing documentation.

## 🏭 Production Deployment

### Building a Release

```bash
# Create production release
MIX_ENV=prod mix release

# Run the release
_build/prod/rel/eliot/bin/eliot start
```

### Docker Deployment

```dockerfile
FROM elixir:1.14-alpine
WORKDIR /app
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
COPY . .
RUN MIX_ENV=prod mix release
CMD ["_build/prod/rel/eliot/bin/eliot", "start"]
```

## 🤝 Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md):

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-capability`
3. Write tests for your changes
4. Ensure all tests pass: `mix test`
5. Run linting: `mix credo` (if configured)
6. Submit a pull request

## 📋 Requirements Checklist

- [x] Production-ready error handling
- [x] Comprehensive test coverage with integration tests
- [x] Environment-specific configuration
- [x] Structured logging for observability
- [x] Circuit breaker patterns
- [x] MQTT protocol support
- [x] Clean code quality
- [x] Documentation with examples
- [x] Graceful shutdown handling

## 🏆 Quality Metrics

```
Tests:     Comprehensive unit and integration test coverage
Coverage:  High coverage of critical paths
Credo:     Clean code following Elixir best practices
Format:    All code properly formatted
Docs:      Comprehensive with examples
```

## 🔮 Roadmap

- **Phase 1**: Core MQTT workers and message processing (Current)
- **Phase 2**: HTTP API for fleet management
- **Phase 3**: Real-time dashboards and alerting
- **Phase 4**: Machine learning anomaly detection
- **Phase 5**: Multi-region deployment and edge computing

## 📚 Documentation

- **Testing**: See [TESTING.md](TESTING.md) for detailed testing information
- **Changes**: See [CHANGELOG.md](CHANGELOG.md) for version history
- **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

---

*"The world is a dangerous place, not because of those who do evil, but because of those who look on and do nothing. Eliot watches, processes, and acts."*

Built with ❤️ and lots of ☕ for the IoT revolution.
