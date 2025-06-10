# Bindocsis Installation Guide

**Complete Installation Instructions for All Platforms**

---

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Quick Start](#quick-start)
3. [Detailed Installation](#detailed-installation)
4. [Platform-Specific Instructions](#platform-specific-instructions)
5. [Development Setup](#development-setup)
6. [Docker Installation](#docker-installation)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)
9. [Upgrading](#upgrading)
10. [Uninstalling](#uninstalling)

---

## System Requirements

### Minimum Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| **Erlang/OTP** | 25.0+ | Required for Elixir runtime |
| **Elixir** | 1.15+ | Core language requirement |
| **Memory** | 512 MB RAM | For basic operations |
| **Storage** | 100 MB | For installation and dependencies |
| **OS** | Linux, macOS, Windows | Cross-platform support |

### Recommended Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| **Erlang/OTP** | 26.0+ | Latest stable version |
| **Elixir** | 1.18+ | Latest features and performance |
| **Memory** | 2 GB RAM | For large file processing |
| **Storage** | 500 MB | Including test fixtures and docs |

### Optional Dependencies

| Component | Purpose | Installation |
|-----------|---------|--------------|
| **Git** | Source code management | `sudo apt install git` (Ubuntu) |
| **jq** | JSON processing in CLI | `sudo apt install jq` (Ubuntu) |
| **yq** | YAML processing in CLI | `pip install yq` |
| **Docker** | Containerized deployment | [Docker Installation](https://docs.docker.com/get-docker/) |

---

## Quick Start

### 1. Install Elixir

**Ubuntu/Debian:**
```bash
# Add Erlang Solutions repository
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
sudo apt update

# Install Erlang and Elixir
sudo apt install esl-erlang elixir
```

**macOS (with Homebrew):**
```bash
brew install elixir
```

**Windows:**
Download and install from [Elixir website](https://elixir-lang.org/install.html#windows)

### 2. Install Bindocsis

```bash
# Clone the repository
git clone https://github.com/your-org/bindocsis.git
cd bindocsis

# Install dependencies
mix deps.get

# Compile the project
mix compile

# Build CLI executable
mix escript.build

# Verify installation
./bindocsis --version
```

### 3. Quick Test

```bash
# Test with a sample file (if available)
./bindocsis test/fixtures/basic_config.cm

# Or test with hex string
./bindocsis -i "03 01 01 FF 00 00"
```

---

## Detailed Installation

### Step 1: Install Erlang/OTP

Erlang is required as the runtime for Elixir.

#### Ubuntu/Debian
```bash
# Method 1: From Erlang Solutions (Recommended)
curl -fSL https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb -o erlang-solutions.deb
sudo dpkg -i erlang-solutions.deb
sudo apt update
sudo apt install esl-erlang

# Method 2: From Ubuntu repositories (older version)
sudo apt update
sudo apt install erlang

# Verify installation
erl -version
```

#### CentOS/RHEL/Fedora
```bash
# Method 1: From Erlang Solutions (Recommended)
curl -fSL https://packages.erlang-solutions.com/erlang-solutions-2.0-1.noarch.rpm -o erlang-solutions.rpm
sudo rpm -Uvh erlang-solutions.rpm
sudo yum install erlang

# Method 2: From EPEL
sudo yum install epel-release
sudo yum install erlang

# Verify installation
erl -version
```

#### macOS
```bash
# Using Homebrew (Recommended)
brew install erlang

# Using MacPorts
sudo port install erlang

# Verify installation
erl -version
```

#### Windows
1. Download Erlang installer from [Erlang.org](https://www.erlang.org/downloads)
2. Run the installer with administrator privileges
3. Add Erlang to your PATH if not done automatically
4. Verify in Command Prompt: `erl -version`

### Step 2: Install Elixir

#### Ubuntu/Debian
```bash
# If using Erlang Solutions repository
sudo apt install elixir

# Alternative: Using snap
sudo snap install elixir --classic

# Verify installation
elixir --version
mix --version
```

#### CentOS/RHEL/Fedora
```bash
# If using Erlang Solutions repository
sudo yum install elixir

# Verify installation
elixir --version
mix --version
```

#### macOS
```bash
# Using Homebrew (Recommended)
brew install elixir

# Using MacPorts
sudo port install elixir

# Verify installation
elixir --version
mix --version
```

#### Windows
1. Download Elixir installer from [Elixir-lang.org](https://elixir-lang.org/install.html#windows)
2. Run the installer
3. Verify in Command Prompt: `elixir --version`

### Step 3: Install Bindocsis

#### From Source (Recommended)
```bash
# Clone repository
git clone https://github.com/your-org/bindocsis.git
cd bindocsis

# Install Hex package manager (if not already installed)
mix local.hex --force

# Install rebar3 build tool (if not already installed)
mix local.rebar --force

# Install dependencies
mix deps.get

# Compile the project
mix compile

# Run tests to ensure everything works
mix test

# Build CLI executable
mix escript.build

# Make executable (Linux/macOS)
chmod +x bindocsis

# Add to PATH (optional)
sudo ln -s $(pwd)/bindocsis /usr/local/bin/bindocsis
```

#### From Hex Package (When Available)
```bash
# Install as global escript
mix escript.install hex bindocsis

# Add ~/.mix/escripts to your PATH
export PATH="$HOME/.mix/escripts:$PATH"

# Add to shell profile for persistence
echo 'export PATH="$HOME/.mix/escripts:$PATH"' >> ~/.bashrc
```

---

## Platform-Specific Instructions

### Linux (Ubuntu/Debian)

#### Complete Installation Script
```bash
#!/bin/bash
# Ubuntu/Debian installation script

set -e

echo "Installing Bindocsis on Ubuntu/Debian..."

# Update system
sudo apt update

# Install dependencies
sudo apt install -y curl wget gnupg2 software-properties-common

# Install Erlang Solutions repository
if [ ! -f /etc/apt/sources.list.d/erlang-solutions.list ]; then
    wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
    sudo dpkg -i erlang-solutions_2.0_all.deb
    sudo apt update
fi

# Install Erlang and Elixir
sudo apt install -y esl-erlang elixir

# Install Git if not present
sudo apt install -y git

# Clone and build Bindocsis
if [ ! -d "bindocsis" ]; then
    git clone https://github.com/your-org/bindocsis.git
fi

cd bindocsis

# Setup Elixir environment
mix local.hex --force
mix local.rebar --force

# Install dependencies and compile
mix deps.get
mix compile
mix test --exclude slow
mix escript.build

# Install globally
sudo ln -sf $(pwd)/bindocsis /usr/local/bin/bindocsis

echo "✅ Bindocsis installation completed!"
echo "Test with: bindocsis --version"
```

### macOS

#### Complete Installation Script
```bash
#!/bin/bash
# macOS installation script

set -e

echo "Installing Bindocsis on macOS..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Elixir (includes Erlang)
brew install elixir

# Install Git if not present
brew install git

# Clone and build Bindocsis
if [ ! -d "bindocsis" ]; then
    git clone https://github.com/your-org/bindocsis.git
fi

cd bindocsis

# Setup Elixir environment
mix local.hex --force
mix local.rebar --force

# Install dependencies and compile
mix deps.get
mix compile
mix test --exclude slow
mix escript.build

# Install globally
sudo ln -sf $(pwd)/bindocsis /usr/local/bin/bindocsis

echo "✅ Bindocsis installation completed!"
echo "Test with: bindocsis --version"
```

### Windows

#### PowerShell Installation Script
```powershell
# Windows PowerShell installation script

Write-Host "Installing Bindocsis on Windows..." -ForegroundColor Green

# Check if Chocolatey is installed
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# Install Elixir
choco install elixir -y

# Install Git
choco install git -y

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Clone and build Bindocsis
if (!(Test-Path "bindocsis")) {
    git clone https://github.com/your-org/bindocsis.git
}

Set-Location bindocsis

# Setup Elixir environment
mix local.hex --force
mix local.rebar --force

# Install dependencies and compile
mix deps.get
mix compile
mix test --exclude slow
mix escript.build

Write-Host "✅ Bindocsis installation completed!" -ForegroundColor Green
Write-Host "Test with: .\bindocsis --version" -ForegroundColor Cyan
```

### CentOS/RHEL

#### Installation Script
```bash
#!/bin/bash
# CentOS/RHEL installation script

set -e

echo "Installing Bindocsis on CentOS/RHEL..."

# Install EPEL repository
sudo yum install -y epel-release

# Install dependencies
sudo yum install -y curl wget git

# Install Erlang Solutions repository
if [ ! -f /etc/yum.repos.d/erlang-solutions.repo ]; then
    curl -fSL https://packages.erlang-solutions.com/erlang-solutions-2.0-1.noarch.rpm -o erlang-solutions.rpm
    sudo rpm -Uvh erlang-solutions.rpm
fi

# Install Erlang and Elixir
sudo yum install -y erlang elixir

# Continue with standard installation...
# (Same as Ubuntu script from here)
```

---

## Development Setup

### For Contributors

```bash
# Clone with development branches
git clone --recurse-submodules https://github.com/your-org/bindocsis.git
cd bindocsis

# Install development dependencies
mix deps.get

# Install development tools
mix archive.install hex ex_doc
mix archive.install hex credo
mix archive.install hex dialyxir

# Setup pre-commit hooks
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Run full test suite
mix test

# Run code quality checks
mix format --check-formatted
mix credo
mix dialyzer

# Generate documentation
mix docs

# Build release
MIX_ENV=prod mix compile
MIX_ENV=prod mix escript.build
```

### Editor Setup

#### VS Code
```bash
# Install Elixir extension
code --install-extension jakebecker.elixir-ls

# Open project
code .
```

#### Vim/Neovim
```bash
# Install vim-elixir plugin
# Add to your .vimrc:
# Plug 'elixir-editors/vim-elixir'
```

#### Emacs
```bash
# Install alchemist.el
# Add to your init.el:
# (package-install 'alchemist)
```

---

## Docker Installation

### Using Pre-built Image (When Available)

```bash
# Pull official image
docker pull bindocsis/bindocsis:latest

# Run with volume mount
docker run -v $(pwd):/workspace bindocsis/bindocsis config.cm

# Create alias for convenience
alias bindocsis='docker run -v $(pwd):/workspace bindocsis/bindocsis'
```

### Building from Source

```dockerfile
# Dockerfile
FROM elixir:1.18-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git

# Copy source
COPY . .

# Build application
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    MIX_ENV=prod mix compile && \
    MIX_ENV=prod mix escript.build

FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache ncurses-libs libstdc++

# Copy binary
COPY --from=builder /app/bindocsis /usr/local/bin/bindocsis

WORKDIR /workspace
ENTRYPOINT ["bindocsis"]
```

```bash
# Build image
docker build -t bindocsis .

# Run
docker run -v $(pwd):/workspace bindocsis config.cm
```

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  bindocsis:
    build: .
    volumes:
      - ./configs:/workspace
    command: ["--help"]
```

---

## Verification

### Basic Verification

```bash
# Check versions
elixir --version
mix --version
bindocsis --version

# Test basic functionality
echo "03 01 01 FF 00 00" | bindocsis -i -

# Test file parsing (if test files available)
bindocsis test/fixtures/basic_config.cm 2>/dev/null && echo "✅ File parsing works"

# Test format conversion
echo '{"tlvs":[{"type":3,"length":1,"value":"01"}]}' | \
  bindocsis -f json -t pretty 2>/dev/null && echo "✅ Format conversion works"
```

### Comprehensive Testing

```bash
# Run test suite
mix test

# Test CLI functionality
./scripts/test-cli.sh

# Performance test
./scripts/benchmark.sh

# Memory usage test
./scripts/memory-test.sh
```

### Integration Testing

```bash
# Test with real DOCSIS files
for file in test/fixtures/*.cm; do
  echo "Testing $file..."
  bindocsis "$file" > /dev/null && echo "✅ $file" || echo "❌ $file"
done

# Test format round-trip
bindocsis test/fixtures/basic.cm -t json | \
  bindocsis -f json -t yaml | \
  bindocsis -f yaml -t binary > test_output.cm

# Compare with original
cmp test/fixtures/basic.cm test_output.cm && echo "✅ Round-trip successful"
```

---

## Troubleshooting

### Common Issues

#### Issue: "mix: command not found"

**Problem:** Elixir not installed or not in PATH

**Solution:**
```bash
# Check if Elixir is installed
which elixir

# If not found, reinstall Elixir
# Ubuntu/Debian:
sudo apt install elixir

# macOS:
brew install elixir

# Add to PATH if needed
export PATH="/usr/local/bin:$PATH"
```

#### Issue: "Could not compile dependency..."

**Problem:** Missing build tools or outdated dependencies

**Solution:**
```bash
# Clean and reinstall dependencies
mix deps.clean --all
mix deps.get
mix deps.compile

# If still failing, check Erlang/Elixir versions
elixir --version
```

#### Issue: "Permission denied" when building escript

**Problem:** No write permissions or Windows execution policy

**Solution:**
```bash
# Linux/macOS: Check permissions
ls -la
chmod +x bindocsis

# Windows: Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Issue: "Memory allocation failed"

**Problem:** Insufficient memory for large files

**Solution:**
```bash
# Increase Erlang memory
export ERL_MAX_MEMORY=2048m

# Or use streaming mode (if available)
bindocsis large_file.cm --stream-mode
```

#### Issue: Dependency compilation errors

**Problem:** Missing system dependencies

**Solution:**
```bash
# Ubuntu/Debian: Install build essentials
sudo apt install build-essential

# CentOS/RHEL: Install development tools
sudo yum groupinstall "Development Tools"

# macOS: Install Xcode command line tools
xcode-select --install
```

### Debug Mode

Enable debug output for troubleshooting:

```bash
# Enable debug logging
export BINDOCSIS_LOG_LEVEL=debug

# Run with verbose output
bindocsis config.cm --verbose

# Check mix dependencies
mix deps.tree

# Check for compilation warnings
mix compile --warnings-as-errors
```

### Getting Help

If you encounter issues not covered here:

1. **Check the logs:**
   ```bash
   tail -f ~/.bindocsis/logs/error.log
   ```

2. **Search existing issues:**
   Visit [GitHub Issues](https://github.com/your-org/bindocsis/issues)

3. **Create a new issue:**
   Include:
   - Operating system and version
   - Elixir version (`elixir --version`)
   - Error messages
   - Steps to reproduce

4. **Join the community:**
   - GitHub Discussions
   - Community Slack/Discord

---

## Upgrading

### From Source

```bash
cd bindocsis

# Backup current version
cp bindocsis bindocsis.backup

# Pull latest changes
git pull origin main

# Update dependencies
mix deps.get
mix deps.compile

# Rebuild
mix compile
mix escript.build

# Test new version
./bindocsis --version
```

### From Hex (When Available)

```bash
# Update to latest version
mix escript.install hex bindocsis --force

# Or update all escripts
mix escript.install hex --force
```

### Version Compatibility

When upgrading, check for breaking changes:

```bash
# Check changelog
cat CHANGELOG.md

# Test with your configurations
bindocsis validate your_config.cm

# Check for deprecated features
grep -i deprecated docs/CHANGELOG.md
```

---

## Uninstalling

### Remove Bindocsis

```bash
# Remove global symlink
sudo rm -f /usr/local/bin/bindocsis

# Remove source directory
rm -rf bindocsis

# Remove escript (if installed via Hex)
mix escript.uninstall bindocsis

# Remove config directory (optional)
rm -rf ~/.bindocsis
```

### Remove Elixir (Optional)

```bash
# Ubuntu/Debian
sudo apt remove elixir esl-erlang

# macOS
brew uninstall elixir erlang

# Windows
# Use Control Panel -> Programs and Features
```

---

## Additional Resources

### Documentation
- [User Guide](USER_GUIDE.md)
- [CLI Reference](CLI_REFERENCE.md)
- [API Reference](API_REFERENCE.md)
- [Examples](EXAMPLES.md)

### Community
- [GitHub Repository](https://github.com/your-org/bindocsis)
- [Issue Tracker](https://github.com/your-org/bindocsis/issues)
- [Discussions](https://github.com/your-org/bindocsis/discussions)

### Support
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [FAQ](FAQ.md)
- Email: support@bindocsis.com

---

**Installation Complete!** 🎉

You now have Bindocsis installed and ready to use. Try these next steps:

1. **Quick test:** `bindocsis --version`
2. **Parse a file:** `bindocsis test/fixtures/basic.cm`
3. **Read the user guide:** [USER_GUIDE.md](USER_GUIDE.md)
4. **Explore examples:** [EXAMPLES.md](EXAMPLES.md)

*For the most up-to-date installation instructions, always refer to the latest documentation on GitHub.*