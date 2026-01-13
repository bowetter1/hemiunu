"""FactGrid CLI main module."""

import json
from typing import Optional

import typer
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.json import JSON
from rich import print as rprint

from factgrid.cli.client import FactGridClient, DEFAULT_BASE_URL

# Map NewsAPI categories to display topics
CATEGORY_TO_TOPIC = {
    "business": "Economy",
    "economy": "Economy",
    "finance": "Economy",
    "technology": "Technology",
    "tech": "Technology",
    "science": "Technology",
    "politics": "Politics",
    "government": "Politics",
    "health": "Health",
    "sports": "Social",
    "entertainment": "Social",
    "environment": "Environment",
    "general": "Other",
}

app = typer.Typer(
    name="factgrid",
    help="CLI for FactGrid API - AI-driven news fact separation",
    add_completion=False,
)
console = Console()


def get_client(base_url: str) -> FactGridClient:
    """Create API client."""
    return FactGridClient(base_url=base_url)


@app.command()
def health(
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
):
    """Check API health status."""
    client = get_client(base_url)
    try:
        result = client.health()
        if result.get("status") == "ok":
            console.print(Panel(
                f"[green]Status: {result['status']}[/green]\n"
                f"Timestamp: {result.get('timestamp', 'N/A')}",
                title="Health Check",
                border_style="green",
            ))
        else:
            console.print(Panel(
                f"[red]Status: {result.get('status', 'unknown')}[/red]",
                title="Health Check",
                border_style="red",
            ))
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command()
def ingest(
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
    store_raw: bool = typer.Option(True, "--store/--no-store", help="Store raw payload"),
):
    """Fetch news articles from NewsAPI."""
    client = get_client(base_url)
    try:
        with console.status("[bold blue]Fetching news..."):
            result = client.ingest(store_raw=store_raw)

        console.print(Panel(
            f"[green]{result.get('message', 'Success')}[/green]\n"
            f"Articles fetched: [bold]{result.get('articles_fetched', 0)}[/bold]\n"
            f"Raw payload ID: {result.get('raw_payload_id', 'N/A')}",
            title="Ingest Result",
            border_style="green",
        ))
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command()
def judge(
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
):
    """Fetch news, judge with AI, and store in database."""
    client = get_client(base_url)
    try:
        with console.status("[bold blue]Judging articles with AI..."):
            result = client.judge()

        console.print(Panel(
            f"[green]{result.get('message', 'Success')}[/green]\n"
            f"Articles judged: [bold]{result.get('articles_judged', 0)}[/bold]",
            title="Judge Result",
            border_style="green",
        ))

        if result.get("article_ids"):
            console.print("\n[bold]Article IDs:[/bold]")
            for aid in result["article_ids"][:5]:
                console.print(f"  • {aid[:16]}...")
            if len(result["article_ids"]) > 5:
                console.print(f"  ... and {len(result['article_ids']) - 5} more")
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command()
def pipeline(
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
):
    """Run full pipeline: ingest -> judge -> store."""
    client = get_client(base_url)
    try:
        with console.status("[bold blue]Running full pipeline..."):
            result = client.pipeline()

        console.print(Panel(
            f"[green]{result.get('message', 'Success')}[/green]\n"
            f"Articles fetched: [bold]{result.get('articles_fetched', 0)}[/bold]\n"
            f"Articles judged: [bold]{result.get('articles_judged', 0)}[/bold]",
            title="Pipeline Result",
            border_style="green",
        ))
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("list")
def list_articles(
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
    limit: int = typer.Option(10, "--limit", "-l", help="Number of articles"),
    skip: int = typer.Option(0, "--skip", "-s", help="Skip N articles"),
):
    """List all articles."""
    client = get_client(base_url)
    try:
        with console.status("[bold blue]Fetching articles..."):
            articles = client.list_articles(limit=limit, skip=skip)

        if not articles:
            console.print("[yellow]No articles found.[/yellow]")
            return

        table = Table(title=f"Articles ({len(articles)} results)")
        table.add_column("ID", style="dim", width=12)
        table.add_column("Title", width=40)
        table.add_column("Source", width=15)
        table.add_column("Ver", justify="center", width=4)
        table.add_column("Grid", justify="center", width=6)

        for article in articles:
            meta = article.get("article_metadata", {})
            state = article.get("current_state", {})
            grid_count = len(state.get("grid", []))

            table.add_row(
                article.get("id", "")[:12],
                (meta.get("title", "")[:38] + "..") if len(meta.get("title", "")) > 40 else meta.get("title", ""),
                meta.get("source", "")[:15],
                str(state.get("version", 1)),
                str(grid_count),
            )

        console.print(table)
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("get")
def get_article(
    article_id: str = typer.Argument(..., help="Article ID"),
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
    show_json: bool = typer.Option(False, "--json", "-j", help="Show raw JSON"),
):
    """Get a specific article by ID."""
    client = get_client(base_url)
    try:
        with console.status("[bold blue]Fetching article..."):
            article = client.get_article(article_id)

        if show_json:
            console.print(JSON(json.dumps(article, indent=2)))
            return

        meta = article.get("article_metadata", {})
        state = article.get("current_state", {})

        # Article info
        console.print(Panel(
            f"[bold]{meta.get('title', 'No title')}[/bold]\n\n"
            f"Source: {meta.get('source', 'N/A')}\n"
            f"Topic: {meta.get('topic', 'N/A')}\n"
            f"URL: {meta.get('original_url', 'N/A')}\n"
            f"Version: {state.get('version', 1)}\n"
            f"Last updated: {state.get('last_updated', 'N/A')}",
            title=f"Article: {article_id[:16]}...",
            border_style="blue",
        ))

        # Grid
        grid = state.get("grid", [])
        if grid:
            table = Table(title="Fact Grid")
            table.add_column("Type", width=8)
            table.add_column("Content", width=50)
            table.add_column("Conf", justify="right", width=6)
            table.add_column("Status", width=10)

            for row in grid:
                type_color = {
                    "FACT": "green",
                    "OPINION": "yellow",
                    "QUOTE": "cyan",
                }.get(row.get("type", ""), "white")

                status_color = "green" if row.get("status") == "VERIFIED" else "yellow"

                table.add_row(
                    f"[{type_color}]{row.get('type', '')}[/{type_color}]",
                    row.get("content", "")[:48] + ".." if len(row.get("content", "")) > 50 else row.get("content", ""),
                    f"{row.get('confidence', 0):.2f}",
                    f"[{status_color}]{row.get('status', '')}[/{status_color}]",
                )

            console.print(table)
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("history")
def get_history(
    article_id: str = typer.Argument(..., help="Article ID"),
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
):
    """Get version history for an article."""
    client = get_client(base_url)
    try:
        with console.status("[bold blue]Fetching history..."):
            result = client.get_article_history(article_id)

        console.print(Panel(
            f"Article: {result.get('article_id', '')[:16]}...\n"
            f"Current version: [bold]{result.get('current_version', 0)}[/bold]",
            title="Article History",
            border_style="blue",
        ))

        history = result.get("history", [])
        if history:
            table = Table()
            table.add_column("Ver", justify="center", width=4)
            table.add_column("Message", width=25)
            table.add_column("Diff", width=30)
            table.add_column("Timestamp", width=20)

            for entry in history:
                table.add_row(
                    str(entry.get("version", "")),
                    entry.get("commit_msg", ""),
                    entry.get("diff", "")[:28] + ".." if len(entry.get("diff", "")) > 30 else entry.get("diff", ""),
                    entry.get("timestamp", "")[:19],
                )

            console.print(table)
        else:
            console.print("[yellow]No history entries.[/yellow]")
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("grid")
def show_grid(
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
    type_filter: Optional[str] = typer.Option(None, "--type", "-t", help="Filter by type: FACT, OPINION, QUOTE"),
    source: Optional[str] = typer.Option(None, "--source", "-s", help="Filter by source"),
    limit: int = typer.Option(50, "--limit", "-l", help="Max rows to show"),
):
    """
    Show the FactGrid - all facts, opinions, and quotes separated.

    The core concept: News broken down into atomic, verifiable data points.
    """
    client = get_client(base_url)
    try:
        with console.status("[bold blue]Building FactGrid..."):
            articles = client.list_articles(limit=100, skip=0)

        if not articles:
            console.print("[yellow]No articles found. Run 'factgrid pipeline' first.[/yellow]")
            return

        # Collect all grid rows across articles
        all_rows = []
        for article in articles:
            meta = article.get("article_metadata", {})
            state = article.get("current_state", {})
            article_source = meta.get("source", "Unknown")
            article_title = meta.get("title", "")[:30]

            for row in state.get("grid", []):
                row_type = row.get("type", "")

                # Apply filters
                if type_filter and row_type != type_filter.upper():
                    continue
                if source and source.lower() not in article_source.lower():
                    continue

                all_rows.append({
                    "type": row_type,
                    "content": row.get("content", ""),
                    "confidence": row.get("confidence", 0),
                    "status": row.get("status", ""),
                    "source": article_source,
                    "article": article_title,
                })

        if not all_rows:
            console.print("[yellow]No matching rows found.[/yellow]")
            return

        # Count by type
        type_counts = {}
        for row in all_rows:
            t = row["type"]
            type_counts[t] = type_counts.get(t, 0) + 1

        # Header panel
        filter_info = ""
        if type_filter:
            filter_info += f" | Type: {type_filter.upper()}"
        if source:
            filter_info += f" | Source: {source}"

        console.print(Panel(
            f"[green]FACT[/green]: {type_counts.get('FACT', 0)}  "
            f"[yellow]OPINION[/yellow]: {type_counts.get('OPINION', 0)}  "
            f"[cyan]QUOTE[/cyan]: {type_counts.get('QUOTE', 0)}"
            f"{filter_info}",
            title="FactGrid - Atomic News Data Points",
            border_style="blue",
        ))

        # Build table
        table = Table(show_header=True, header_style="bold")
        table.add_column("Type", width=8)
        table.add_column("Content", width=45)
        table.add_column("Conf", justify="right", width=5)
        table.add_column("Status", width=10)
        table.add_column("Source", width=12)

        type_colors = {
            "FACT": "green",
            "OPINION": "yellow",
            "QUOTE": "cyan",
        }

        for row in all_rows[:limit]:
            color = type_colors.get(row["type"], "white")
            status_color = "green" if row["status"] == "VERIFIED" else "yellow"
            content = row["content"]
            if len(content) > 43:
                content = content[:43] + ".."

            table.add_row(
                f"[{color}]{row['type']}[/{color}]",
                content,
                f"{row['confidence']:.2f}",
                f"[{status_color}]{row['status']}[/{status_color}]",
                row["source"][:12],
            )

        console.print(table)

        if len(all_rows) > limit:
            console.print(f"\n[dim]Showing {limit} of {len(all_rows)} rows. Use --limit to see more.[/dim]")

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("stats")
def show_stats(
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
):
    """
    Show statistics: facts/opinions/quotes per source.

    Analyze how different sources present information.
    """
    client = get_client(base_url)
    try:
        with console.status("[bold blue]Calculating statistics..."):
            articles = client.list_articles(limit=100, skip=0)

        if not articles:
            console.print("[yellow]No articles found.[/yellow]")
            return

        # Collect stats per source
        source_stats = {}
        total_stats = {"FACT": 0, "OPINION": 0, "QUOTE": 0, "articles": 0}

        for article in articles:
            meta = article.get("article_metadata", {})
            state = article.get("current_state", {})
            source_name = meta.get("source", "Unknown")

            if source_name not in source_stats:
                source_stats[source_name] = {"FACT": 0, "OPINION": 0, "QUOTE": 0, "articles": 0}

            source_stats[source_name]["articles"] += 1
            total_stats["articles"] += 1

            for row in state.get("grid", []):
                row_type = row.get("type", "")
                if row_type in source_stats[source_name]:
                    source_stats[source_name][row_type] += 1
                    total_stats[row_type] += 1

        # Summary panel
        total_points = total_stats["FACT"] + total_stats["OPINION"] + total_stats["QUOTE"]
        fact_pct = (total_stats["FACT"] / total_points * 100) if total_points > 0 else 0

        console.print(Panel(
            f"Total Articles: [bold]{total_stats['articles']}[/bold]\n"
            f"Total Data Points: [bold]{total_points}[/bold]\n\n"
            f"[green]Facts[/green]: {total_stats['FACT']} ({fact_pct:.0f}%)\n"
            f"[yellow]Opinions[/yellow]: {total_stats['OPINION']}\n"
            f"[cyan]Quotes[/cyan]: {total_stats['QUOTE']}",
            title="FactGrid Statistics",
            border_style="blue",
        ))

        # Per-source table
        table = Table(title="Breakdown by Source")
        table.add_column("Source", width=20)
        table.add_column("Articles", justify="center", width=8)
        table.add_column("Facts", justify="center", width=8, style="green")
        table.add_column("Opinions", justify="center", width=8, style="yellow")
        table.add_column("Quotes", justify="center", width=8, style="cyan")
        table.add_column("Fact %", justify="right", width=8)

        # Sort by total facts descending
        sorted_sources = sorted(
            source_stats.items(),
            key=lambda x: x[1]["FACT"],
            reverse=True
        )

        for source_name, stats in sorted_sources:
            total = stats["FACT"] + stats["OPINION"] + stats["QUOTE"]
            pct = (stats["FACT"] / total * 100) if total > 0 else 0
            pct_color = "green" if pct >= 60 else "yellow" if pct >= 40 else "red"

            table.add_row(
                source_name[:20],
                str(stats["articles"]),
                str(stats["FACT"]),
                str(stats["OPINION"]),
                str(stats["QUOTE"]),
                f"[{pct_color}]{pct:.0f}%[/{pct_color}]",
            )

        console.print(table)

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("diff")
def show_diff(
    article_id: str = typer.Argument(..., help="Article ID"),
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
):
    """
    Show version diff for an article (Git-style).

    Track how information has changed over time.
    """
    client = get_client(base_url)
    try:
        with console.status("[bold blue]Fetching version history..."):
            article = client.get_article(article_id)
            history_result = client.get_article_history(article_id)

        meta = article.get("article_metadata", {})
        state = article.get("current_state", {})
        history = history_result.get("history", [])

        console.print(Panel(
            f"[bold]{meta.get('title', 'No title')}[/bold]\n"
            f"Source: {meta.get('source', 'N/A')}\n"
            f"Current Version: [bold]v{state.get('version', 1)}[/bold]",
            title="Version History",
            border_style="blue",
        ))

        if not history:
            console.print("[yellow]No version history available.[/yellow]")
            return

        # Show each version change
        for i, entry in enumerate(history):
            version = entry.get("version", i + 1)
            commit_msg = entry.get("commit_msg", "No message")
            diff = entry.get("diff", "")
            logic = entry.get("logic", "")
            timestamp = entry.get("timestamp", "")[:19]

            # Determine change type styling
            if "added" in diff.lower() or "initial" in commit_msg.lower():
                diff_color = "green"
                symbol = "+"
            elif "removed" in diff.lower() or "deleted" in diff.lower():
                diff_color = "red"
                symbol = "-"
            elif "updated" in diff.lower() or "changed" in diff.lower():
                diff_color = "yellow"
                symbol = "~"
            else:
                diff_color = "white"
                symbol = "•"

            console.print(f"\n[bold]v{version}[/bold] - {timestamp}")
            console.print(f"  [dim]Commit:[/dim] {commit_msg}")
            if diff:
                console.print(f"  [{diff_color}]{symbol} {diff}[/{diff_color}]")
            if logic:
                console.print(f"  [dim]Logic: {logic}[/dim]")

        # Show current grid state
        console.print("\n")
        grid = state.get("grid", [])
        if grid:
            table = Table(title=f"Current State (v{state.get('version', 1)})")
            table.add_column("Type", width=8)
            table.add_column("Content", width=50)
            table.add_column("Status", width=10)

            type_colors = {"FACT": "green", "OPINION": "yellow", "QUOTE": "cyan"}

            for row in grid:
                color = type_colors.get(row.get("type", ""), "white")
                table.add_row(
                    f"[{color}]{row.get('type', '')}[/{color}]",
                    row.get("content", "")[:48],
                    row.get("status", ""),
                )
            console.print(table)

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("matrix")
def show_matrix(
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
    article_id: Optional[str] = typer.Option(None, "--article", "-a", help="Show matrix for specific article"),
):
    """
    Show topic-based matrix: Facts vs Opinions vs Quotes by topic.

    The core FactGrid concept - news broken down into a verifiable grid.

    Example output:
    | Topic    | Facts              | Opinions           | Quotes             |
    |----------|--------------------|--------------------|---------------------|
    | Economy  | GDP grew 2.3%      | "Will collapse"    | "We must invest"   |
    | Security | Base has 500 troops| "Risk of war"      | "Peace is priority"|
    """
    client = get_client(base_url)
    try:
        with console.status("[bold blue]Building topic matrix..."):
            if article_id:
                articles = [client.get_article(article_id)]
            else:
                articles = client.list_articles(limit=100, skip=0)

        if not articles:
            console.print("[yellow]No articles found.[/yellow]")
            return

        # Collect data by topic
        topic_data = {}  # topic -> {FACT: [], OPINION: [], QUOTE: []}

        for article in articles:
            meta = article.get("article_metadata", {})
            state = article.get("current_state", {})
            article_source = meta.get("source", "")

            # Get fallback topic from article metadata
            article_category = meta.get("topic", "").lower()
            fallback_topic = CATEGORY_TO_TOPIC.get(article_category, "Other")

            for row in state.get("grid", []):
                # Use row topic if present, otherwise use article-level topic
                topic = row.get("topic") or fallback_topic
                row_type = row.get("type", "")
                content = row.get("content", "")

                if topic not in topic_data:
                    topic_data[topic] = {"FACT": [], "OPINION": [], "QUOTE": []}

                if row_type in topic_data[topic]:
                    topic_data[topic][row_type].append({
                        "content": content,
                        "source": article_source,
                        "confidence": row.get("confidence", 0),
                        "status": row.get("status", ""),
                    })

        if not topic_data:
            console.print("[yellow]No topic data found. Run 'factgrid pipeline' to fetch new articles.[/yellow]")
            return

        # Count totals
        total_facts = sum(len(d["FACT"]) for d in topic_data.values())
        total_opinions = sum(len(d["OPINION"]) for d in topic_data.values())
        total_quotes = sum(len(d["QUOTE"]) for d in topic_data.values())

        # Header
        title = "FactGrid Matrix"
        if article_id:
            title += f" (Article: {article_id[:12]}...)"

        console.print(Panel(
            f"Topics: [bold]{len(topic_data)}[/bold]  |  "
            f"[green]Facts: {total_facts}[/green]  "
            f"[yellow]Opinions: {total_opinions}[/yellow]  "
            f"[cyan]Quotes: {total_quotes}[/cyan]",
            title=title,
            border_style="blue",
        ))

        # Build matrix table
        table = Table(show_header=True, header_style="bold", box=None, padding=(0, 1))
        table.add_column("Topic", style="bold", width=12)
        table.add_column("Facts (Verifiable)", style="green", width=28)
        table.add_column("Opinions (Subjective)", style="yellow", width=28)
        table.add_column("Quotes (Direct)", style="cyan", width=28)

        # Sort topics by total content
        sorted_topics = sorted(
            topic_data.items(),
            key=lambda x: len(x[1]["FACT"]) + len(x[1]["OPINION"]) + len(x[1]["QUOTE"]),
            reverse=True,
        )

        for topic, data in sorted_topics:
            # Get first item from each type (or empty)
            fact_items = data["FACT"]
            opinion_items = data["OPINION"]
            quote_items = data["QUOTE"]

            # Format cells - show first item with count
            def format_cell(items, max_len=26):
                if not items:
                    return "[dim]-[/dim]"
                first = items[0]["content"]
                if len(first) > max_len:
                    first = first[:max_len] + ".."
                if len(items) > 1:
                    return f"{first}\n[dim](+{len(items)-1} more)[/dim]"
                return first

            table.add_row(
                topic,
                format_cell(fact_items),
                format_cell(opinion_items),
                format_cell(quote_items),
            )

        console.print(table)

        # Detailed view hint
        console.print(f"\n[dim]Use 'factgrid matrix --article <id>' for single article view.[/dim]")
        console.print(f"[dim]Use 'factgrid topic <name>' to explore a specific topic.[/dim]")

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("topic")
def show_topic(
    topic_name: str = typer.Argument(..., help="Topic name (e.g., Economy, Security)"),
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
):
    """
    Deep dive into a specific topic across all articles.

    Shows all facts, opinions, and quotes for the given topic.
    """
    client = get_client(base_url)
    try:
        with console.status(f"[bold blue]Fetching '{topic_name}' data..."):
            articles = client.list_articles(limit=100, skip=0)

        if not articles:
            console.print("[yellow]No articles found.[/yellow]")
            return

        # Collect all rows for this topic
        facts = []
        opinions = []
        quotes = []

        for article in articles:
            meta = article.get("article_metadata", {})
            state = article.get("current_state", {})
            article_source = meta.get("source", "")
            article_title = meta.get("title", "")[:40]

            # Get fallback topic from article metadata
            article_category = meta.get("topic", "").lower()
            fallback_topic = CATEGORY_TO_TOPIC.get(article_category, "Other")

            for row in state.get("grid", []):
                topic = row.get("topic") or fallback_topic
                if topic.lower() != topic_name.lower():
                    continue

                row_type = row.get("type", "")
                item = {
                    "content": row.get("content", ""),
                    "source": row.get("source", article_source),
                    "confidence": row.get("confidence", 0),
                    "status": row.get("status", ""),
                    "article": article_title,
                }

                if row_type == "FACT":
                    facts.append(item)
                elif row_type == "OPINION":
                    opinions.append(item)
                elif row_type == "QUOTE":
                    quotes.append(item)

        total = len(facts) + len(opinions) + len(quotes)
        if total == 0:
            console.print(f"[yellow]No data found for topic '{topic_name}'.[/yellow]")
            console.print("[dim]Available topics: Economy, Politics, Technology, Security, Environment, Health, Social, Other[/dim]")
            return

        # Header
        console.print(Panel(
            f"[green]Facts: {len(facts)}[/green]  "
            f"[yellow]Opinions: {len(opinions)}[/yellow]  "
            f"[cyan]Quotes: {len(quotes)}[/cyan]",
            title=f"Topic: {topic_name}",
            border_style="blue",
        ))

        # Facts table
        if facts:
            console.print("\n[bold green]FACTS (Verifiable Data)[/bold green]")
            fact_table = Table(show_header=True, box=None)
            fact_table.add_column("Content", width=50)
            fact_table.add_column("Source", width=20)
            fact_table.add_column("Status", width=10)

            for f in facts:
                status_color = "green" if f["status"] == "VERIFIED" else "yellow"
                fact_table.add_row(
                    f["content"][:48] + ".." if len(f["content"]) > 50 else f["content"],
                    f["source"][:20],
                    f"[{status_color}]{f['status']}[/{status_color}]",
                )
            console.print(fact_table)

        # Opinions table
        if opinions:
            console.print("\n[bold yellow]OPINIONS (Subjective/Predictions)[/bold yellow]")
            opinion_table = Table(show_header=True, box=None)
            opinion_table.add_column("Content", width=50)
            opinion_table.add_column("Source", width=20)

            for o in opinions:
                opinion_table.add_row(
                    o["content"][:48] + ".." if len(o["content"]) > 50 else o["content"],
                    o["source"][:20],
                )
            console.print(opinion_table)

        # Quotes table
        if quotes:
            console.print("\n[bold cyan]QUOTES (Direct Statements)[/bold cyan]")
            quote_table = Table(show_header=True, box=None)
            quote_table.add_column("Content", width=50)
            quote_table.add_column("Source", width=20)

            for q in quotes:
                content = f'"{q["content"]}"' if not q["content"].startswith('"') else q["content"]
                quote_table.add_row(
                    content[:48] + '.."' if len(content) > 50 else content,
                    q["source"][:20],
                )
            console.print(quote_table)

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


