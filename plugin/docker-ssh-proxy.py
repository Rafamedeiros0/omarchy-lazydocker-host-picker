#!/usr/bin/env python3
"""Bridge a local Unix socket to Docker's SSH stdio transport."""

import os
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
from urllib.parse import urlsplit


def parse_target(value: str) -> str:
    url = urlsplit(value)
    if url.scheme != "ssh" or not url.netloc or url.path or url.query or url.fragment:
        raise ValueError("expected an SSH Docker endpoint such as ssh://user@host")
    return url.netloc


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} ssh://[user@]host", file=sys.stderr)
        return 2
    try:
        target = parse_target(sys.argv[1])
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    if not shutil.which("ssh") or not shutil.which("lazydocker"):
        print("Both ssh and lazydocker must be installed", file=sys.stderr)
        return 127

    stop = threading.Event()
    active_lock = threading.Lock()
    active = {}

    with tempfile.TemporaryDirectory(prefix="lazydocker-dial-stdio-") as directory:
        socket_path = os.path.join(directory, "docker.sock")
        listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        listener.bind(socket_path)
        os.chmod(socket_path, 0o600)
        listener.listen(16)
        listener.settimeout(0.5)

        def serve_client(client: socket.socket) -> None:
            try:
                proc = subprocess.Popen(
                    ["ssh", target, "docker", "system", "dial-stdio"],
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    bufsize=0,
                )
            except OSError as exc:
                print(f"Could not start SSH Docker transport: {exc}", file=sys.stderr)
                client.close()
                return

            with active_lock:
                active[proc.pid] = (proc, client)

            def client_to_remote() -> None:
                try:
                    while True:
                        data = client.recv(65536)
                        if not data:
                            break
                        os.write(proc.stdin.fileno(), data)
                except (BrokenPipeError, OSError):
                    pass
                finally:
                    try:
                        proc.stdin.close()
                    except OSError:
                        pass

            def remote_to_client() -> None:
                try:
                    while True:
                        data = os.read(proc.stdout.fileno(), 65536)
                        if not data:
                            break
                        client.sendall(data)
                except (BrokenPipeError, OSError):
                    pass
                finally:
                    try:
                        client.shutdown(socket.SHUT_WR)
                    except OSError:
                        pass

            upstream = threading.Thread(target=client_to_remote, daemon=True)
            downstream = threading.Thread(target=remote_to_client, daemon=True)
            upstream.start()
            downstream.start()
            proc.wait()
            upstream.join(timeout=1)
            downstream.join(timeout=1)
            client.close()
            with active_lock:
                active.pop(proc.pid, None)

        def accept_clients() -> None:
            while not stop.is_set():
                try:
                    client, _ = listener.accept()
                except socket.timeout:
                    continue
                except OSError:
                    break
                threading.Thread(target=serve_client, args=(client,), daemon=True).start()

        server = threading.Thread(target=accept_clients, daemon=True)
        server.start()
        env = os.environ.copy()
        env["DOCKER_HOST"] = "unix://" + socket_path
        try:
            return subprocess.call(["lazydocker"], env=env)
        finally:
            stop.set()
            listener.close()
            with active_lock:
                connections = list(active.values())
            for proc, client in connections:
                try:
                    client.shutdown(socket.SHUT_RDWR)
                    client.close()
                except OSError:
                    pass
                proc.terminate()
            server.join(timeout=1)


if __name__ == "__main__":
    raise SystemExit(main())
