"""Shared, credential-file based MQTT configuration for Reserva bridges."""

from __future__ import annotations

import re
import socket
from pathlib import Path

import paho.mqtt.client as mqtt


CONFIG_PATH = Path("/etc/reserva-edge/mqtt.env")
ALLOWED_KEYS = {
    "MQTT_HOST",
    "MQTT_PORT",
    "MQTT_USERNAME",
    "MQTT_PASSWORD",
    "MQTT_TLS",
    "MQTT_DISCOVERY_PREFIX",
    "DEVICE_ID",
    "DEVICE_NAME",
    "TOPIC_ROOT",
}


def _unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def load_config(path: Path = CONFIG_PATH) -> dict[str, object]:
    values: dict[str, str] = {}
    for number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise RuntimeError(f"invalid MQTT config line {number}")
        key, value = line.split("=", 1)
        key = key.strip()
        if key not in ALLOWED_KEYS:
            raise RuntimeError(f"unknown MQTT config key: {key}")
        values[key] = _unquote(value)

    host = values.get("MQTT_HOST", "")
    if not host:
        raise RuntimeError("MQTT_HOST is required")
    try:
        port = int(values.get("MQTT_PORT", "1883"))
    except ValueError as exc:
        raise RuntimeError("MQTT_PORT must be an integer") from exc
    if not 1 <= port <= 65535:
        raise RuntimeError("MQTT_PORT is outside 1..65535")

    machine = Path("/etc/machine-id").read_text(encoding="ascii").strip()[:12]
    base = re.sub(r"[^a-z0-9]+", "_", socket.gethostname().lower()).strip("_")
    generated_id = f"reserva_edge_{base}_{machine}"
    device_id = re.sub(r"[^a-zA-Z0-9_-]+", "_", values.get("DEVICE_ID", "") or generated_id)
    if not device_id.strip("_"):
        raise RuntimeError("DEVICE_ID contains no usable characters")
    device_name = values.get("DEVICE_NAME", "") or f"Reserva Edge {socket.gethostname()}"
    topic_root = (values.get("TOPIC_ROOT", "") or f"reserva-edge/{device_id}").strip("/")
    if not re.fullmatch(r"[A-Za-z0-9_./-]+", topic_root):
        raise RuntimeError("TOPIC_ROOT contains unsupported characters")

    tls_value = values.get("MQTT_TLS", "false").lower()
    if tls_value not in {"true", "false"}:
        raise RuntimeError("MQTT_TLS must be true or false")

    return {
        "host": host,
        "port": port,
        "username": values.get("MQTT_USERNAME", ""),
        "password": values.get("MQTT_PASSWORD", ""),
        "tls": tls_value == "true",
        "discovery_prefix": values.get("MQTT_DISCOVERY_PREFIX", "homeassistant").strip("/"),
        "device_id": device_id,
        "device_name": device_name,
        "topic_root": topic_root,
    }


def make_client(component: str, config: dict[str, object]) -> mqtt.Client:
    client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2,
        client_id=f"{component}-{socket.gethostname()}"[:64],
    )
    username = str(config["username"])
    if username:
        client.username_pw_set(username, str(config["password"]))
    if bool(config["tls"]):
        client.tls_set()
    return client


def device_block(config: dict[str, object]) -> dict[str, object]:
    return {
        "identifiers": [str(config["device_id"])],
        "name": str(config["device_name"]),
        "manufacturer": "ONELAN",
        "model": "Reserva Edge 10T / ER5A0",
    }
