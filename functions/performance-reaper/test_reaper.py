from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from unittest import mock

import pytest

os.environ.setdefault("MAX_RUNTIME_HOURS", "12")
os.environ.setdefault("MAX_LIFETIME_DAYS", "7")
os.environ.setdefault("EXPIRY_GRACE_MINUTES", "15")
os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")

with mock.patch("boto3.client"):
    import reaper

NOW = datetime(2026, 9, 27, 12, tzinfo=timezone.utc)


def instance(
    started_hours_ago: float,
    launched_hours_ago: float | None = None,
    state: str = "running",
    expires_at: str | None = None,
) -> dict:
    launched = (
        launched_hours_ago if launched_hours_ago is not None else started_hours_ago
    )
    result: dict = {
        "InstanceId": "i-0123456789abcdef0",
        "State": {"Name": state},
        "LaunchTime": NOW - timedelta(hours=started_hours_ago),
        "RootDeviceName": "/dev/xvda",
        "BlockDeviceMappings": [
            {
                "DeviceName": "/dev/xvda",
                "Ebs": {"AttachTime": NOW - timedelta(hours=launched)},
            },
        ],
    }
    if expires_at is not None:
        result["Tags"] = [{"Key": "expires-at", "Value": expires_at}]
    return result


@pytest.mark.parametrize(
    ("instance", "expected"),
    [
        (instance(11), None),
        (instance(13), "stop"),
        (instance(1, launched_hours_ago=13), None),
        (instance(13, state="stopped"), None),
        (instance(1, launched_hours_ago=24 * 8), "terminate"),
        (instance(1, launched_hours_ago=24 * 8, state="stopped"), "terminate"),
        (instance(2, expires_at="2026-09-27T11:50:00Z"), None),
        (instance(2, expires_at="2026-09-27T11:40:00Z"), "stop"),
        (instance(2, expires_at="2026-09-27T11:40:00"), "stop"),
        (instance(2, state="stopped", expires_at="2026-09-27T11:40:00Z"), None),
        (instance(2, expires_at="2026-09-27T13:00:00+00:00"), None),
        (instance(2, expires_at="not a date"), None),
        (instance(13, expires_at="not a date"), "stop"),
    ],
    ids=[
        "under runtime",
        "over runtime",
        "resumed within runtime",
        "stopped over runtime",
        "over lifetime",
        "stopped over lifetime",
        "expired within grace",
        "expired past grace",
        "naive expiry read as UTC",
        "stopped past expiry",
        "not yet expired",
        "unparseable expiry",
        "unparseable expiry over runtime",
    ],
)
def test_action_for(instance: dict, expected: str | None) -> None:
    action = reaper.action_for(instance, NOW)
    assert (action.kind if action else None) == expected
