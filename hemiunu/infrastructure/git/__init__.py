"""
Git Infrastructure - Git-operationer.
"""
from .operations import (
    run_git,
    get_current_branch,
    branch_exists,
    create_branch,
    checkout_branch,
    checkout_main,
    commit_changes,
    push_branch,
    get_branch_status,
    get_uncommitted_changes
)
from .merge import (
    start_merge,
    get_conflict_files,
    get_conflict_content,
    resolve_file_conflict,
    abort_merge,
    complete_merge,
    get_file_from_branch
)

__all__ = [
    "run_git",
    "get_current_branch",
    "branch_exists",
    "create_branch",
    "checkout_branch",
    "checkout_main",
    "commit_changes",
    "push_branch",
    "get_branch_status",
    "get_uncommitted_changes",
    "start_merge",
    "get_conflict_files",
    "get_conflict_content",
    "resolve_file_conflict",
    "abort_merge",
    "complete_merge",
    "get_file_from_branch"
]
