# -*- coding: utf-8 -*-
"""
工作流 API 调用工具 - UTF-8 安全
用法:
  python api_call.py submit_questions <step> <step_name> <questions_json_file>
  python api_call.py update_status <step> <step_name> <status> <total_steps>
  python api_call.py log <message> [type]
  python api_call.py wait_answers [timeout]
  python api_call.py get_request
  python api_call.py get_answers

避免 PowerShell 5 的中文编码问题，所有请求用 UTF-8 编码。
"""
import json
import sys
import urllib.request
import time

BASE = "http://localhost:8765"


def post_json(path, data):
    body = json.dumps(data, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        BASE + path,
        data=body,
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))


def get_json(path):
    with urllib.request.urlopen(BASE + path) as resp:
        return json.loads(resp.read().decode("utf-8"))


def submit_questions(step, step_name, questions_file):
    with open(questions_file, "r", encoding="utf-8") as f:
        questions = json.load(f)
    result = post_json("/api/questions", {
        "step": int(step),
        "step_name": step_name,
        "questions": questions,
    })
    print(json.dumps(result, ensure_ascii=False, indent=2))


def update_status(step, step_name, status, total_steps=6):
    result = post_json("/api/status", {
        "step": int(step),
        "step_name": step_name,
        "status": status,
        "total_steps": int(total_steps),
    })
    print(json.dumps(result, ensure_ascii=False, indent=2))


def log(message, log_type="info"):
    result = post_json("/api/log", {
        "type": log_type,
        "message": message,
    })
    print(json.dumps(result, ensure_ascii=False, indent=2))


def wait_answers(timeout=300):
    result = get_json(f"/api/wait_answers?timeout={timeout}")
    print(json.dumps(result, ensure_ascii=False, indent=2))


def get_request():
    result = get_json("/api/request")
    print(json.dumps(result, ensure_ascii=False, indent=2))


def get_answers():
    result = get_json("/api/questions")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "submit_questions":
        submit_questions(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "update_status":
        update_status(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5] if len(sys.argv) > 5 else "6")
    elif cmd == "log":
        log(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "info")
    elif cmd == "wait_answers":
        wait_answers(int(sys.argv[2]) if len(sys.argv) > 2 else 300)
    elif cmd == "get_request":
        get_request()
    elif cmd == "get_answers":
        get_answers()
    else:
        print(f"Unknown command: {cmd}")
        print(__doc__)
        sys.exit(1)
