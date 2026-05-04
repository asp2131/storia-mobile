#!/usr/bin/env python3
"""Small Linear CLI for the Storia Mobile project.

Uses LINEAR_API_KEY from the environment. No third-party dependencies.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import textwrap
import urllib.error
import urllib.request
from typing import Any

API_URL = "https://api.linear.app/graphql"
DEFAULT_PROJECT_SLUG = "storia-web-b2f648c17c65"
DEFAULT_FIRST = 25


class LinearError(RuntimeError):
    pass


def gql(query: str, variables: dict[str, Any] | None = None) -> dict[str, Any]:
    api_key = os.environ.get("LINEAR_API_KEY")
    if not api_key:
        raise LinearError("LINEAR_API_KEY is not set")

    payload = json.dumps({"query": query, "variables": variables or {}}).encode()
    req = urllib.request.Request(
        API_URL,
        data=payload,
        headers={
            "Authorization": api_key,
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="replace")
        raise LinearError(f"Linear HTTP {exc.code}: {body}") from exc
    except urllib.error.URLError as exc:
        raise LinearError(f"Linear request failed: {exc.reason}") from exc

    data = json.loads(body)
    if data.get("errors"):
        messages = "; ".join(str(err.get("message", err)) for err in data["errors"])
        raise LinearError(messages)
    return data["data"]


def project_slug(args: argparse.Namespace) -> str:
    return args.project or os.environ.get("LINEAR_PROJECT_SLUG") or DEFAULT_PROJECT_SLUG


def compact_issue_fields() -> str:
    return """
      id
      identifier
      title
      description
      url
      priority
      createdAt
      updatedAt
      state { id name type }
      team { id key name }
      project { id name slugId }
      assignee { id name email }
      labels(first: 20) { nodes { id name } }
    """


def resolve_project(slug: str) -> dict[str, Any]:
    query = """
    query($slug: String!) {
      project(id: $slug) {
        id
        name
        slugId
        teams(first: 10) {
          nodes {
            id
            key
            name
            states(first: 50) { nodes { id name type } }
          }
        }
      }
    }
    """
    project = gql(query, {"slug": slug})["project"]
    if not project:
        raise LinearError(f"Could not resolve Linear project: {slug}")
    if not project["teams"]["nodes"]:
        raise LinearError(f"Project has no teams: {slug}")
    return project


def find_state_id(states: list[dict[str, Any]], name: str) -> str:
    for state in states:
        if state["name"].lower() == name.lower():
            return state["id"]
    available = ", ".join(state["name"] for state in states)
    raise LinearError(f"State '{name}' not found. Available states: {available}")


def fetch_issue(identifier: str) -> dict[str, Any]:
    query = f"""
    query($id: String!) {{
      issue(id: $id) {{
        {compact_issue_fields()}
        comments(first: 10, orderBy: updatedAt) {{
          nodes {{ id body createdAt user {{ name email }} }}
        }}
      }}
    }}
    """
    issue = gql(query, {"id": identifier})["issue"]
    if not issue:
        raise LinearError(f"Issue not found: {identifier}")
    return issue


def list_issues(args: argparse.Namespace) -> list[dict[str, Any]]:
    project = resolve_project(project_slug(args))
    filters: dict[str, Any] = {"project": {"id": {"eq": project["id"]}}}
    if args.state:
        filters["state"] = {"name": {"eq": args.state}}
    if args.query:
        filters["or"] = [
            {"title": {"containsIgnoreCase": args.query}},
            {"description": {"containsIgnoreCase": args.query}},
        ]

    query = f"""
    query($filter: IssueFilter, $first: Int!) {{
      issues(filter: $filter, first: $first, orderBy: updatedAt) {{
        nodes {{ {compact_issue_fields()} }}
      }}
    }}
    """
    return gql(query, {"filter": filters, "first": args.first})["issues"]["nodes"]


def create_issue(args: argparse.Namespace) -> dict[str, Any]:
    project = resolve_project(project_slug(args))
    team = project["teams"]["nodes"][0]
    input_data: dict[str, Any] = {
        "teamId": team["id"],
        "projectId": project["id"],
        "title": args.title,
    }
    if args.description:
        input_data["description"] = args.description
    if args.state:
        input_data["stateId"] = find_state_id(team["states"]["nodes"], args.state)
    if args.assignee_id:
        input_data["assigneeId"] = args.assignee_id

    query = f"""
    mutation($input: IssueCreateInput!) {{
      issueCreate(input: $input) {{
        success
        issue {{ {compact_issue_fields()} }}
      }}
    }}
    """
    result = gql(query, {"input": input_data})["issueCreate"]
    if not result["success"]:
        raise LinearError("Linear issueCreate returned success=false")
    return result["issue"]


def update_issue(args: argparse.Namespace) -> dict[str, Any]:
    issue = fetch_issue(args.identifier)
    input_data: dict[str, Any] = {}
    if args.title is not None:
        input_data["title"] = args.title
    if args.description is not None:
        input_data["description"] = args.description
    if args.state is not None:
        states = team_states(issue["team"]["id"])
        input_data["stateId"] = find_state_id(states, args.state)
    if args.assignee_id is not None:
        input_data["assigneeId"] = args.assignee_id
    if not input_data and not args.comment:
        raise LinearError("Nothing to update; pass --title, --description, --state, --assignee-id, or --comment")

    updated = issue
    if input_data:
        query = f"""
        mutation($id: String!, $input: IssueUpdateInput!) {{
          issueUpdate(id: $id, input: $input) {{
            success
            issue {{ {compact_issue_fields()} }}
          }}
        }}
        """
        result = gql(query, {"id": issue["id"], "input": input_data})["issueUpdate"]
        if not result["success"]:
            raise LinearError("Linear issueUpdate returned success=false")
        updated = result["issue"]

    if args.comment:
        add_comment(updated["id"], args.comment)
    return fetch_issue(updated["identifier"])


def team_states(team_id: str) -> list[dict[str, Any]]:
    query = """
    query($id: String!) {
      team(id: $id) { states(first: 50) { nodes { id name type } } }
    }
    """
    team = gql(query, {"id": team_id})["team"]
    if not team:
        raise LinearError(f"Team not found: {team_id}")
    return team["states"]["nodes"]


def add_comment(issue_id: str, body: str) -> None:
    query = """
    mutation($input: CommentCreateInput!) {
      commentCreate(input: $input) { success comment { id } }
    }
    """
    result = gql(query, {"input": {"issueId": issue_id, "body": body}})["commentCreate"]
    if not result["success"]:
        raise LinearError("Linear commentCreate returned success=false")


def print_issue(issue: dict[str, Any]) -> None:
    print(f"{issue['identifier']}: {issue['title']}")
    print(f"URL: {issue['url']}")
    print(f"State: {issue['state']['name']} | Project: {issue.get('project', {}).get('name', 'n/a')}")
    assignee = issue.get("assignee")
    print(f"Assignee: {assignee['name'] if assignee else 'Unassigned'}")
    labels = [label["name"] for label in issue.get("labels", {}).get("nodes", [])]
    if labels:
        print(f"Labels: {', '.join(labels)}")
    description = issue.get("description") or ""
    if description:
        print("\nDescription:\n" + textwrap.indent(description, "  "))
    comments = issue.get("comments", {}).get("nodes", [])
    if comments:
        print("\nRecent comments:")
        for comment in comments:
            author = comment.get("user") or {}
            first_line = (comment.get("body") or "").strip().splitlines()[0:1]
            preview = first_line[0] if first_line else ""
            print(f"- {comment['createdAt']} {author.get('name', 'Unknown')}: {preview}")


def print_issue_table(issues: list[dict[str, Any]]) -> None:
    for issue in issues:
        print(f"{issue['identifier']:<10} {issue['state']['name']:<14} {issue['title']}")


def maybe_print(data: Any, as_json: bool, list_output: bool = False) -> None:
    if as_json:
        print(json.dumps(data, indent=2, sort_keys=True))
    elif isinstance(data, list) or list_output:
        print_issue_table(data)
    else:
        print_issue(data)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Create, view, and update Storia Mobile Linear tickets using LINEAR_API_KEY.",
    )
    parser.add_argument(
        "--project",
        help=f"Linear project slug/id (default: LINEAR_PROJECT_SLUG or {DEFAULT_PROJECT_SLUG})",
    )
    parser.add_argument("--json", action="store_true", help="Print raw JSON output")
    sub = parser.add_subparsers(dest="command", required=True)

    create = sub.add_parser("create", help="Create a ticket in the Storia Mobile Linear project")
    create.add_argument("--title", required=True)
    create.add_argument("--description", default="")
    create.add_argument("--state", help="Workflow state name, e.g. Backlog or Todo")
    create.add_argument("--assignee-id", help="Linear user ID to assign")

    view = sub.add_parser("view", help="View one ticket by identifier or UUID")
    view.add_argument("identifier", help="Example: STO-123")

    list_cmd = sub.add_parser("list", help="List recent tickets in the Storia Mobile project")
    list_cmd.add_argument("--state", help="Filter by workflow state name")
    list_cmd.add_argument("--query", help="Case-insensitive search in title/description")
    list_cmd.add_argument("--first", type=int, default=DEFAULT_FIRST, help="Max issues to fetch")

    update = sub.add_parser("update", help="Update a ticket by identifier or UUID")
    update.add_argument("identifier", help="Example: STO-123")
    update.add_argument("--title")
    update.add_argument("--description")
    update.add_argument("--state", help="Workflow state name, e.g. In Progress or In Review")
    update.add_argument("--assignee-id", help="Linear user ID to assign")
    update.add_argument("--comment", help="Append a comment after updating fields")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if args.command == "create":
            maybe_print(create_issue(args), args.json)
        elif args.command == "view":
            maybe_print(fetch_issue(args.identifier), args.json)
        elif args.command == "list":
            maybe_print(list_issues(args), args.json, list_output=True)
        elif args.command == "update":
            maybe_print(update_issue(args), args.json)
        else:  # pragma: no cover
            parser.error(f"Unknown command: {args.command}")
    except LinearError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
