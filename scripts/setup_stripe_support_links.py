#!/usr/bin/env python3
"""Create Stripe test Payment Links and write them to website/public/support.json."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUPPORT_JSON = ROOT / "website" / "public" / "support.json"
GITHUB_SPONSORS_DEFAULT = "https://github.com/sponsors/acburgess25"


def stripe_post(secret_key: str, path: str, data: dict[str, str]) -> dict:
    body = urllib.parse.urlencode(data).encode()
    request = urllib.request.Request(
        f"https://api.stripe.com/v1/{path}",
        data=body,
        headers={"Authorization": f"Bearer {secret_key}"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        raise SystemExit(f"Stripe API error ({error.code}): {detail}") from error


def load_support() -> dict[str, str]:
    if SUPPORT_JSON.exists():
        return json.loads(SUPPORT_JSON.read_text(encoding="utf-8"))
    return {
        "githubSponsors": GITHUB_SPONSORS_DEFAULT,
        "donateOneTime": "",
        "donateMonthly": "",
    }


def save_support(data: dict[str, str]) -> None:
    SUPPORT_JSON.parent.mkdir(parents=True, exist_ok=True)
    SUPPORT_JSON.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def create_payment_link(secret_key: str, product_name: str, unit_amount_cents: int, *, recurring: bool) -> str:
    product = stripe_post(
        secret_key,
        "products",
        {"name": product_name, "metadata[source]": "nobs-support-setup"},
    )
    price_data: dict[str, str] = {
        "product": product["id"],
        "currency": "usd",
        "unit_amount": str(unit_amount_cents),
    }
    if recurring:
        price_data["recurring[interval]"] = "month"
    price = stripe_post(secret_key, "prices", price_data)
    link = stripe_post(
        secret_key,
        "payment_links",
        {
            "line_items[0][price]": price["id"],
            "line_items[0][quantity]": "1",
            "allow_promotion_codes": "true",
        },
    )
    return link["url"]


def main() -> int:
    secret_key = os.environ.get("STRIPE_SECRET_KEY", "").strip()
    if not secret_key:
        print(
            "Set STRIPE_SECRET_KEY to a test secret (sk_test_…) from Stripe Dashboard → Developers → API keys.",
            file=sys.stderr,
        )
        return 1
    if not secret_key.startswith("sk_test_"):
        print("Refusing to run with a live secret key. Use sk_test_… for this helper.", file=sys.stderr)
        return 1

    one_time_cents = os.environ.get("NOBS_DONATE_ONETIME_CENTS", "500")
    monthly_cents = os.environ.get("NOBS_DONATE_MONTHLY_CENTS", "300")

    support = load_support()
    if not support.get("githubSponsors"):
        support["githubSponsors"] = GITHUB_SPONSORS_DEFAULT

    print("Creating one-time support link…")
    support["donateOneTime"] = create_payment_link(
        secret_key,
        "Support NOBS development (one-time)",
        int(one_time_cents),
        recurring=False,
    )
    print("Creating monthly support link…")
    support["donateMonthly"] = create_payment_link(
        secret_key,
        "Support NOBS development (monthly)",
        int(monthly_cents),
        recurring=True,
    )

    save_support(support)
    print(f"Updated {SUPPORT_JSON}")
    print(json.dumps(support, indent=2))
    print("\nRebuild and deploy the website:")
    print("  cd website && pnpm run build")
    print("  rsync -az --delete dist/ tank:~/services/nobsdash/current/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
