import os
import secrets
import uuid
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Header, HTTPException

from codex_client import AuthRequiredError, CodexAppServerClient, CodexRPCError
from models import AuthDeviceStartResponse, QueryRequest, QueryResponse


codex = CodexAppServerClient()


@asynccontextmanager
async def lifespan(app: FastAPI):
    await codex.start()
    try:
        yield
    finally:
        await codex.close()


app = FastAPI(
    title="AIWristCom Gateway",
    version="0.1.0",
    lifespan=lifespan,
)


async def verify_device_token(
    authorization: str | None = Header(default=None),
) -> None:
    expected = os.getenv("AIWRIST_DEVICE_TOKEN")
    if not expected:
        return

    if not secrets.compare_digest(authorization or "", f"Bearer {expected}"):
        raise HTTPException(status_code=401, detail="Invalid device token")


@app.get("/health")
async def health():
    try:
        state = await codex.account()
        account = state.get("account")
        return {
            "ok": True,
            "codex": "running",
            "authenticated": bool(account and account.get("type") == "chatgpt"),
            "plan_type": account.get("planType") if account else None,
        }
    except Exception as exc:
        return {
            "ok": False,
            "codex": "error",
            "error": str(exc),
        }


@app.get("/api/v1/auth/status")
async def auth_status(_: None = Depends(verify_device_token)):
    state = await codex.account()
    account = state.get("account")
    return {
        "ok": True,
        "authenticated": bool(account and account.get("type") == "chatgpt"),
        "account_type": account.get("type") if account else None,
        "plan_type": account.get("planType") if account else None,
        "email": account.get("email") if account else None,
    }


@app.post(
    "/api/v1/auth/device/start",
    response_model=AuthDeviceStartResponse,
)
async def auth_device_start(_: None = Depends(verify_device_token)):
    result = await codex.start_device_login()
    return AuthDeviceStartResponse(
        verification_url=result["verificationUrl"],
        user_code=result["userCode"],
        login_id=result.get("loginId"),
    )


@app.get("/api/v1/limits")
async def limits(_: None = Depends(verify_device_token)):
    try:
        result = await codex.rate_limits()
        return {"ok": True, **result}
    except CodexRPCError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@app.post("/api/v1/query", response_model=QueryResponse)
async def query(
    request: QueryRequest,
    _: None = Depends(verify_device_token),
):
    request_id = f"req_{uuid.uuid4().hex[:12]}"

    try:
        reply, model = await codex.ask(request.text, timeout_seconds=20)
    except AuthRequiredError as exc:
        raise HTTPException(
            status_code=401,
            detail={
                "code": "CHATGPT_AUTH_REQUIRED",
                "message": str(exc),
            },
        ) from exc
    except TimeoutError as exc:
        raise HTTPException(
            status_code=504,
            detail={
                "code": "MODEL_TIMEOUT",
                "message": "AI 暫時沒有在時間內回應",
            },
        ) from exc
    except CodexRPCError as exc:
        raise HTTPException(
            status_code=502,
            detail={
                "code": "CODEX_ERROR",
                "message": str(exc),
            },
        ) from exc

    return QueryResponse(
        request_id=request_id,
        reply=reply,
        model=model,
    )
