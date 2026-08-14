import os
import secrets
import socket
from pathlib import Path

import qrcode
from dotenv import load_dotenv, set_key


def get_local_ip() -> str:
    """Get the local IP address of the machine."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Destination does not need to be reachable.
        s.connect(("10.255.255.255", 1))
        ip = s.getsockname()[0]
    except OSError:
        ip = "127.0.0.1"
    finally:
        s.close()
    return ip


def get_or_create_token() -> str:
    """Read the NOBS_DEVICE_TOKEN from .env, generating one if missing."""
    env_path = Path(".env")
    if not env_path.exists():
        env_path.touch()

    load_dotenv(dotenv_path=env_path)
    token = os.getenv("NOBS_DEVICE_TOKEN")

    if not token:
        token = secrets.token_urlsafe(32)
        set_key(env_path, "NOBS_DEVICE_TOKEN", token)
        print("Generated new NOBS_DEVICE_TOKEN and saved to .env")

    return token


def main():
    print("NOBS Zero-Configuration Pairing")
    print("===============================\n")

    ip = get_local_ip()
    port = 8000
    token = get_or_create_token()

    # Construct the pairing URL
    pairing_url = f"nobs://pair?url=http://{ip}:{port}&token={token}"

    print(f"Tank Address: http://{ip}:{port}")
    print(f"Device Token: {token}\n")
    print("Scan this QR code from the NOBS iOS App (Privacy -> Scan QR Code to Pair):\n")

    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    qr.add_data(pairing_url)
    qr.make(fit=True)

    # Print ASCII QR code to terminal
    try:
        qr.print_ascii(tty=True)
    except OSError:
        qr.print_ascii(tty=False)


if __name__ == "__main__":
    main()
