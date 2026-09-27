from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from unittest import mock

import pytest

os.environ.setdefault("MAX_RUNTIME_HOURS", "12")
os.environ.setdefault("EXPIRY_GRACE_MINUTES", "15")
os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")

with mock.patch("boto3.client"):
    import reaper

NOW = datetime(2026, 9, 27, 12, tzinfo=timezone.utc)


def instance(
    launched_hours_ago: float,
    attached_hours_ago: float | None = None,
    expires_at: str | None = None,
) -> dict:
    attached = (
        attached_hours_ago if attached_hours_ago is not None else launched_hours_ago
    )
    result: dict = {
        "InstanceId": "i-0123456789abcdef0",
        "LaunchTime": NOW - timedelta(hours=launched_hours_ago),
        "RootDeviceName": "/dev/xvda",
        "BlockDeviceMappings": [
            {
                "DeviceName": "/dev/xvda",
                "Ebs": {"AttachTime": NOW - timedelta(hours=attached)},
            },
        ],
    }
    if expires_at is not None:
        result["Tags"] = [{"Key": "expires-at", "Value": expires_at}]
    return result


@pytest.mark.parametrize(
    ("instance", "terminated"),
    [
        (instance(11), False),
        (instance(13), True),
        (instance(1, attached_hours_ago=13), True),
        (instance(2, expires_at="2026-09-27T11:50:00Z"), False),
        (instance(2, expires_at="2026-09-27T11:40:00Z"), True),
        (instance(2, expires_at="2026-09-27T11:40:00"), True),
        (instance(2, expires_at="2026-09-27T13:00:00+00:00"), False),
        (instance(2, expires_at="not a date"), False),
        (instance(13, expires_at="not a date"), True),
    ],
    ids=[
        "under ceiling",
        "over ceiling",
        "restarted past ceiling",
        "expired within grace",
        "expired past grace",
        "naive expiry read as UTC",
        "not yet expired",
        "unparseable expiry",
        "unparseable expiry over ceiling",
    ],
)
def test_termination_reason(instance: dict, terminated: bool) -> None:
    assert (reaper.termination_reason(instance, NOW) is not None) == terminated
