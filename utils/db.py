from dataclasses import dataclass
import os
from pathlib import Path
from flask import request

class DB:
    """A simple key-value store, where keys are filenames and values are file contents."""

    def __init__(self, path):
        self.path = Path(path).absolute()

        self.path.mkdir(parents=True, exist_ok=True)

    def __getitem__(self, key):
        full_path = self.path / key

        if not full_path.is_file():
            raise KeyError(key)
        with full_path.open("r", encoding="utf-8") as f:
            return f.read()

    def __delitem__(self, key):
        full_path = self.path / key
        if full_path.is_file():
            os.remove(full_path)
        else:
            raise KeyError(f"No such key: {key}")

    def __setitem__(self, key, val):
        full_path = self.path / key
        full_path.parent.mkdir(parents=True, exist_ok=True)

        if isinstance(val, str):
            full_path.write_text(val, encoding="utf-8")
        else:
            raise TypeError("val must be either a str or bytes")


@dataclass
class DBs:
    preprompts: DB
    memory: DB
    
def collectData():
    data = CCData()
    data.username = request.json.get("username", "")
    data.ainame = request.json.get("ainame", "")
    data.prompt = request.json.get("prompt", "")
    data.gameday = request.json.get("gameday", "")
    data.gametime = request.json.get("gametime", "")
    data.gameuptime = request.json.get("gameuptime", "")
    data.computerid = request.json.get("computerid", "")
    data.summarythreshold = request.json.get("summarythreshold", 600)
    conversation_id = f"{data.computerid}-{data.username}-{data.ainame}"
    data.conversation_id = conversation_id
    return data

class CCData:
    def __init__(self):
        self.conversation_id = ""
        self.username = ""
        self.ainame = ""
        self.prompt = ""
        self.gameday = ""
        self.gametime = ""
        self.gameuptime = ""
        self.computerid = ""
        self.summarythreshold = ""
        self.conversation_history = []
        
    def items(self):
        return vars(self).items()