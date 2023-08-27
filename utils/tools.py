from flask import request, abort

def system_template(data):
    """
    Generate a formatted template for the user prompt.

    Args:
        data (object): Data containing information about the conversation.

    Returns:
        str: Formatted template including important hidden details.
    """
    prompt = f"""# IMPORTANT HIDDEN DETAILS\n
                Your name is: {data.ainame}. 
                You are speaking to: {data.username}. 
                The game time and day is: {data.gameday} at {data.gametime}. 
                The game uptime is {data.gameuptime}. 
                Now, the user says: {data.prompt}"""
    return prompt


def setup_sys_prompt(data, dbs):
    """
    Set up the system prompt using pre-defined template and data.

    Args:
        data (object): Data containing information about the conversation.
        dbs (object): Database object to access pre-defined prompts.

    Returns:
        str: Formatted system message with placeholders replaced by data values.
    """
    system_message = dbs.preprompts["system"]
    for key, value in data.items():
        system_message = system_message.replace(
            f"{{{key.upper()}}}", str(value))
    return system_message


def authorize_token(api_token):
    received_token = request.headers.get("Authorization", "").split(" ")[-1]
    if received_token != api_token:
        abort(401, "You are not authorized. Please provide a valid API token.")
