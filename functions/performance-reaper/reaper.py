"""Pauses performance instances that run too long and ends ones that live too long.

A running instance stops once it has run MAX_RUNTIME_HOURS since its last
start, or once its expires-at tag passed more than EXPIRY_GRACE_MINUTES ago.
Stopping keeps the disk, so the launcher can resume it. Any instance, running
or stopped, terminates MAX_LIFETIME_DAYS after it first launched.
"""

from __future__ import annotations

import logging
import os
from collections.abc import Iterator
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Literal

import boto3
from botocore.exceptions import BotoCoreError, ClientError

MAX_RUNTIME_HOURS = float(os.environ["MAX_RUNTIME_HOURS"])
MAX_RUNTIME = timedelta(hours=MAX_RUNTIME_HOURS)
MAX_LIFETIME_DAYS = float(os.environ["MAX_LIFETIME_DAYS"])
MAX_LIFETIME = timedelta(days=MAX_LIFETIME_DAYS)
EXPIRY_GRACE = timedelta(minutes=float(os.environ["EXPIRY_GRACE_MINUTES"]))

RUNNING_STATES = {"pending", "running"}

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")


@dataclass(frozen=True)
class Action:
    kind: Literal["stop", "terminate"]
    reason: str


def parse_expiry(value: str) -> datetime | None:
    try:
        expiry = datetime.fromisoformat(value)
    except ValueError:
        return None
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)
    return expiry


def first_launched(instance: dict) -> datetime:
    """When the instance first launched.

    LaunchTime resets on every start. The root volume's attachment keeps the
    original launch time across a stop and start.
    """
    launched = instance["LaunchTime"]
    for mapping in instance.get("BlockDeviceMappings", []):
        if mapping["DeviceName"] == instance.get("RootDeviceName") and "Ebs" in mapping:
            launched = min(launched, mapping["Ebs"]["AttachTime"])
    return launched


def expiry_reason(instance: dict, now: datetime) -> str | None:
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


def action_for(instance: dict, now: datetime) -> Action | None:
    launched = first_launched(instance)
    if now - launched > MAX_LIFETIME:
        return Action(
            "terminate",
            f"first launched {launched.isoformat()}, over the {MAX_LIFETIME_DAYS:g}d lifetime",
        )

    if instance["State"]["Name"] not in RUNNING_STATES:
        return None

    started = instance["LaunchTime"]
    if now - started > MAX_RUNTIME:
        return Action(
            "stop",
            f"started {started.isoformat()}, over the {MAX_RUNTIME_HOURS:g}h runtime",
        )

    reason = expiry_reason(instance, now)
    if reason:
        return Action("stop", reason)
    return None


def due_instances(now: datetime) -> Iterator[tuple[str, Action]]:
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
                action = action_for(instance, now)
                if action:
                    yield instance["InstanceId"], action


def is_protected(error: ClientError) -> bool:
    return error.response["Error"]["Code"] == "OperationNotPermitted"


def terminate(instance_id: str) -> None:
    try:
        ec2.terminate_instances(InstanceIds=[instance_id])
    except ClientError as error:
        if not is_protected(error):
            raise
        # Stop protection blocks termination too, so clear both.
        logger.info("Clearing stop and termination protection on %s", instance_id)
        ec2.modify_instance_attribute(
            InstanceId=instance_id, DisableApiStop={"Value": False}
        )
        ec2.modify_instance_attribute(
            InstanceId=instance_id, DisableApiTermination={"Value": False}
        )
        ec2.terminate_instances(InstanceIds=[instance_id])


def stop(instance_id: str) -> None:
    try:
        ec2.stop_instances(InstanceIds=[instance_id])
    except ClientError as error:
        if not is_protected(error):
            raise
        logger.info("Clearing stop protection on %s", instance_id)
        ec2.modify_instance_attribute(
            InstanceId=instance_id, DisableApiStop={"Value": False}
        )
        ec2.stop_instances(InstanceIds=[instance_id])


def handler(event: dict, context: object) -> dict[str, list[str]]:
    now = datetime.now(timezone.utc)
    done: dict[str, list[str]] = {"stopped": [], "terminated": []}
    failed: list[str] = []

    # One call per instance, so one that refuses does not shield the rest.
    for instance_id, action in due_instances(now):
        logger.info("%s %s: %s", action.kind.capitalize(), instance_id, action.reason)
        try:
            if action.kind == "terminate":
                terminate(instance_id)
                done["terminated"].append(instance_id)
            else:
                stop(instance_id)
                done["stopped"].append(instance_id)
        except (BotoCoreError, ClientError):
            logger.exception("Failed to %s %s", action.kind, instance_id)
            failed.append(instance_id)

    if failed:
        raise RuntimeError(f"Failed to act on {', '.join(failed)}")

    return done