def truncate_text(text: str, max_len: int) -> str:
    """Truncate text with ellipsis."""
    if not text:
        return ""
    return text[:max_len-2] + ".." if len(text) > max_len else text


def wrap_text(text: str, width: int) -> list:
    """Wrap text into lines of max width."""
    if not text:
        return [""]
    words = text.split()
    lines = []
    current_line = ""
    for word in words:
        if len(current_line) + len(word) + 1 <= width:
            current_line += (" " if current_line else "") + word
        else:
            if current_line:
                lines.append(current_line)
            current_line = word[:width] if len(word) > width else word
    if current_line:
        lines.append(current_line)
    return lines if lines else [""]


def format_grid_cell(items: list, cell_width: int, item_type: str) -> list:
    """Format items for a grid cell, returns list of lines."""
    if not items:
        return ["  -"]

    lines = []
    for item in items[:3]:  # Max 3 items per cell
        content = item.get("content", "")
        source = item.get("source", "")

        # Wrap content
        content_lines = wrap_text(content, cell_width - 4)
        for j, line in enumerate(content_lines[:2]):  # Max 2 lines per item
            prefix = "  * " if j == 0 else "    "
            lines.append(prefix + line)

        # Add source on separate line
        if source:
            source_text = f"    ({truncate_text(source, cell_width - 6)})"
            lines.append(source_text)

    if len(items) > 3:
        lines.append(f"    (+{len(items) - 3} more)")

    return lines


