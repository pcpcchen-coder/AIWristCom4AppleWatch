from typing import Literal

from pydantic import BaseModel, Field


class QueryRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    device: Literal["apple_watch"] = "apple_watch"
    locale: str = "zh-TW"
    session_id: str | None = None


class QueryResponse(BaseModel):
    ok: bool = True
    request_id: str
    reply: str
    intent: str = "general_chat"
    speak: bool = True
    provider: str = "codex_chatgpt_oauth"
    model: str | None = None


class AuthDeviceStartResponse(BaseModel):
    ok: bool = True
    verification_url: str
    user_code: str
    login_id: str | None = None
