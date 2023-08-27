from __future__ import annotations

import logging
import openai

logger = logging.getLogger(__name__)

class AI:
    def __init__(self, api_key, model="gpt-3.5-turbo", **kwargs):
        """
        Initialize the AI model for conversation generation.

        Args:
            model (str): The name of the GPT model to use (default: "gpt-3.5-turbo").
            **kwargs: Additional keyword arguments for temperature and max_tokens.

        Returns:
            None
        """
        openai.api_key = kwargs.get("api_key", api_key)
        self.temperature = kwargs.get("temperature", 0.1)
        self.max_tokens = kwargs.get("max_tokens", 300)
        self.model = kwargs.get("model", model)

    def start(self, system, user):
        """
        Begin a conversation with a system message and user message.

        Args:
            system (str): The system message.
            user (str): The user message.

        Returns:
            list[dict[str, str]]: List of messages in the conversation.
        """
        messages = [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ]

        return self.next(messages)

    def fsystem(self, msg):
        """
        Format a message as a system message.

        Args:
            msg (str): The content of the message.

        Returns:
            dict[str, str]: The formatted system message.
        """
        return {"role": "system", "content": msg}

    def fuser(self, msg):
        """
        Format a message as a user message.

        Args:
            msg (str): The content of the message.

        Returns:
            dict[str, str]: The formatted user message.
        """

        return {"role": "user", "content": msg}

    def fassistant(self, msg):
        """
        Format a message as an assistant message.

        Args:
            msg (str): The content of the message.

        Returns:
            dict[str, str]: The formatted assistant message.
        """

        return {"role": "assistant", "content": msg}

    def next(self, messages: list[dict[str, str]], prompt=None):
        """
        Generate the next message in the conversation.

        Args:
            messages (list[dict[str, str]]): List of messages in the conversation.
            prompt (str, optional): An optional user prompt.

        Returns:
            list[dict[str, str]]: Updated list of messages after generating the response.
        """
        if prompt:
            messages += [{"role": "user", "content": prompt}]

        logger.debug(f"Creating a new chat completion: {messages}")
        response = openai.ChatCompletion.create(
            messages=messages,
            stream=True,
            model=self.model,
            temperature=self.temperature,
        )

        chat = []
        for chunk in response:
            delta = chunk["choices"][0]["delta"]
            msg = delta.get("content", "")
            print(msg, end="")
            chat.append(msg)
        print()
        messages += [{"role": "assistant", "content": "".join(chat)}]
        logger.debug(f"Chat completion finished: {messages}")
        return messages

    def summarize(self, prompt):
        """
        Summarize a text using a predefined summary prompt.

        Args:
            prompt (str): Text to be summarized.
            dbs (object): Database object to access pre-defined prompts.

        Returns:
            str: Summarized text.
        """
        summary_prompt = "# Summarize Task\nReformat this message to be more concise without losing any details. This is the final response so it should not mention that it is condensed or shortened in any way:"
        summarized_response = self.next(prompt, summary_prompt)
        response = summarized_response[-1]["content"]
        return response