PERSPECTIVE_ICONS = {
    "Conservative": "🔴",
    "Progressive": "🔵",
    "Expert": "📊",
    "International": "🌍",
    "Neutral": "⚪",
}

PERSPECTIVE_COLORS = {
    "Conservative": "red",
    "Progressive": "blue",
    "Expert": "magenta",
    "International": "green",
    "Neutral": "white",
}


@app.command("today")
def show_today(
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
    compact: bool = typer.Option(False, "--compact", "-c", help="Extra compact view"),
):
    """
    📰 Snabb daglig nyhetsöverblick - fakta utan bias.

    Visar dagens viktigaste stories med fakta och olika perspektiv
    i ett kompakt, lättläst format.
    """
    client = get_client(base_url)
    try:
        with console.status("[bold blue]📡 Hämtar nyheter från multipla källor..."):
            result = client.get_stories()

        stories = result.get("stories", [])
        articles_processed = result.get("articles_processed", 0)
        sources_used = result.get("sources_used", [])

        if not stories:
            console.print()
            console.print("[yellow]Inga stories att visa just nu.[/yellow]")
            console.print("[dim]Tips: Prova igen senare när fler artiklar är tillgängliga.[/dim]")
            return

        # Header
        from datetime import datetime
        today = datetime.now().strftime("%Y-%m-%d")

        console.print()
        console.print(f"[bold]📰 FACTGRID TODAY[/bold] - {today}")
        console.print(f"[dim]{articles_processed} artiklar från {len(sources_used)} källor → {len(stories)} stories[/dim]")
        console.print()

        # Display each story in compact format
        for i, story in enumerate(stories, 1):
            story_name = story.get("name", "Unknown Story")
            facts = story.get("facts", [])
            perspectives = story.get("perspectives", [])
            sources = story.get("sources", [])

            # Story header with colored bar
            console.print(f"[bold cyan]{'━' * 70}[/bold cyan]")
            console.print(f"[bold white] {i}. {story_name}[/bold white]")
            console.print(f"[dim]    Källor: {', '.join(sources[:3])}[/dim]")
            console.print()

            # Facts - compact bullets
            if facts:
                console.print("[bold green]   FAKTA[/bold green]")
                for fact in facts[:3]:
                    content = truncate_text(fact.get("content", ""), 60)
                    console.print(f"   [green]•[/green] {content}")
                if len(facts) > 3:
                    console.print(f"   [dim]  (+{len(facts) - 3} fler fakta)[/dim]")
                console.print()

            # Perspectives - one line each
            if perspectives:
                console.print("[bold]   PERSPEKTIV[/bold]")
                for perspective in perspectives:
                    persp_type = perspective.get("perspective", "Neutral")
                    persp_label = perspective.get("label", persp_type)
                    icon = PERSPECTIVE_ICONS.get(persp_type, "•")
                    color = PERSPECTIVE_COLORS.get(persp_type, "white")

                    opinions = perspective.get("opinions", [])
                    quotes = perspective.get("quotes", [])

                    # Show first opinion or quote
                    content = ""
                    source = ""
                    if opinions:
                        content = opinions[0].get("content", "")
                        source = opinions[0].get("source", "")
                    elif quotes:
                        content = quotes[0].get("content", "")
                        source = quotes[0].get("source", "")

                    if content:
                        content_short = truncate_text(content, 50)
                        console.print(f"   {icon} [{color}]{persp_label}[/{color}]: \"{content_short}\"")
                        if source and not compact:
                            console.print(f"      [dim]- {truncate_text(source, 40)}[/dim]")

            console.print()

        # Footer
        console.print(f"[dim]Kör 'factgrid stories' för fullständig vy.[/dim]")
        console.print()

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("stories")
def show_stories(
    base_url: str = typer.Option(DEFAULT_BASE_URL, "--url", "-u", help="API base URL"),
    show_json: bool = typer.Option(False, "--json", "-j", help="Show raw JSON"),
):
    """
    Visa nyheter utan bias - fakta separerat från åsikter.

    Grupperar relaterade artiklar och visar:
    - FAKTA: Verifierbara uppgifter
    - PERSPEKTIV: Åsikter grupperade efter politisk/ideologisk inriktning
    """
    client = get_client(base_url)
    try:
        with console.status("[bold blue]Analyserar nyheter..."):
            result = client.get_stories()

        if show_json:
            console.print(JSON(json.dumps(result, indent=2)))
            return

        stories = result.get("stories", [])
        articles_processed = result.get("articles_processed", 0)

        if not stories:
            console.print(Panel(
                f"[yellow]Inga stories hittades från {articles_processed} artiklar.[/yellow]\n"
                "[dim]Stories kräver 2+ artiklar om samma händelse.[/dim]",
                title="Stories",
                border_style="yellow",
            ))
            return

        # Summary header
        sources_used = result.get("sources_used", [])
        console.print()
        console.print(f"[bold]FactGrid[/bold] - {articles_processed} artiklar → {len(stories)} stories")
        if sources_used:
            console.print(f"[dim]Källor: {', '.join(sources_used)}[/dim]")
        console.print()

        # Display each story
        for i, story in enumerate(stories, 1):
            story_name = story.get("name", "Unknown Story")
            story_summary = story.get("summary", "")
            article_count = story.get("article_count", 0)
            sources = story.get("sources", [])
            facts = story.get("facts", [])
            perspectives = story.get("perspectives", [])

            # Total width
            total_width = 75

            # Story box top
            console.print("┌" + "─" * (total_width - 2) + "┐")

            # Story title
            title_line = f"  STORY {i}: {story_name}"
            if len(title_line) > total_width - 3:
                title_line = title_line[:total_width - 6] + "..."
            console.print(f"│[bold blue]{title_line:<{total_width - 3}}[/bold blue]│")

            # Sources
            sources_str = ", ".join(sources[:3]) if sources else "Unknown"
            if len(sources) > 3:
                sources_str += f" (+{len(sources) - 3})"
            sources_line = f"  Källor: {sources_str} ({article_count} artiklar)"
            console.print(f"│[dim]{sources_line:<{total_width - 3}}[/dim]│")

            # Summary
            if story_summary:
                summary_wrapped = wrap_text(story_summary, total_width - 5)
                for line in summary_wrapped[:2]:
                    console.print(f"│[dim]  {line:<{total_width - 5}}[/dim]│")

            # FAKTA section
            console.print("├" + "─" * (total_width - 2) + "┤")
            console.print(f"│[bold green]  FAKTA (Verifierat){' ' * (total_width - 23)}[/bold green]│")
            console.print("├" + "─" * (total_width - 2) + "┤")

            if facts:
                for fact in facts[:5]:
                    content = fact.get("content", "")
                    source = fact.get("source", "")
                    # Wrap content
                    content_wrapped = wrap_text(content, total_width - 8)
                    for j, line in enumerate(content_wrapped[:2]):
                        prefix = "  • " if j == 0 else "    "
                        console.print(f"│[green]{prefix}{line:<{total_width - 7}}[/green]│")
                    if source:
                        source_line = f"    ({truncate_text(source, total_width - 10)})"
                        console.print(f"│[dim]{source_line:<{total_width - 3}}[/dim]│")
            else:
                console.print(f"│[dim]  Inga fakta extraherade{' ' * (total_width - 28)}[/dim]│")

            # PERSPEKTIV section
            console.print("├" + "─" * (total_width - 2) + "┤")
            console.print(f"│[bold]  PERSPEKTIV{' ' * (total_width - 15)}[/bold]│")
            console.print("├" + "─" * (total_width - 2) + "┤")

            if perspectives:
                for p_idx, perspective in enumerate(perspectives):
                    persp_type = perspective.get("perspective", "Neutral")
                    persp_label = perspective.get("label", persp_type)
                    icon = PERSPECTIVE_ICONS.get(persp_type, "•")
                    opinions = perspective.get("opinions", [])
                    quotes = perspective.get("quotes", [])

                    # Perspective header
                    persp_header = f"  {icon} {persp_label}"
                    console.print(f"│[bold]{persp_header:<{total_width - 3}}[/bold]│")

                    # Opinions
                    for opinion in opinions[:2]:
                        content = opinion.get("content", "")
                        source = opinion.get("source", "")
                        affiliation = opinion.get("affiliation", "")
                        source_str = f"{source}" + (f", {affiliation}" if affiliation else "")
                        content_short = truncate_text(content, total_width - 10)
                        console.print(f"│[yellow]    \"{content_short}\"[/yellow]{' ' * max(0, total_width - len(content_short) - 9)}│")
                        if source_str:
                            console.print(f"│[dim]    - {truncate_text(source_str, total_width - 12):<{total_width - 9}}[/dim]│")

                    # Quotes
                    for quote in quotes[:2]:
                        content = quote.get("content", "")
                        source = quote.get("source", "")
                        role = quote.get("role", "")
                        source_str = f"{source}" + (f", {role}" if role else "")
                        content_short = truncate_text(content, total_width - 10)
                        console.print(f"│[cyan]    \"{content_short}\"[/cyan]{' ' * max(0, total_width - len(content_short) - 9)}│")
                        if source_str:
                            console.print(f"│[dim]    - {truncate_text(source_str, total_width - 12):<{total_width - 9}}[/dim]│")

                    # Separator between perspectives
                    if p_idx < len(perspectives) - 1:
                        console.print(f"│{' ' * (total_width - 2)}│")
            else:
                console.print(f"│[dim]  Inga perspektiv extraherade{' ' * (total_width - 34)}[/dim]│")

            # Story box bottom
            console.print("└" + "─" * (total_width - 2) + "┘")
            console.print()

        console.print(f"[dim]Kör 'factgrid stories --json' för fullständig data.[/dim]")

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("research")
def run_research(
    fetch: bool = typer.Option(True, "--fetch/--no-fetch", help="Fetch new headlines from NewsAPI"),
    limit: int = typer.Option(5, "--limit", "-l", help="Max headlines to research"),
):
    """
    🔬 Kör AI-driven research pipeline.

    Hämtar nyheter från NewsAPI, sparar i MongoDB,
    och researchar med Claude för att hitta fakta och perspektiv.
    """
    from factgrid.domain.research import ResearchPipeline

    try:
        pipeline = ResearchPipeline()

        with console.status("[bold blue]🔬 Kör research pipeline..."):
            result = pipeline.run(fetch_new=fetch, process_limit=limit)

        # Show results
        console.print()
        console.print(Panel(
            f"[green]✓ Pipeline klar[/green]\n\n"
            f"Headlines hämtade: [bold]{result.headlines_fetched}[/bold]\n"
            f"Headlines sparade: [bold]{result.headlines_saved}[/bold]\n"
            f"Stories skapade: [bold]{result.stories_created}[/bold]",
            title="Research Pipeline",
            border_style="green" if result.stories_created > 0 else "yellow",
        ))

        # Show created stories
        if result.stories:
            console.print()
            console.print("[bold]Skapade stories:[/bold]")
            for story in result.stories:
                facts_count = len(story.facts)
                persp_count = len(story.perspectives)
                console.print(f"  • {story.title[:60]}")
                console.print(f"    [dim]{facts_count} fakta, {persp_count} perspektiv[/dim]")

        # Show errors if any
        if result.errors:
            console.print()
            console.print("[yellow]Varningar:[/yellow]")
            for error in result.errors[:3]:
                console.print(f"  ⚠ {error}")

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("research-status")
def show_research_status():
    """
    📊 Visa status för research pipeline.

    Visar antal headlines och stories i databasen.
    """
    from factgrid.domain.research import ResearchPipeline

    try:
        pipeline = ResearchPipeline()
        status = pipeline.get_status()

        console.print()
        console.print(Panel(
            f"[bold]Headlines[/bold]\n"
            f"  Totalt: {status['headlines_total']}\n"
            f"  Processade: {status['headlines_processed']}\n"
            f"  Väntar: {status['headlines_pending']}\n\n"
            f"[bold]Stories[/bold]\n"
            f"  Totalt: {status['stories_total']}",
            title="Research Pipeline Status",
            border_style="blue",
        ))

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command("research-stories")
def show_research_stories(
    show_json: bool = typer.Option(False, "--json", "-j", help="Visa raw JSON"),
    limit: int = typer.Option(10, "--limit", "-l", help="Max antal stories"),
):
    """
    📰 Visa AI-researchade stories från databasen.

    Visar stories med fakta och perspektiv från MongoDB.
    """
    from factgrid.domain.research import StoryRepository

    try:
        repo = StoryRepository()
        stories = repo.get_recent(limit=limit)

        if not stories:
            console.print("[yellow]Inga stories i databasen. Kör 'factgrid research' först.[/yellow]")
            return

        if show_json:
            import json
            data = [s.to_api_dict() for s in stories]
            console.print(JSON(json.dumps(data, indent=2, ensure_ascii=False)))
            return

        # Header
        console.print()
        console.print(f"[bold]📰 {len(stories)} AI-researchade stories[/bold]")
        console.print()

        for i, story in enumerate(stories, 1):
            # Story header
            console.print(f"[bold cyan]{'─' * 70}[/bold cyan]")
            console.print(f"[bold white] {i}. {story.title}[/bold white]")
            console.print(f"[dim]    Källor: {', '.join(story.sources_searched[:3])}[/dim]")
            console.print()

            # Summary
            if story.summary:
                console.print(f"   [italic]{story.summary}[/italic]")
                console.print()

            # Facts
            if story.facts:
                console.print("[bold green]   FAKTA[/bold green]")
                for fact in story.facts[:3]:
                    content = truncate_text(fact.content, 60)
                    console.print(f"   [green]•[/green] {content}")
                if len(story.facts) > 3:
                    console.print(f"   [dim]  (+{len(story.facts) - 3} fler fakta)[/dim]")
                console.print()

            # Perspectives
            if story.perspectives:
                console.print("[bold]   PERSPEKTIV[/bold]")
                for persp in story.perspectives:
                    icon = PERSPECTIVE_ICONS.get(persp.perspective, "•")
                    color = PERSPECTIVE_COLORS.get(persp.perspective, "white")

                    console.print(f"   {icon} [{color}]{persp.label}[/{color}]")

                    # Show key argument or quote
                    if persp.key_arguments:
                        arg = truncate_text(persp.key_arguments[0], 50)
                        console.print(f"      \"{arg}\"")
                    elif persp.quotes:
                        q = persp.quotes[0]
                        quote_text = truncate_text(q.content, 45)
                        console.print(f"      \"{quote_text}\"")
                        if q.speaker:
                            console.print(f"      [dim]- {q.speaker}[/dim]")

            console.print()

    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


def main():
    """Entry point for CLI."""
    app()


if __name__ == "__main__":
    main()
