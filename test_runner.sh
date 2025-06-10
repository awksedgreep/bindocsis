#!/bin/bash

# Bindocsis Test Runner
# Provides convenient commands for running different test suites

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to show usage
show_usage() {
    echo -e "${BLUE}Bindocsis Test Runner${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  quick         Run quick tests (default, excludes CLI and comprehensive fixtures)"
    echo "  cli           Run CLI tests only"
    echo "  comprehensive Run comprehensive fixture tests only"
    echo "  integration   Run integration tests (includes CLI)"
    echo "  performance   Run performance tests only"
    echo "  full          Run all tests (CLI + comprehensive fixtures + performance)"
    echo "  unit          Run unit tests only"
    echo "  coverage      Run tests with coverage report"
    echo "  watch         Run tests in watch mode"
    echo "  help          Show this help message"
    echo ""
    echo "Options:"
    echo "  --verbose     Show verbose output"
    echo "  --seed SEED   Use specific random seed"
    echo "  --maxcases N  Set maximum concurrent test cases"
    echo ""
    echo "Examples:"
    echo "  $0 quick                  # Fast development feedback"
    echo "  $0 cli --verbose          # Debug CLI issues"
    echo "  $0 performance            # Run performance benchmarks"
    echo "  $0 full --coverage        # Complete test run with coverage"
    echo "  $0 unit --seed 12345      # Reproducible unit test run"
}

# Parse options
VERBOSE=""
SEED=""
MAXCASES=""
COVERAGE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE="--trace"
            shift
            ;;
        --seed)
            SEED="--seed $2"
            shift 2
            ;;
        --maxcases)
            MAXCASES="--max-cases $2"
            shift 2
            ;;
        --coverage)
            COVERAGE="--cover"
            shift
            ;;
        *)
            COMMAND="$1"
            shift
            ;;
    esac
done

# Default command
COMMAND=${COMMAND:-quick}

# Build base mix test command
BASE_CMD="mix test $VERBOSE $SEED $MAXCASES $COVERAGE"

# Execute based on command
case $COMMAND in
    quick|q)
        print_header "Running Quick Tests (excludes CLI and comprehensive fixtures)"
        print_warning "This excludes slower CLI and comprehensive fixture tests"
        echo "Command: $BASE_CMD"
        echo ""
        eval $BASE_CMD
        print_success "Quick tests completed!"
        ;;
    
    cli)
        print_header "Running CLI Tests Only"
        print_warning "This runs integration tests for command-line interface"
        echo "Command: $BASE_CMD --include cli --exclude comprehensive_fixtures"
        echo ""
        eval "$BASE_CMD --include cli --exclude comprehensive_fixtures"
        print_success "CLI tests completed!"
        ;;
    
    comprehensive|comp)
        print_header "Running Comprehensive Fixture Tests"
        print_warning "This may take longer due to extensive fixture coverage"
        echo "Command: $BASE_CMD --include comprehensive_fixtures --exclude cli"
        echo ""
        eval "$BASE_CMD --include comprehensive_fixtures --exclude cli"
        print_success "Comprehensive fixture tests completed!"
        ;;
    
    integration|int)
        print_header "Running Integration Tests (includes CLI)"
        echo "Command: $BASE_CMD --include cli --exclude comprehensive_fixtures --exclude performance"
        echo ""
        eval "$BASE_CMD --include cli --exclude comprehensive_fixtures --exclude performance"
        print_success "Integration tests completed!"
        ;;
    
    performance|perf)
        print_header "Running Performance Tests"
        print_warning "This runs performance benchmarks and may take longer"
        echo "Command: $BASE_CMD --include performance --exclude cli --exclude comprehensive_fixtures"
        echo ""
        eval "$BASE_CMD --include performance --exclude cli --exclude comprehensive_fixtures"
        print_success "Performance tests completed!"
        ;;
    
    full|all)
        print_header "Running Full Test Suite"
        print_warning "This includes ALL tests and may take several minutes"
        echo "Command: $BASE_CMD --include cli --include comprehensive_fixtures --include performance"
        echo ""
        eval "$BASE_CMD --include cli --include comprehensive_fixtures --include performance"
        print_success "Full test suite completed!"
        ;;
    
    unit|u)
        print_header "Running Unit Tests Only"
        echo "Command: $BASE_CMD test/unit/"
        echo ""
        eval "$BASE_CMD test/unit/"
        print_success "Unit tests completed!"
        ;;
    
    coverage|cov)
        print_header "Running Tests with Coverage Report"
        print_warning "Running all tests with coverage analysis"
        echo "Command: $BASE_CMD --cover --include cli --include comprehensive_fixtures --include performance"
        echo ""
        eval "$BASE_CMD --cover --include cli --include comprehensive_fixtures --include performance"
        print_success "Coverage report generated!"
        echo ""
        echo "Coverage report available at: cover/excoveralls.html"
        ;;
    
    watch|w)
        print_header "Running Tests in Watch Mode"
        print_warning "Tests will re-run automatically when files change"
        echo "Command: mix test.watch"
        echo ""
        if command -v mix test.watch &> /dev/null; then
            mix test.watch
        else
            print_error "mix test.watch not available. Install with: mix archive.install hex mix_test_watch"
            exit 1
        fi
        ;;
    
    help|h|--help|-h)
        show_usage
        ;;
    
    *)
        print_error "Unknown command: $COMMAND"
        echo ""
        show_usage
        exit 1
        ;;
esac