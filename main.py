import json
import logging
import os
from pathlib import Path
from threading import Lock

from dotenv import load_dotenv
from flask import Flask, jsonify
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

from utils.ai import AI
from utils.db import DB, DBs, collectData
from utils.tools import system_template, setup_sys_prompt, authorizeToken

load_dotenv()
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
API_TOKEN = os.getenv("API_TOKEN")
MODEL_NAME = os.getenv("MODEL_NAME")
TEMPERATURE = float(os.getenv("TEMPERATURE"))
PORT = int(os.getenv("PORT"))
LOG_LEVEL = os.getenv("LOG_LEVEL")

logging.basicConfig(level=LOG_LEVEL)

root_path = Path(os.path.curdir).absolute()
memory_path = root_path / "memory"
preprompts_path = root_path / "preprompts"

ai = AI(
    api_key=OPENAI_API_KEY,
    model=MODEL_NAME,
    temperature=TEMPERATURE
)

dbs = DBs(
    memory=DB(path=memory_path),
    preprompts=DB(path=preprompts_path),
)

memory_lock = Lock()

app = Flask(__name__)

limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)


@app.route('/conversation', methods=['POST'])
@limiter.limit("8 per minute")
def chat_bot():
    """
    Handle the conversation endpoint to interact with the chatbot.

    This function receives a POST request containing conversation data.
    It loads or initializes the conversation history and generates a response
    using the AI model. The conversation history is saved for future interactions.

    Returns:
        JSON response containing the generated AI response and status information.
    """
    logging.info("Received POST request for 'conversation'.")
    authorizeToken(API_TOKEN)
    data = collectData()
    user_prompt = data.prompt
    conversation = data.conversation_id
    summary_threshold = data.summarythreshold

    try:
        conversation_history = json.loads(dbs.memory[data.conversation_id])
        logging.info(
            f"Loaded conversation history for conversation_id: {conversation}")
    except KeyError:
        logging.warning(
            f"No conversation history found for conversation_id: {conversation}")
        conversation_history = []
        

    system_prompt = setup_sys_prompt(data, dbs)

    if not conversation_history:
        conversation_history.append(ai.fsystem(system_prompt))
        response = ai.start(system_prompt, system_template(data))
        logging.info(
            f"Started new conversation with conversation_id: {conversation}")
    else:
        conversation_history[0] = ai.fsystem(system_prompt)
        response = ai.next(conversation_history[1:], system_template(data))
        logging.info(
            f"Continuing existing conversation with conversation_id: {conversation}")

    ai_response = response[-1]["content"]

    conversation_history.append(ai.fuser(user_prompt))
    conversation_history.append(ai.fsystem(conversation))

    summarized = False
    
    if len(ai_response) > int(summary_threshold):
        ai_response = ai.summarize(ai_response)
        summarized = True
        logging.info(
            f"Response summarized for conversation_id: {conversation}")

    dbs.memory[data.conversation_id] = json.dumps(
        [conversation_history[0]] + conversation_history[-9:])
    logging.info(
        f"Saved conversation history for conversation_id: {conversation}")

    return jsonify(status="success", message=ai_response, summarized=summarized)


@app.route('/clear_conversation', methods=['POST'])
@limiter.limit("8 per minute")
def wipe_memory():
    """
    Handle the clear_conversation endpoint to clear conversation memory.

    This function receives a POST request to clear the memory associated with
    a conversation. It locks access to the memory and clears the stored history.

    Returns:
        JSON response indicating success or error in clearing the memory.
    """
    authorizeToken(API_TOKEN)
    data = collectData()
    conversation = data.conversation_id

    logging.info(
        f"Attempting to clear memory for conversation_id: {conversation}")
    
    with memory_lock:
        try:
            with open(dbs.memory.path / conversation, "w") as f:
                f.write("[]")
            logging.info(
                f"Successfully cleared memory for conversation_id: {conversation}")
            return jsonify(status="success", message="Memory cleared.")
        except KeyError:
            logging.warning(
                f"Failed to clear memory for conversation_id: {conversation}")
            return jsonify(status="error", message="No memory to clear.")


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=PORT)
