import sqlite3
import uuid
import datetime
from pathlib import Path

def main():
    db_path = Path("/home/alex/nobs/data/nobs-agent.db")
    if not db_path.exists():
        db_path = Path("data/nobs-agent.db") # fallback if run locally
    
    conn = sqlite3.connect(db_path)
    
    # Calculate time 1 minute from now in UTC
    now_utc = datetime.datetime.now(datetime.UTC)
    target_time = now_utc + datetime.timedelta(minutes=1)
    time_str = target_time.strftime("%H:%M")
    
    # Insert schedule
    schedule_id = str(uuid.uuid4())
    conn.execute(
        "INSERT INTO briefing_schedules VALUES (?, ?, ?, ?)",
        (schedule_id, time_str, "active", now_utc.isoformat())
    )
    
    # Insert some dummy calendar events
    conn.execute("DELETE FROM calendar_events")
    conn.execute(
        "INSERT INTO calendar_events VALUES (?, ?, ?, ?, ?)",
        (str(uuid.uuid4()), "Launch NOBS Dashboard", "10:00", "business", now_utc.isoformat())
    )
    conn.execute(
        "INSERT INTO calendar_events VALUES (?, ?, ?, ?, ?)",
        (str(uuid.uuid4()), "Review Agent Approvals", "14:00", "personal", now_utc.isoformat())
    )
    
    # Insert dummy reminders
    conn.execute("DELETE FROM reminders")
    conn.execute(
        "INSERT INTO reminders VALUES (?, ?, ?, ?)",
        (str(uuid.uuid4()), "Check Tank GPU temperatures", "business", now_utc.isoformat())
    )
    
    conn.commit()
    print(f"Created active schedule for {time_str} UTC with 2 events and 1 reminder!")

if __name__ == "__main__":
    main()
