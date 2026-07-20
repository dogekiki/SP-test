"""
自动化开发工作流 - 交互服务器 v3
批量问答模式: TRAE 一次提交多个问题, 用户批量回答, 对话驱动推进
启动: python server.py
端口: 8765
"""

import json
import time
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
import os
import webbrowser

PORT = 8765
UI_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ui.html")

# 全局状态
state = {
    "request": None,          # 用户提交的需求
    "batch_id": 0,            # 当前批次ID(每次提交新问题递增)
    "questions": [],          # 当前批次的问题列表
    "answers": {},            # 当前批次的回答 {question_id: answer}
    "batch_ready": False,     # 当前批次是否所有问题已回答
    "status": {
        "step": 0,
        "total_steps": 6,
        "step_name": "等待需求",
        "status": "idle"
    },
    "logs": [],
    "history": []             # 所有批次的历史记录
}
state_lock = threading.Lock()


class WorkflowHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def _send_json(self, data, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))

    def _send_html(self, html):
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(html.encode("utf-8"))

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        body = self.rfile.read(length).decode("utf-8")
        try:
            return json.loads(body)
        except json.JSONDecodeError:
            return {}

    def do_OPTIONS(self):
        self._send_json({"ok": True})

    def do_GET(self):
        path = urlparse(self.path).path

        if path == "/" or path == "/index.html":
            try:
                with open(UI_FILE, "r", encoding="utf-8") as f:
                    self._send_html(f.read())
            except FileNotFoundError:
                self._send_html("<h1>ui.html not found</h1>")
            return

        if path == "/api/request":
            with state_lock:
                r = state["request"]
            if r:
                self._send_json({"has_request": True, "request": r["text"], "timestamp": r["timestamp"]})
            else:
                self._send_json({"has_request": False})
            return

        if path == "/api/questions":
            with state_lock:
                self._send_json({
                    "batch_id": state["batch_id"],
                    "questions": list(state["questions"]),
                    "batch_ready": state["batch_ready"]
                })
            return

        if path == "/api/answers":
            with state_lock:
                self._send_json({
                    "batch_id": state["batch_id"],
                    "answers": dict(state["answers"]),
                    "batch_ready": state["batch_ready"]
                })
            return

        if path == "/api/status":
            with state_lock:
                s = dict(state["status"])
            self._send_json(s)
            return

        if path == "/api/logs":
            with state_lock:
                logs = list(state["logs"])
            self._send_json({"logs": logs})
            return

        if path == "/api/history":
            with state_lock:
                history = list(state["history"])
            self._send_json({"history": history})
            return

        self._send_json({"error": "not found"}, 404)

    def do_POST(self):
        path = urlparse(self.path).path
        body = self._read_body()

        if path == "/api/request":
            req_text = body.get("request", "")
            with state_lock:
                state["request"] = {
                    "text": req_text,
                    "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
                }
            self._send_json({"ok": True})
            return

        if path == "/api/questions":
            # TRAE 提交一批问题
            questions = body.get("questions", [])
            step = body.get("step", 0)
            step_name = body.get("step_name", "")
            with state_lock:
                state["batch_id"] += 1
                state["questions"] = []
                state["answers"] = {}
                state["batch_ready"] = False
                for i, q in enumerate(questions):
                    state["questions"].append({
                        "id": i,
                        "step": step,
                        "step_name": step_name,
                        "batch_id": state["batch_id"],
                        "question_type": q.get("question_type", "text"),
                        "question": q.get("question", ""),
                        "options": q.get("options", []),
                        "allow_custom": q.get("allow_custom", False)
                    })
            self._send_json({"ok": True, "batch_id": state["batch_id"], "count": len(questions)})
            return

        if path == "/api/answer":
            # 用户回答单个问题
            qid = body.get("question_id", -1)
            answer = body.get("answer", "")
            with state_lock:
                state["answers"][str(qid)] = answer
                # 检查是否所有问题都已回答
                total = len(state["questions"])
                answered = len(state["answers"])
                was_ready = state["batch_ready"]
                state["batch_ready"] = answered >= total and total > 0
                # 只在首次变为 ready 时记录历史，避免重复
                if state["batch_ready"] and not was_ready:
                    for q in state["questions"]:
                        state["history"].append({
                            "batch_id": state["batch_id"],
                            "step_name": q["step_name"],
                            "question": q["question"],
                            "answer": state["answers"].get(str(q["id"]), "")
                        })
            self._send_json({"ok": True, "batch_ready": state["batch_ready"]})
            return

        if path == "/api/status":
            with state_lock:
                state["status"] = {
                    "step": body.get("step", 0),
                    "total_steps": body.get("total_steps", 6),
                    "step_name": body.get("step_name", ""),
                    "status": body.get("status", "in_progress")
                }
            self._send_json({"ok": True})
            return

        if path == "/api/log":
            entry = {
                "type": body.get("type", "info"),
                "message": body.get("message", ""),
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
            }
            with state_lock:
                state["logs"].append(entry)
                if len(state["logs"]) > 200:
                    state["logs"] = state["logs"][-200:]
            self._send_json({"ok": True})
            return

        if path == "/api/reset":
            with state_lock:
                state["request"] = None
                state["batch_id"] = 0
                state["questions"] = []
                state["answers"] = {}
                state["batch_ready"] = False
                state["status"] = {
                    "step": 0, "total_steps": 6,
                    "step_name": "已重置", "status": "idle"
                }
                state["logs"] = []
                state["history"] = []
            self._send_json({"ok": True})
            return

        self._send_json({"error": "not found"}, 404)


def open_browser():
    time.sleep(1)
    webbrowser.open(f"http://localhost:{PORT}")


def main():
    print(f"[workflow-server v3] 端口 {PORT}")
    print(f"[workflow-server v3] 前端: http://localhost:{PORT}")
    print(f"[workflow-server v3] 批量问答模式 - 对话驱动")
    print(f"  POST /api/request    - 用户提交需求")
    print(f"  POST /api/questions  - TRAE 提交一批问题")
    print(f"  POST /api/answer     - 用户回答单个问题")
    print(f"  GET  /api/answers    - TRAE 获取一批回答")
    print(f"  POST /api/status     - 更新状态")
    print(f"  POST /api/log        - 记录日志")
    threading.Thread(target=open_browser, daemon=True).start()
    server = HTTPServer(("0.0.0.0", PORT), WorkflowHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[workflow-server] 已停止")
        server.server_close()


if __name__ == "__main__":
    main()
