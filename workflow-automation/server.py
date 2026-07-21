"""
自动化开发工作流 - 交互服务器 v4
WebSocket + HTTP 混合架构
- HTTP 端口 8765: API + 前端页面 + 长轮询
- WebSocket 端口 8766: 实时推送问题/状态/日志, 接收回答

核心改进:
  TRAE 提交问题后, 通过 WebSocket 实时推送给前端
  前端回答后, 通过 batch_event 即时唤醒 TRAE 长轮询
  无需用户在终端输入"继续"/"确认"

启动: python server.py
"""

import json
import time
import threading
import asyncio
import os
import webbrowser
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import websockets

HTTP_PORT = 8765
WS_PORT = 8766
UI_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ui.html")

# 全局状态
state = {
    "request": None,          # 用户提交的需求
    "batch_id": 0,            # 当前批次ID
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
    "history": [],            # 所有批次的历史记录
    "ws_clients": set(),      # 连接的 WebSocket 客户端
    "batch_event": threading.Event(),  # 批次完成事件(唤醒长轮询)
}
state_lock = threading.Lock()

# WebSocket 事件循环引用(用于跨线程推送)
ws_loop = None


# ============ WebSocket 服务器 (端口 8766, 异步) ============

async def ws_handler(websocket):
    """WebSocket 连接处理"""
    with state_lock:
        state["ws_clients"].add(websocket)
    client_count = len(state["ws_clients"])
    print(f"[WS] 客户端连接, 当前 {client_count} 个")

    try:
        # 发送当前完整状态(支持断线重连后恢复)
        with state_lock:
            init_msg = {
                "type": "init",
                "request": state["request"],
                "batch_id": state["batch_id"],
                "questions": list(state["questions"]),
                "answers": dict(state["answers"]),
                "batch_ready": state["batch_ready"],
                "status": dict(state["status"]),
                "logs": list(state["logs"][-20:]),
                "history": list(state["history"][-10:]),
            }
        await websocket.send(json.dumps(init_msg, ensure_ascii=False))

        # 监听客户端消息(回答)
        async for message in websocket:
            try:
                data = json.loads(message)
            except json.JSONDecodeError:
                continue

            if data.get("type") == "answer":
                qid = data.get("question_id", -1)
                answer = data.get("answer", "")
                msg_batch_id = data.get("batch_id", 0)

                with state_lock:
                    # 忽略旧批次的回答
                    if msg_batch_id != 0 and msg_batch_id != state["batch_id"]:
                        continue

                    state["answers"][str(qid)] = answer
                    total = len(state["questions"])
                    answered = len(state["answers"])
                    was_ready = state["batch_ready"]
                    state["batch_ready"] = answered >= total and total > 0

                    # 首次变为 ready 时记录历史
                    if state["batch_ready"] and not was_ready:
                        for q in state["questions"]:
                            state["history"].append({
                                "batch_id": state["batch_id"],
                                "step_name": q["step_name"],
                                "question": q["question"],
                                "answer": state["answers"].get(str(q["id"]), "")
                            })
                        # 触发批次完成事件,唤醒长轮询
                        state["batch_event"].set()
                        print(f"[WS] 批次 {state['batch_id']} 全部回答完成, 已唤醒长轮询")

                # 广播更新给所有客户端
                await broadcast_ws({
                    "type": "update",
                    "batch_id": state["batch_id"],
                    "answers": dict(state["answers"]),
                    "batch_ready": state["batch_ready"],
                })

                # 如果批次完成,推送完成消息
                if state["batch_ready"]:
                    await broadcast_ws({
                        "type": "batch_complete",
                        "batch_id": state["batch_id"],
                    })

    except websockets.exceptions.ConnectionClosed:
        pass
    except Exception as e:
        print(f"[WS] 错误: {e}")
    finally:
        with state_lock:
            state["ws_clients"].discard(websocket)
        print(f"[WS] 客户端断开, 当前 {len(state['ws_clients'])} 个")


async def broadcast_ws(message_dict):
    """广播消息给所有 WebSocket 客户端"""
    msg = json.dumps(message_dict, ensure_ascii=False)
    clients = list(state["ws_clients"])
    if clients:
        await asyncio.gather(
            *[client.send(msg) for client in clients],
            return_exceptions=True
        )


def push_to_ws_clients(message_dict):
    """从 HTTP 线程推送消息到 WebSocket 客户端(跨线程安全)"""
    global ws_loop
    if ws_loop and not ws_loop.is_closed():
        try:
            asyncio.run_coroutine_threadsafe(broadcast_ws(message_dict), ws_loop)
        except Exception as e:
            print(f"[HTTP] WebSocket 推送失败: {e}")


def start_ws_server():
    """在单独线程中启动 WebSocket 服务器"""
    global ws_loop
    ws_loop = asyncio.new_event_loop()
    asyncio.set_event_loop(ws_loop)

    async def main():
        async with websockets.serve(ws_handler, "0.0.0.0", WS_PORT):
            print(f"[WS] WebSocket 服务器启动在 ws://0.0.0.0:{WS_PORT}")
            # 永久阻塞,保持服务器运行
            await asyncio.Future()

    ws_loop.run_until_complete(main())


