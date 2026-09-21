import asyncio
import json
from typing import Any


class CodexRPCError(RuntimeError):
    pass


class AuthRequiredError(RuntimeError):
    pass


class CodexAppServerClient:
    """Minimal async bridge to the official `codex app-server` stdio protocol.

    v0.1 intentionally serializes turns with a lock. This keeps the Watch MVP
    predictable while still allowing auth/status endpoints to use the same
    long-lived app-server process.
    """

    def __init__(self) -> None:
        self._proc: asyncio.subprocess.Process | None = None
        self._reader_task: asyncio.Task | None = None
        self._next_id = 1
        self._pending: dict[int, asyncio.Future] = {}
        self._turn_events: dict[str, asyncio.Event] = {}
        self._turn_buffers: dict[str, list[str]] = {}
        self._turn_status: dict[str, dict[str, Any]] = {}
        self._active_thread_id: str | None = None
        self._active_turn_id: str | None = None
        self._active_final_text: str | None = None
        self._active_error: str | None = None
        self._ask_lock = asyncio.Lock()
        self._write_lock = asyncio.Lock()
        self._start_lock = asyncio.Lock()

    async def start(self) -> None:
        async with self._start_lock:
            await self._start()

    async def _start(self) -> None:
        if self._proc and self._proc.returncode is None:
            return

        try:
            self._proc = await asyncio.create_subprocess_exec(
                "codex",
                "app-server",
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            )
        except FileNotFoundError as exc:
            raise RuntimeError(
                "Codex CLI not found. Install the official Codex CLI first."
            ) from exc

        self._reader_task = asyncio.create_task(self._reader_loop())

        try:
            await self._request(
                "initialize",
                {
                    "clientInfo": {
                        "name": "aiwristcom",
                        "title": "AIWristCom4AppleWatch",
                        "version": "0.1.0",
                    }
                },
            )
            await self._notify("initialized", {})

        except BaseException:
            await self.close()
            raise

    async def close(self) -> None:
        if self._proc and self._proc.returncode is None:
            self._proc.terminate()
            try:
                await asyncio.wait_for(self._proc.wait(), timeout=5)
            except asyncio.TimeoutError:
                self._proc.kill()
                await self._proc.wait()

        if self._reader_task:
            self._reader_task.cancel()
            try:
                await self._reader_task
            except asyncio.CancelledError:
                pass

    async def account(self) -> dict[str, Any]:
        return await self._request(
            "account/read",
            {"refreshToken": False},
        )

    async def start_device_login(self) -> dict[str, Any]:
        return await self._request(
            "account/login/start",
            {"type": "chatgptDeviceCode"},
        )

    async def rate_limits(self) -> dict[str, Any]:
        return await self._request("account/rateLimits/read", None)

    async def models(self) -> dict[str, Any]:
        return await self._request(
            "model/list",
            {"limit": 50, "includeHidden": False},
        )

    async def ask(self, text: str, timeout_seconds: float = 20.0) -> tuple[str, str | None]:
        # Deadline includes queueing, account/model lookup, thread creation and generation.
        async with asyncio.timeout(timeout_seconds):
            async with self._ask_lock:
                try:
                    return await self._ask(text, timeout_seconds)
                finally:
                    # On cancellation/timeout, stop the process before accepting a new turn.
                    # This avoids late events contaminating a subsequent request.
                    if self._active_thread_id is not None:
                        await self.close()
                    self._turn_events.clear()
                    self._turn_buffers.clear()
                    self._turn_status.clear()
                    self._active_thread_id = None
                    self._active_turn_id = None
                    self._active_final_text = None
                    self._active_error = None

    async def _ask(self, text: str, timeout_seconds: float) -> tuple[str, str | None]:
        account_state = await self.account()
        account = account_state.get("account")
        if not account or account.get("type") != "chatgpt":
            raise AuthRequiredError(
                "ChatGPT OAuth login is required. Complete device login first."
            )

        model_id = await self._select_default_model()

        thread_params: dict[str, Any] = {
            "approvalPolicy": "never",
            "sandbox": "readOnly",
            "personality": "friendly",
            "serviceName": "aiwristcom_v0_1",
        }
        if model_id:
            thread_params["model"] = model_id

        thread_result = await self._request("thread/start", thread_params)
        thread_id = thread_result["thread"]["id"]

        self._turn_events[thread_id] = asyncio.Event()
        self._turn_buffers[thread_id] = []
        self._turn_status.pop(thread_id, None)
        self._active_thread_id = thread_id
        self._active_turn_id = None
        self._active_final_text = None
        self._active_error = None

        watch_prompt = (
            "你是 Apple Watch 上的精簡語音助理。"
            "直接回答使用者問題；除非使用者明確要求，否則不要執行 shell、"
            "不要修改檔案、不要操作電腦。"
            "回答請適合手錶閱讀與語音朗讀，預設使用繁體中文，簡潔但完整。\n\n"
            f"使用者：{text}"
        )

        turn_result = await self._request(
            "turn/start",
            {
                "threadId": thread_id,
                "input": [{"type": "text", "text": watch_prompt}],
            },
        )

        turn_id = turn_result.get("turn", {}).get("id")
        self._active_turn_id = turn_id

        try:
            await asyncio.wait_for(
                self._turn_events[thread_id].wait(),
                timeout=timeout_seconds,
            )
        except asyncio.TimeoutError as exc:
            if turn_id:
                try:
                    await self._request(
                        "turn/interrupt",
                        {"threadId": thread_id, "turnId": turn_id},
                    )
                except Exception:
                    pass
            raise TimeoutError("Codex turn timed out") from exc

        status = self._turn_status.get(thread_id, {})
        turn = status.get("turn", {})
        if turn.get("status") != "completed":
            error = turn.get("error") or {}
            raise CodexRPCError(error.get("message", "Codex turn failed"))

        if self._active_error:
            raise CodexRPCError(self._active_error)

        reply = (self._active_final_text or "").strip()
        if not reply:
            reply = "".join(self._turn_buffers.get(thread_id, [])).strip()
        if not reply:
            raise CodexRPCError("Codex returned an empty reply")

        self._turn_events.pop(thread_id, None)
        self._turn_buffers.pop(thread_id, None)
        self._turn_status.pop(thread_id, None)
        self._active_thread_id = None
        self._active_turn_id = None
        self._active_final_text = None
        self._active_error = None

        return reply, model_id

    async def _select_default_model(self) -> str | None:
        result = await self.models()
        data = result.get("data", [])
        for item in data:
            if item.get("isDefault"):
                return item.get("id") or item.get("model")
        if data:
            return data[0].get("id") or data[0].get("model")
        raise CodexRPCError("No available model")

    async def _request(self, method: str, params: dict[str, Any] | None) -> dict[str, Any]:
        if not self._proc or self._proc.returncode is not None:
            await self.start()

        request_id = self._next_id
        self._next_id += 1

        loop = asyncio.get_running_loop()
        future = loop.create_future()
        self._pending[request_id] = future

        message: dict[str, Any] = {"method": method, "id": request_id}
        if params is not None:
            message["params"] = params

        try:
            await self._write(message)
            return await asyncio.wait_for(future, timeout=10)
        finally:
            self._pending.pop(request_id, None)

    async def _notify(self, method: str, params: dict[str, Any]) -> None:
        await self._write({"method": method, "params": params})

    async def _write(self, message: dict[str, Any]) -> None:
        if not self._proc or not self._proc.stdin:
            raise CodexRPCError("Codex app-server is not running")

        payload = (json.dumps(message, ensure_ascii=False) + "\n").encode("utf-8")
        async with self._write_lock:
            self._proc.stdin.write(payload)
            await self._proc.stdin.drain()

    async def _reader_loop(self) -> None:
        assert self._proc is not None
        assert self._proc.stdout is not None

        while True:
            line = await self._proc.stdout.readline()
            if not line:
                break

            try:
                message = json.loads(line.decode("utf-8"))
            except json.JSONDecodeError:
                continue

            if "id" in message and "method" in message:
                await self._write({"id": message["id"], "error": {
                    "code": -32601, "message": "Interactive tools are unsupported by AIWrist v0.1"}})
                continue

            if "id" in message:
                request_id = message.get("id")
                future = self._pending.get(request_id)
                if future and not future.done():
                    if "error" in message:
                        err = message["error"]
                        future.set_exception(
                            CodexRPCError(err.get("message", str(err)))
                        )
                    else:
                        future.set_result(message.get("result", {}))
                continue

            method = message.get("method")
            params = message.get("params") or {}
            thread_id = params.get("threadId")
            if thread_id != self._active_thread_id or thread_id is None:
                continue
            event_turn = params.get("turnId") or (params.get("turn") or {}).get("id")
            if self._active_turn_id and event_turn and event_turn != self._active_turn_id:
                continue

            if method == "item/agentMessage/delta" and thread_id:
                delta = params.get("delta")
                if isinstance(delta, str):
                    self._turn_buffers.setdefault(thread_id, []).append(delta)

            elif method == "item/completed" and thread_id:
                item = params.get("item") or {}
                if item.get("type") == "agentMessage":
                    full_text = item.get("text")
                    phase = item.get("phase")
                    if isinstance(full_text, str):
                        if phase == "final_answer":
                            self._active_final_text = full_text
                        elif not self._active_final_text and not self._turn_buffers.get(thread_id):
                            self._turn_buffers.setdefault(thread_id, []).append(full_text)

            elif method == "error":
                error = params.get("error") or {}
                self._active_error = error.get("message") or str(error)

            elif method == "turn/completed":
                turn = params.get("turn") or {}
                turn_id = turn.get("id")
                if (
                    self._active_thread_id
                    and (
                        not self._active_turn_id
                        or not turn_id
                        or turn_id == self._active_turn_id
                    )
                ):
                    thread_id = self._active_thread_id
                    self._turn_status[thread_id] = params
                    event = self._turn_events.get(thread_id)
                    if event:
                        event.set()

        # EOF must fail waiters rather than leave them hanging until the UI deadline.
        for future in list(self._pending.values()):
            if not future.done():
                future.set_exception(CodexRPCError("Codex app-server disconnected"))
        self._active_error = "Codex app-server disconnected"
        for event in self._turn_events.values():
            event.set()
