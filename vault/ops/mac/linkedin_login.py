#!/usr/bin/env python3
"""
LinkedIn session capture for NOBS Agent.

Runs a headed Chromium browser on your Mac, lets you log in to LinkedIn
manually, then saves the session cookies to Tank automatically.

Usage:
    python3 linkedin_login.py
"""

import asyncio
import json
import subprocess
from pathlib import Path

SESSION_FILE = Path("/tmp/linkedin_state.json")
TANK_DEST    = "tank:/opt/homelab/data/sessions/linkedin/state.json"


async def capture_session() -> None:
    from playwright.async_api import async_playwright

    print("\n🔐 Opening LinkedIn in a browser window...")
    print("   Log in normally, complete any 2FA, then come back here.\n")

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(
            headless=False,
            args=["--start-maximized"],
        )
        ctx = await browser.new_context(
            viewport=None,  # use full window
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            ),
        )
        page = await ctx.new_page()
        await page.goto("https://www.linkedin.com/login")

        print("⏳ Waiting for you to log in...")
        print("   (The script will auto-continue once it sees you're logged in)\n")

        # Wait until we're redirected away from /login — means logged in
        for _ in range(120):  # wait up to 2 minutes
            await asyncio.sleep(1)
            url = page.url
            if "linkedin.com/feed" in url or "linkedin.com/in/" in url or "linkedin.com/home" in url:
                print(f"✅ Logged in! Detected: {url}")
                break
            if "checkpoint" in url or "challenge" in url:
                print(f"⚠️  Security check detected at: {url}")
                print("   Complete it in the browser, then wait...")
        else:
            print("⏰ Timed out waiting for login. Try again.")
            await browser.close()
            return

        # Extra pause to let any post-login redirects settle
        await asyncio.sleep(3)

        # Save full browser storage state (cookies + localStorage)
        await ctx.storage_state(path=str(SESSION_FILE))
        await browser.close()

    print(f"\n💾 Session saved to {SESSION_FILE}")

    # Upload to Tank
    print(f"📤 Uploading session to Tank...")
    result = subprocess.run(
        ["ssh", "tank", "mkdir -p /opt/homelab/data/sessions/linkedin"],
        capture_output=True,
    )
    result = subprocess.run(
        ["scp", str(SESSION_FILE), TANK_DEST],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        print("✅ Session uploaded to Tank successfully!")
        print("\n🤖 The agent will now use your LinkedIn session for job scanning.")
        print("   Next scan runs within the hour. Check ntfy for proposals!\n")
    else:
        print(f"❌ Upload failed: {result.stderr}")
        print(f"   You can manually run: scp {SESSION_FILE} {TANK_DEST}")


if __name__ == "__main__":
    # Check playwright is installed
    try:
        import playwright  # noqa: F401
    except ImportError:
        print("Installing playwright...")
        subprocess.run(["pip3", "install", "playwright"], check=True)
        subprocess.run(["python3", "-m", "playwright", "install", "chromium"], check=True)

    asyncio.run(capture_session())
