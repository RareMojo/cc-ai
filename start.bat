@echo off

REM Check if .env file exists, if not, create a default .env file
if not exist .env (
  (
  echo OPENAI_API_KEY="KEY HERE"
  echo API_TOKEN="TOKEN HERE"
  echo PORT=PORT HERE
  echo MODEL_NAME="gpt-3.5-turbo"
  echo TEMPERATURE=0.7
  echo LOG_LEVEL="INFO"
  ) > .env
)

REM Create a virtual environment
python -m venv venv

REM Activate the virtual environment
call venv\Scripts\activate

REM Update pip
python -m pip install --upgrade pip

REM Install requirements
pip install -r requirements.txt

REM Launch src/main.py
python main.py

REM Deactivate the virtual environment
call venv\Scripts\deactivate.bat