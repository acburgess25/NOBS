"""NOBS connector library.

A declarative catalog of every service/app/place you might connect to. Each
entry describes what auth it needs, what it can do, and which NOBS skills it
unlocks. Connecting anything still happens behind the approval-first gate and
`send_requires_approval` is always on for these.

Adding a new connector = adding one declarative entry here (no other wiring).
The register endpoint stores it in `connectors`; live use needs the service's
OAuth client/credentials, which only the account owner can create.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass

# Categories the catalog is grouped by (the "library shelves").
CATEGORIES = [
    "accounts",       # identity / SSO providers
    "communication",  # chat, e-mail, teams
    "calendar",
    "productivity",   # notes, docs, drives
    "dev",            # code, git, APIs
    "media",
    "home",           # local/Apple devices (no auth)
    "skills",         # NOBS's own local skill library
]


@dataclass(frozen=True)
class Connector:
    name: str
    category: str
    auth_type: str  # oauth2 | api_key | token | none
    description: str = ""
    auth_url: str = ""
    # fine-grained scopes the connector would ask for
    scopes: tuple[str, ...] = ()
    # NOBS skill names enabled by connecting
    skills_enabled: tuple[str, ...] = ()
    # if a send-capable connector, sending always waits for approval
    send_capable: bool = False


AVAILABLE_CONNECTORS: tuple[Connector, ...] = (
    Connector(
        "google", "accounts", "oauth2",
        "Personal Google account — search, mail, calendar, drive.",
        "https://accounts.google.com/o/oauth2/v2/auth",
        ("openid", "email", "profile",
         "https://www.googleapis.com/auth/calendar",
         "https://www.googleapis.com/auth/gmail.send",
         "https://www.googleapis.com/auth/drive.file"),
        skills_enabled=("google-search", "calendar", "mail"),
        send_capable=True,
    ),
    Connector(
        "google_workspace", "accounts", "oauth2",
        "School or work Google Workspace account (same APIs, your other mailbox).",
        "https://accounts.google.com/o/oauth2/v2/auth",
        ("openid", "email", "profile",
         "https://www.googleapis.com/auth/calendar",
         "https://www.googleapis.com/auth/gmail.send",
         "https://www.googleapis.com/auth/drive.file"),
        skills_enabled=("school-calendar", "mail", "google-search"),
        send_capable=True,
    ),
    Connector(
        "outlook", "accounts", "oauth2",
        "Microsoft / Office 365 account (mail + calendar).",
        "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
        ("Mail.ReadWrite", "Calendars.ReadWrite", "User.Read"),
        skills_enabled=("mail", "calendar"),
        send_capable=True,
    ),
    Connector(
        "mail", "communication", "oauth2",
        "E-mail inbox (Gmail or Outlook). Read + compose; sending waits for approval.",
        "https://mail.google.com/",
        ("gmail.send", "gmail.readonly"),
        skills_enabled=("mail",),
        send_capable=True,
    ),
    Connector(
        "calendar", "calendar", "oauth2",
        "Calendar events — read, propose, schedule (writes wait for approval).",
        "https://www.google.com/calendar/",
        ("https://www.googleapis.com/auth/calendar"),
        skills_enabled=("calendar",),
        send_capable=True,
    ),
    Connector(
        "drive", "productivity", "oauth2",
        "Google Drive files — search and read; file writes wait for approval.",
        "https://www.google.com/drive/",
        ("https://www.googleapis.com/auth/drive.file",),
        skills_enabled=("docs",),
    ),
    Connector(
        "slack", "communication", "oauth2",
        "Team chat — read channels; posts wait for approval.",
        "https://slack.com/oauth/v2/authorize",
        ("channels:read", "chat:write", "users:read"),
        skills_enabled=("team-updates",),
        send_capable=True,
    ),
    Connector(
        "notion", "productivity", "oauth2",
        "Notes, docs, and databases.",
        "https://api.notion.com/v1/oauth/authorize",
        (),
        skills_enabled=("notes", "docs"),
    ),
    Connector(
        "github", "dev", "oauth2",
        "Code, repos, issues, and gists (reads; pushes wait for approval).",
        "https://github.com/login/oauth/authorize",
        ("repo", "gist", "workflow"),
        skills_enabled=("git", "coding"),
        send_capable=True,
    ),
    Connector(
        "spotify", "media", "oauth2",
        "Music — read your library; playlist changes wait for approval.",
        "https://accounts.spotify.com/authorize",
        ("user-library-read", "playlist-modify-public"),
        skills_enabled=("music",),
        send_capable=True,
    ),
    Connector(
        "homekit", "home", "none",
        "Apple Home devices — local control (no external auth).",
        "",
        (),
        skills_enabled=("home",),
    ),
    Connector(
        "skills", "skills", "none",
        "NOBS's own local skill library — no external login; activated locally.",
        "",
        (),
        skills_enabled=("auto-improve",),
    ),
)


def _public(c: Connector) -> dict[str, object]:
    d = asdict(c)
    return d


def catalog() -> list[dict[str, object]]:
    return [_public(c) for c in AVAILABLE_CONNECTORS]


def catalog_by_category() -> dict[str, list[dict[str, object]]]:
    grouped = {cat: [] for cat in CATEGORIES}
    for c in AVAILABLE_CONNECTORS:
        grouped.setdefault(c.category, []).append(_public(c))
    return grouped


def search(query: str) -> list[dict[str, object]]:
    q = (query or "").strip().lower()
    if not q:
        return catalog()
    return [
        _public(c)
        for c in AVAILABLE_CONNECTORS
        if q in c.name.lower()
        or q in c.category.lower()
        or q in c.description.lower()
        or any(q in s.lower() for s in c.skills_enabled)
    ]


def get(name: str) -> dict[str, object] | None:
    for c in AVAILABLE_CONNECTORS:
        if c.name == name:
            return _public(c)
    return None