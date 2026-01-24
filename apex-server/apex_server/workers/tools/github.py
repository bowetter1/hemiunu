"""GitHub tools for workers"""
from pathlib import Path
from apex_server.github import GitHubService


# Tool definitions for GitHub operations
GITHUB_TOOL_DEFINITIONS = [
    {
        "name": "git_init",
        "description": "Initialize a git repository in the project directory. Call this before making commits.",
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "git_commit",
        "description": "Add all changes and create a git commit with a message. Use this after completing a feature or fix.",
        "input_schema": {
            "type": "object",
            "properties": {
                "message": {
                    "type": "string",
                    "description": "Commit message describing the changes"
                }
            },
            "required": ["message"]
        }
    },
    {
        "name": "git_status",
        "description": "Check the current git status to see uncommitted changes.",
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "github_create_repo",
        "description": "Create a new GitHub repository and push the code. Use this when the project is ready to be published.",
        "input_schema": {
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Repository name (lowercase, hyphens allowed, no spaces)"
                },
                "description": {
                    "type": "string",
                    "description": "Short description of the project"
                }
            },
            "required": ["name"]
        }
    },
    {
        "name": "github_push",
        "description": "Push committed changes to the GitHub repository. Use this after making commits when the repo already exists.",
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    }
]


def execute_github_tool(project_dir: Path, tool_name: str, args: dict) -> str:
    """Execute a GitHub tool"""
    github = GitHubService(project_dir)

    if tool_name == "git_init":
        return github.init_repo()

    elif tool_name == "git_commit":
        message = args.get("message", "Update from Apex AI Team")
        return github.add_and_commit(message)

    elif tool_name == "git_status":
        return github.get_status()

    elif tool_name == "github_create_repo":
        if not github.is_configured():
            return "GitHub is not configured. Please set GITHUB_TOKEN in environment variables."

        name = args.get("name", "")
        if not name:
            return "Error: Repository name is required"

        # Clean up the name
        name = name.lower().replace(" ", "-").replace("_", "-")

        description = args.get("description", "Created by Apex AI Team")

        result = github.setup_and_push(name, description)

        if result["success"]:
            return f"Repository created and pushed!\n\nURL: {result['url']}\n\nSteps:\n" + "\n".join(f"- {s}" for s in result["steps"])
        else:
            steps_str = "\n".join(f"- {s}" for s in result.get("steps", []))
            return f"Failed to create repository: {result['error']}\n\nCompleted steps:\n{steps_str}"

    elif tool_name == "github_push":
        if not github.is_configured():
            return "GitHub is not configured. Please set GITHUB_TOKEN in environment variables."

        return github.push()

    return f"Unknown GitHub tool: {tool_name}"
