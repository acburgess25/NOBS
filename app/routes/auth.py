"""Pairing an Apple identity to this Tank.

This is the one route that hands out the device token, so it is the boundary
that decides who owns the Tank. It is unauthenticated by necessity -- a device
with no token has to be able to ask -- which is why claiming an unpaired Tank
additionally requires a pairing window opened at the Tank itself.
"""

from __future__ import annotations

import secrets

from fastapi import APIRouter, HTTPException, status

from app.dependencies import PairingDep, SettingsDep, StoreDep, resolve_device_token
from app.schemas import AppleAuthRequest, AppleAuthResponse

router = APIRouter()


@router.post(
    "/auth/apple",
    response_model=AppleAuthResponse,
    tags=["auth"],
    summary="Exchange an Apple user identifier for a Tank device token",
)
async def auth_apple(
    request: AppleAuthRequest,
    settings: SettingsDep,
    store: StoreDep,
    pairing: PairingDep,
) -> AppleAuthResponse:
    """
    Bootstrap endpoint — no device token required.

    Claiming an unpaired Tank additionally requires a pairing window opened
    on the Tank itself, because an Apple user identifier travels inside this
    request and so proves nothing on its own. Without that gate the first
    caller to reach the port would own the Tank.

    Once paired, the registered Apple user gets the same token back and any
    other user ID is rejected.
    """
    registered = store.get_kv("apple_user_identifier")

    if registered is None:
        if not pairing.is_open():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "This Tank is not open for pairing. Open pairing on the "
                    "Tank display, then sign in again."
                ),
            )
        # First pairing — register this Apple user and spend the window so a
        # single opening cannot be reused to claim the Tank twice.
        store.set_kv("apple_user_identifier", request.user_identifier)
        pairing.close()
    elif registered != request.user_identifier:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This Tank is already paired to a different Apple ID.",
        )

    token = resolve_device_token(settings, store)
    if not token:
        token = secrets.token_urlsafe(32)
        store.set_kv("device_token", token)
    return AppleAuthResponse(device_token=token)
