# --- V55 INPUT SCRIPT (Standard Shell) ---
# Context: Scaffolding
# Target: python_calculator
# Mode: Direct Write (User Permissions Verified)

# 1. Create Directory Structure
# Direct execution as 'team_of_six' (Write Access Confirmed)
mkdir -p python_calculator/src
mkdir -p python_calculator/tests
mkdir -p python_calculator/.tos

# 2. Initialize State & Config
cat <<EOF > python_calculator/README.md
# Python Calculator

A simple, atomic library for basic arithmetic.
EOF

echo "pytest" > python_calculator/requirements.txt

# 2a. Team of Six State (Setting to RED)
cat <<EOF > python_calculator/.tos/features.md
# Features
* [ ] Basic Calculator (Current)
EOF

echo "Red" > python_calculator/.tos/state
touch python_calculator/.tos/objections.md

# 3. Version Control
# Executes as REAL_USER via tos_wrapper.sh aliases
cd python_calculator
git init
git add .
git commit -m "chore: project scaffold (Team of Six V55)"
