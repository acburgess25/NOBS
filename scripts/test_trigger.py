import asyncio
from pathlib import Path
from app.config import get_settings
from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.scheduler import trigger_autonomous_idea

async def main():
    settings = get_settings()
    settings.agent_database_path = Path("/home/alex/nobs/data/nobs-agent.db")
    store = AgentStore(settings.agent_database_path)
    tools = ToolRegistry(workspace=settings.agent_workspace_path, project=settings.agent_project_path, store=store)
    
    print("Triggering autonomous idea...")
    await trigger_autonomous_idea(settings, store, tools, None)
    print("Done!")
    
    # Check runs
    runs = store.list_runs()
    print("Runs:", runs)

if __name__ == "__main__":
    asyncio.run(main())
