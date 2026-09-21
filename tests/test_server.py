import asyncio
import json
import sys
from pathlib import Path
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'Server'))
import main
from codex_client import CodexAppServerClient, CodexRPCError, AuthRequiredError

@pytest.fixture
def client(monkeypatch):
    fake = type('Fake', (), {})()
    fake.start = AsyncMock()
    fake.close = AsyncMock()
    fake.account = AsyncMock(return_value={'account': {'type': 'chatgpt'}})
    fake.ask = AsyncMock(return_value=('固定繁中測試回覆', 'test-model'))
    fake.rate_limits = AsyncMock(return_value={'rateLimits': {}})
    fake.start_device_login = AsyncMock(return_value={'verificationUrl': 'https://example.test', 'userCode': 'test'})
    monkeypatch.setattr(main, 'codex', fake)
    monkeypatch.setenv('AIWRIST_DEVICE_TOKEN', 'test-secret')
    with TestClient(main.app) as client:
        yield client, fake

HEADERS = {'Authorization': 'Bearer test-secret'}

def test_ten_fake_http_queries(client):
    api, fake = client
    for _ in range(10):
        response = api.post('/api/v1/query', json={'text': '中文測試'}, headers=HEADERS)
        assert response.status_code == 200
        assert response.json()['reply'] == '固定繁中測試回覆'
    assert fake.ask.await_count == 10

@pytest.mark.parametrize('path', ['/api/v1/auth/status', '/api/v1/limits'])
def test_authenticated_status(client, path):
    api, _ = client
    assert api.get(path).status_code == 401
    assert api.get(path, headers=HEADERS).status_code == 200

@pytest.mark.parametrize('text', ['', '   ', 'x' * 4001])
def test_invalid_input(client, text):
    api, fake = client
    assert api.post('/api/v1/query', json={'text': text}, headers=HEADERS).status_code == 422
    fake.ask.assert_not_called()

@pytest.mark.parametrize('error,status', [(AuthRequiredError('expired'), 401), (TimeoutError(), 504), (CodexRPCError('failed'), 502)])
def test_error_mapping(client, error, status):
    api, fake = client
    fake.ask.side_effect = error
    assert api.post('/api/v1/query', json={'text': 'test'}, headers=HEADERS).status_code == status

def test_device_login(client):
    api, _ = client
    assert api.post('/api/v1/auth/device/start', headers=HEADERS).json()['user_code'] == 'test'

def test_rpc_ignores_other_thread_and_fails_pending_on_eof():
    async def run():
        rpc = CodexAppServerClient()
        reader = asyncio.StreamReader()
        rpc._proc = type('Proc', (), {'stdout': reader})()
        rpc._active_thread_id = 'mine'
        rpc._active_turn_id = 'my-turn'
        event = asyncio.Event()
        rpc._turn_events['mine'] = event
        future = asyncio.get_running_loop().create_future()
        rpc._pending[7] = future
        messages = [
            {'method': 'item/completed', 'params': {'threadId': 'other', 'item': {'type': 'agentMessage', 'phase': 'final_answer', 'text': 'WRONG'}}},
            {'method': 'item/completed', 'params': {'threadId': 'mine', 'turnId': 'my-turn', 'item': {'type': 'agentMessage', 'phase': 'final_answer', 'text': 'RIGHT'}}},
        ]
        for message in messages:
            reader.feed_data((json.dumps(message) + '\n').encode())
        reader.feed_eof()
        await rpc._reader_loop()
        assert rpc._active_final_text == 'RIGHT'
        assert event.is_set()
        with pytest.raises(CodexRPCError):
            await future
    asyncio.run(run())

def test_total_deadline_and_cleanup():
    async def run():
        rpc = CodexAppServerClient()
        async def hang(*args):
            rpc._active_thread_id = 't'
            rpc._turn_buffers['t'] = ['partial']
            await asyncio.sleep(10)
        rpc._ask = hang
        rpc.close = AsyncMock()
        with pytest.raises(TimeoutError):
            await rpc.ask('test', timeout_seconds=0.01)
        assert rpc._active_thread_id is None
        assert not rpc._turn_buffers
        rpc.close.assert_awaited_once()
    asyncio.run(run())
