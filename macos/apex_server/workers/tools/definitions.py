"""Tool definitions - JSON schemas for LLM tool calling"""

# Worker enum for delegation tools
WORKER_ENUM = ["ad", "architect", "backend", "frontend", "tester", "reviewer", "devops", "security"]

TOOL_DEFINITIONS = [
    # === FILE OPERATIONS ===
    {
        "name": "write_file",
        "description": "Write content to a file. Creates directories if needed.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "File path (relative to project)"},
                "content": {"type": "string", "description": "Content to write"}
            },
            "required": ["path", "content"]
        }
    },
    {
        "name": "read_file",
        "description": "Read a file from the project.",
        "input_schema": {
            "type": "object",
            "properties": {
                "file": {"type": "string", "description": "File path (relative to project)"}
            },
            "required": ["file"]
        }
    },
    {
        "name": "list_files",
        "description": "List all files in the project directory.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Subdirectory to list", "default": "."}
            }
        }
    },
    {
        "name": "run_command",
        "description": "Run a shell command. Allowed: git, ls, cat, echo, mkdir, touch, npm, node, python, pip, pytest, curl",
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {"type": "string", "description": "Command to run"}
            },
            "required": ["command"]
        }
    },

    # === DELEGATION TOOLS (Chef only) ===
    {
        "name": "assign_ad",
        "description": "Assign task to AD (Art Director). Good for design guidelines, UX, colors, typography.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "Design task"},
                "context": {"type": "string", "description": "Extra context about the project"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_architect",
        "description": "Assign task to Architect. Good for planning, structure, technical design.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "Planning task"},
                "context": {"type": "string", "description": "Extra context"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_backend",
        "description": "Assign task to Backend developer. Builds API that frontend uses. RUN FIRST!",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "What to build?"},
                "file": {"type": "string", "description": "Which file? (e.g. main.py)"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_frontend",
        "description": "Assign task to Frontend developer. Builds against EXISTING API. Run AFTER backend!",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "What to build?"},
                "file": {"type": "string", "description": "Which file? (e.g. index.html, app.js)"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_tester",
        "description": "Tester WRITES test files (test_*.py). Run BEFORE run_tests()!",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "What to test? E.g. 'Write tests for API endpoints'"},
                "context": {"type": "string", "description": "Extra context"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_reviewer",
        "description": "Ask Reviewer to review code.",
        "input_schema": {
            "type": "object",
            "properties": {
                "files_to_review": {"type": "array", "items": {"type": "string"}, "description": "Files to review"},
                "focus": {"type": "string", "description": "What to focus on?"}
            },
            "required": ["files_to_review"]
        }
    },
    {
        "name": "assign_devops",
        "description": "Assign task to DevOps. Good for infra, CI/CD, config, monitoring.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "DevOps task"},
                "context": {"type": "string", "description": "Extra context"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_security",
        "description": "Security audit - OWASP vulnerabilities, auth, input validation, secrets exposure.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "Security audit task"},
                "context": {"type": "string", "description": "Extra context"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_parallel",
        "description": "Run MULTIPLE workers SIMULTANEOUSLY. Perfect for independent tasks like AD + Architect.",
        "input_schema": {
            "type": "object",
            "properties": {
                "assignments": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "worker": {"type": "string", "enum": WORKER_ENUM, "description": "Which worker"},
                            "task": {"type": "string", "description": "The task"},
                            "context": {"type": "string", "description": "Extra context (optional)"},
                            "file": {"type": "string", "description": "File to work with (optional)"}
                        },
                        "required": ["worker", "task"]
                    },
                    "description": "List of assignments [{worker, task, context?, file?}]"
                }
            },
            "required": ["assignments"]
        }
    },

    # === COMMUNICATION TOOLS ===
    {
        "name": "thinking",
        "description": "Log your thoughts. ALWAYS USE before and after every action!",
        "input_schema": {
            "type": "object",
            "properties": {
                "thought": {"type": "string", "description": "Your thought process"}
            },
            "required": ["thought"]
        }
    },
    {
        "name": "talk_to",
        "description": "Talk freely to a worker. Has MEMORY - continues previous session!",
        "input_schema": {
            "type": "object",
            "properties": {
                "worker": {"type": "string", "enum": WORKER_ENUM},
                "message": {"type": "string"}
            },
            "required": ["worker", "message"]
        }
    },
    {
        "name": "reassign_with_feedback",
        "description": "Send back task with feedback. Worker remembers what they did!",
        "input_schema": {
            "type": "object",
            "properties": {
                "worker": {"type": "string", "enum": WORKER_ENUM},
                "task": {"type": "string"},
                "feedback": {"type": "string"}
            },
            "required": ["worker", "task", "feedback"]
        }
    },

    # === MEETING TOOLS ===
    {
        "name": "team_kickoff",
        "description": "Kickoff meeting: PRESENT the plan to the team.",
        "input_schema": {
            "type": "object",
            "properties": {
                "vision": {"type": "string", "description": "What are we building? Why?"},
                "goals": {"type": "array", "items": {"type": "string"}, "description": "Sprint goals"},
                "plan_summary": {"type": "string", "description": "Summary of architect's plan"}
            },
            "required": ["vision", "goals"]
        }
    },
    {
        "name": "sprint_planning",
        "description": "Start a new sprint with specific features.",
        "input_schema": {
            "type": "object",
            "properties": {
                "sprint_name": {"type": "string", "description": "Sprint name, e.g. 'Sprint 1: Setup'"},
                "features": {"type": "array", "items": {"type": "string"}, "description": "Features to build"}
            },
            "required": ["sprint_name", "features"]
        }
    },
    {
        "name": "team_demo",
        "description": "Demo meeting: Show what was built.",
        "input_schema": {
            "type": "object",
            "properties": {
                "what_was_built": {"type": "string", "description": "Short description of what was built"},
                "files_created": {"type": "array", "items": {"type": "string"}, "description": "List of files created"}
            },
            "required": ["what_was_built"]
        }
    },
    {
        "name": "team_retrospective",
        "description": "Retrospective: Reflect on the sprint.",
        "input_schema": {
            "type": "object",
            "properties": {
                "went_well": {"type": "array", "items": {"type": "string"}, "description": "What went well?"},
                "could_improve": {"type": "array", "items": {"type": "string"}, "description": "What could improve?"},
                "learnings": {"type": "string", "description": "What did we learn?"},
                "live_url": {"type": "string", "description": "URL to live app (if deployed)"}
            },
            "required": ["went_well", "could_improve"]
        }
    },

    # === TESTING & QA TOOLS ===
    {
        "name": "run_tests",
        "description": "RUN existing tests (pytest, npm test). Use assign_tester() FIRST to WRITE tests!",
        "input_schema": {
            "type": "object",
            "properties": {
                "framework": {
                    "type": "string",
                    "enum": ["auto", "pytest", "npm", "bun", "go"],
                    "description": "Test framework (auto = detect automatically)"
                },
                "path": {"type": "string", "description": "Specific file/folder to test"},
                "verbose": {"type": "boolean", "description": "Show detailed output"}
            }
        }
    },
    {
        "name": "run_lint",
        "description": "Run linting for code quality (ruff, flake8, eslint).",
        "input_schema": {
            "type": "object",
            "properties": {
                "framework": {
                    "type": "string",
                    "enum": ["auto", "ruff", "flake8", "eslint", "prettier"],
                    "description": "Lint tool (auto = detect automatically)"
                },
                "path": {"type": "string", "description": "Specific file/folder to lint"},
                "fix": {"type": "boolean", "description": "Try to fix automatically"}
            }
        }
    },
    {
        "name": "run_typecheck",
        "description": "Run type checking (mypy, pyright, tsc).",
        "input_schema": {
            "type": "object",
            "properties": {
                "framework": {
                    "type": "string",
                    "enum": ["auto", "mypy", "pyright", "tsc"],
                    "description": "Type checker (auto = detect automatically)"
                },
                "path": {"type": "string", "description": "Specific file/folder to check"}
            }
        }
    },
    {
        "name": "run_qa",
        "description": "Run full QA: tests + lint + typecheck.",
        "input_schema": {
            "type": "object",
            "properties": {
                "focus": {"type": "string", "description": "What to focus on"}
            }
        }
    },

    # === DEPLOY TOOLS ===
    {
        "name": "check_railway_status",
        "description": "Check Railway deployment status.",
        "input_schema": {"type": "object", "properties": {}}
    },
    {
        "name": "deploy_railway",
        "description": "Deploy the project to Railway.",
        "input_schema": {
            "type": "object",
            "properties": {
                "with_database": {
                    "type": "string",
                    "enum": ["none", "postgres", "mongo"],
                    "description": "Add database service"
                }
            }
        }
    },
    {
        "name": "create_deploy_files",
        "description": "Create Dockerfile, railway.toml, Procfile, requirements.txt from templates.",
        "input_schema": {
            "type": "object",
            "properties": {
                "db": {
                    "type": "string",
                    "enum": ["none", "postgres", "mongo", "sqlite"],
                    "description": "Database type"
                },
                "extra_deps": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Extra pip dependencies"
                }
            }
        }
    },
    {
        "name": "start_dev_server",
        "description": "Start development server (uvicorn on localhost:8000).",
        "input_schema": {
            "type": "object",
            "properties": {
                "port": {"type": "integer", "description": "Port (default 8000)"}
            }
        }
    },
    {
        "name": "stop_dev_server",
        "description": "Stop the development server.",
        "input_schema": {"type": "object", "properties": {}}
    },
    {
        "name": "open_browser",
        "description": "Open an HTML file in the browser.",
        "input_schema": {
            "type": "object",
            "properties": {
                "file": {"type": "string", "description": "File to open (default: index.html)"}
            }
        }
    },

    # === USER INTERACTION TOOLS ===
    {
        "name": "ask_user",
        "description": "Ask the user a question. Use when you need clarification, preferences, or a decision. The sprint will pause until the user responds.",
        "input_schema": {
            "type": "object",
            "properties": {
                "question": {"type": "string", "description": "The question to ask the user"},
                "options": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Optional pre-defined answer options (buttons). If empty, user can type freely."
                }
            },
            "required": ["question"]
        }
    },

    # === COORDINATION TOOLS ===
    {
        "name": "check_needs",
        "description": "Check CONTEXT.md for any NEEDS (blockers) from workers. Returns pending items that need resolution.",
        "input_schema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "checkin_worker",
        "description": "Quick check-in with a worker. Ask them a specific question with memory of previous work. Good for status updates or clarifications.",
        "input_schema": {
            "type": "object",
            "properties": {
                "worker": {"type": "string", "enum": WORKER_ENUM, "description": "Which worker to check in with"},
                "question": {"type": "string", "description": "The question to ask"}
            },
            "required": ["worker", "question"]
        }
    },

    # === BOSS/DECISION TOOLS ===
    {
        "name": "log_decision",
        "description": "Document an important decision for future reference.",
        "input_schema": {
            "type": "object",
            "properties": {
                "decision": {"type": "string", "description": "What was decided?"},
                "reason": {"type": "string", "description": "Why?"}
            },
            "required": ["decision", "reason"]
        }
    },
    {
        "name": "get_decisions",
        "description": "Get logged decisions for the project.",
        "input_schema": {
            "type": "object",
            "properties": {
                "limit": {"type": "integer", "description": "Max number to show (default 10)"}
            }
        }
    },
    {
        "name": "summarize_progress",
        "description": "Summarize the project's progress - files, decisions, status.",
        "input_schema": {"type": "object", "properties": {}}
    },
]