# ============ HTTP 服务器 (端口 8765, 多线程) ============

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
                    "answers": dict(state["answers"]),
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

        # 核心 API: 长轮询等待回答完成
        if path == "/api/wait_answers":
            parsed = urlparse(self.path)
            params = parse_qs(parsed.query)
            timeout = int(params.get("timeout", ["300"])[0])
            req_batch_id = int(params.get("batch_id", ["0"])[0])

            with state_lock:
                # 如果已经 ready, 立即返回
                if state["batch_ready"] and (req_batch_id == 0 or state["batch_id"] == req_batch_id):
                    self._send_json({
                        "batch_id": state["batch_id"],
                        "answers": dict(state["answers"]),
                        "batch_ready": True,
                        "timeout": False,
                    })
                    return
                # 重置事件(确保等待的是新事件)
                state["batch_event"].clear()

            # 阻塞等待批次完成事件(最多 timeout 秒)
            triggered = state["batch_event"].wait(timeout=timeout)

            with state_lock:
                self._send_json({
                    "batch_id": state["batch_id"],
                    "answers": dict(state["answers"]),
                    "batch_ready": state["batch_ready"],
                    "timeout": not triggered,
                })
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
                req_snapshot = dict(state["request"])
            # 推送到前端
            push_to_ws_clients({
                "type": "request",
                "request": req_snapshot,
            })
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
                state["batch_event"].clear()
                new_batch_id = state["batch_id"]
                questions_snapshot = list(state["questions"])

            # 通过 WebSocket 推送问题给前端
            push_to_ws_clients({
                "type": "questions",
                "batch_id": new_batch_id,
                "step_name": step_name,
                "questions": questions_snapshot,
            })

            print(f"[HTTP] 批次 {new_batch_id} 提交: {len(questions_snapshot)} 个问题, 已推送 WebSocket")
            self._send_json({"ok": True, "batch_id": new_batch_id, "count": len(questions_snapshot), "ws_pushed": True})
            return

        if path == "/api/answer":
            # HTTP 回退: 用户通过 HTTP 回答单个问题
            qid = body.get("question_id", -1)
            answer = body.get("answer", "")
            with state_lock:
                state["answers"][str(qid)] = answer
                total = len(state["questions"])
                answered = len(state["answers"])
                was_ready = state["batch_ready"]
                state["batch_ready"] = answered >= total and total > 0
                if state["batch_ready"] and not was_ready:
                    for q in state["questions"]:
                        state["history"].append({
                            "batch_id": state["batch_id"],
                            "step_name": q["step_name"],
                            "question": q["question"],
                            "answer": state["answers"].get(str(q["id"]), "")
                        })
                    state["batch_event"].set()
                batch_id_snapshot = state["batch_id"]
                answers_snapshot = dict(state["answers"])
                batch_ready_snapshot = state["batch_ready"]

            # 推送更新给前端
            push_to_ws_clients({
                "type": "update",
                "batch_id": batch_id_snapshot,
                "answers": answers_snapshot,
                "batch_ready": batch_ready_snapshot,
            })

            self._send_json({"ok": True, "batch_ready": batch_ready_snapshot})
            return

        if path == "/api/status":
            with state_lock:
                state["status"] = {
                    "step": body.get("step", 0),
                    "total_steps": body.get("total_steps", 6),
                    "step_name": body.get("step_name", ""),
                    "status": body.get("status", "in_progress")
                }
                status_snapshot = dict(state["status"])
            # 推送状态更新给前端
            push_to_ws_clients({
                "type": "status",
                "status": status_snapshot,
            })
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
            # 推送日志给前端
            push_to_ws_clients({
                "type": "log",
                "log": entry,
            })
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
                state["batch_event"].clear()
            # 推送重置给前端
            push_to_ws_clients({"type": "reset"})
            self._send_json({"ok": True})
            return

        self._send_json({"error": "not found"}, 404)


# ============ 启动 ============

def open_browser():
    time.sleep(1)
    webbrowser.open(f"http://localhost:{HTTP_PORT}")


def main():
    print(f"[workflow-server v4] HTTP 端口 {HTTP_PORT}, WebSocket 端口 {WS_PORT}")
    print(f"[workflow-server v4] 前端: http://localhost:{HTTP_PORT}")
    print(f"[workflow-server v4] WebSocket + HTTP 混合架构 - 无需终端交互")
    print(f"  GET  /api/wait_answers?timeout=300  - TRAE 长轮询等待回答(自动继续)")
    print(f"  POST /api/questions                 - TRAE 提交问题(自动推送WebSocket)")
    print(f"  POST /api/answer                    - HTTP回退:用户回答")
    print(f"  POST /api/status                    - 更新状态(自动推送WebSocket)")
    print(f"  POST /api/log                       - 记录日志(自动推送WebSocket)")
    print(f"  WebSocket ws://localhost:{WS_PORT}  - 前端实时通信")

    # 启动 WebSocket 服务器线程
    ws_thread = threading.Thread(target=start_ws_server, daemon=True)
    ws_thread.start()

    # 等待 WebSocket 服务器启动
    time.sleep(0.5)

    # 启动浏览器
    threading.Thread(target=open_browser, daemon=True).start()

    # 启动 HTTP 服务器(主线程, 多线程处理请求)
    server = ThreadingHTTPServer(("0.0.0.0", HTTP_PORT), WorkflowHandler)
    server.daemon_threads = True
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[workflow-server] 已停止")
        server.server_close()


if __name__ == "__main__":
    main()
