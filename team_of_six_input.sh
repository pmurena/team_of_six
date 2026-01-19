#!/bin/zsh

# --- Context Setup ---
# Ensure we know the Real User for file operations
if [ -z "$REAL_USER" ]; then
    # Fallback: Assume the owner of the current directory is the target user
    REAL_USER=$(ls -ld . | awk '{print $3}')
fi

echo "🔧 Scaffolding Project Structure (User: $REAL_USER)..."

# 1. Create Directories and Modules
# We use sudo -u $REAL_USER to ensure files are owned by the Architect, not the Ghost.
sudo -u "$REAL_USER" mkdir -p src tests
sudo -u "$REAL_USER" touch src/__init__.py
# Create empty module to allow import (even if empty) to refine the failure to logic errors
sudo -u "$REAL_USER" touch src/calculator.py

# 2. Write Failing Test (Red Stage)
# We expect these tests to fail because calculator.py is empty/unimplemented.
echo "📝 Writing Test Suite to tests/test_calculator.py..."
sudo -u "$REAL_USER" tee tests/test_calculator.py > /dev/null << 'EOF'
import pytest
from src import calculator

def test_add():
    assert calculator.add(1, 2) == 3

def test_subtract():
    assert calculator.subtract(5, 3) == 2

def test_multiply():
    assert calculator.multiply(2, 3) == 6

def test_divide():
    assert calculator.divide(10, 2) == 5.0

def test_divide_by_zero():
    with pytest.raises(ValueError):
        calculator.divide(10, 0)
EOF

# 3. Execution (Test Runner)
echo "🔥 Running Tests (Expect Failure)..."
# Using the wrapper's pytest alias (which handles the sudo tunnel)
pytest tests/test_calculator.py || echo "✅ Tests failed as expected (Red Cycle Complete)."
