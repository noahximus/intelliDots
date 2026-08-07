"""Command-line entry point."""

from __future__ import annotations

import argparse
import logging
import os

from .proxy import ProxyConfig
from .server import WrapperServer


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate and repair local-model tool calls")
    parser.add_argument(
        "--host", default=os.getenv("LOCAL_LLM_WRAPPER_HOST", "127.0.0.1")
    )
    parser.add_argument(
        "--port", type=int, default=int(os.getenv("LOCAL_LLM_WRAPPER_PORT", "8090"))
    )
    parser.add_argument(
        "--backend",
        default=os.getenv("LOCAL_LLM_WRAPPER_BACKEND", "http://127.0.0.1:8081"),
    )
    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        default=os.getenv("LOCAL_LLM_WRAPPER_LOG_LEVEL", "INFO"),
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    config = ProxyConfig.from_env()
    config.backend_url = args.backend.rstrip("/")
    server = WrapperServer((args.host, args.port), config)
    logging.getLogger("local-llm-wrapper").info(
        "listening at http://%s:%d; backend=%s",
        args.host,
        args.port,
        config.backend_url,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
