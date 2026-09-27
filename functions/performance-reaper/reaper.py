"""Terminates performance instances that have outlived their runtime limits.

Stopped instances count too, since their volumes still bill.
"""

from __future__ import annotations

import logging
import os
from collections.abc import Iterator
from datetime import datetime, timedelta, timezone

import boto3
from botocore.exceptions import BotoCoreError, ClientError

MAX_RUNTIME_HOURS = float(os.environ["MAX_RUNTIME_HOURS"])
MAX_RUNTIME = timedelta(hours=MAX_RUNTIME_HOURS)
EXPIRY_GRACE = timedelta(minutes=float(os.environ["EXPIRY_GRACE_MINUTES"]))

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")


def parse_expiry(value: str) -> datetime | None:
    try:
        expiry = datetime.fromisoformat(value)
    except ValueError:
        return None
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)
    return expiry


def started_at(instance: dict) -> datetime:
    """When the instance first launched.

    LaunchTime resets on every start, so a stop and start would restart the
    clock. The root volume's attachment keeps the original launch time.
    """
    started = instance["LaunchTime"]
    for mapping in instance.get("BlockDeviceMappings", []):
        if mapping["DeviceName"] == instance.get("RootDeviceName"):
            started = min(started, mapping["Ebs"]["AttachTime"])
    return started


def termination_reason(instance: dict, now: datetime) -> str | None:
    started = started_at(instance)
    if now - started > MAX_RUNTIME:
        return f"started {started.isoformat()}, over the {MAX_RUNTIME_HOURS:g}h limit"

    tags = {tag["Key"]: tag["Value"] for tag in instance.get("Tags", [])}
    if "expires-at" not in tags:
        return None

    expiry = parse_expiry(tags["expires-at"])
    if expiry is None:
        logger.warning(
            "%s has an unparseable expires-at %r",
            instance["InstanceId"],
            tags["expires-at"],
        )
        return None
    if now - expiry > EXPIRY_GRACE:
        return f"expired {expiry.isoformat()}"
    return None


def expired_instances(now: datetime) -> Iterator[tuple[str, str]]:
    paginator = ec2.get_paginator("describe_instances")
    pages = paginator.paginate(
        Filters=[
            {
                "Name": "instance-state-name",
                "Values": ["pending", "running", "stopping", "stopped"],
            }
        ]
    )
    for page in pages:
        for reservation in page["Reservations"]:
            for instance in reservation["Instances"]:
                reason = termination_reason(instance, now)
                if reason:
                    yield instance["InstanceId"], reason


def handler(event: dict, context: object) -> dict[str, list[str]]:
    now = datetime.now(timezone.utc)
    terminated: list[str] = []
    failed: list[str] = []

    # One call per instance, so one that refuses termination does not
    # shield the rest.
    for instance_id, reason in expired_instances(now):
        logger.info("Terminating %s: %s", instance_id, reason)
        try:
            ec2.terminate_instances(InstanceIds=[instance_id])
            terminated.append(instance_id)
        except (BotoCoreError, ClientError):
            logger.exception("Failed to terminate %s", instance_id)
            failed.append(instance_id)

    if failed:
        raise RuntimeError(f"Failed to terminate {', '.join(failed)}")

    return {"terminated": terminated}
