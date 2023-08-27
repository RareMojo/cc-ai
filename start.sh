#!/bin/bash

# Check if .env file exists, if not, create a default .env file
if [ ! -f .env ]; then
  cat > .env << EOL
OPENAI_API_KEY="KEY HERE"
API_TOKEN="TOKEN HERE"
PORT=PORT HERE
MODEL_NAME="gpt-3.5-turbo"
TEMPERATURE=0.7
LOG_LEVEL="INFO"
EOL
fi

# Create a virtual environment
python3 -m venv venv

# Install requirements
venv/bin/pip install -r requirements.txt

# Launch src/main.py
venv/bin/python main.py