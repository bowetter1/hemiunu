"""Research service using Claude Opus for news analysis with web search."""

import hashlib
import json
import logging
from datetime import datetime
from typing import List, Dict, Any, Optional
from dataclasses import dataclass

import anthropic

from factgrid.infrastructure import get_settings
from factgrid.domain.research.models import (
    RawHeadline,
    ResearchedStory,
    ResearchFact,
    ResearchPerspective,
    ResearchQuote,
)
from factgrid.domain.research.repository import HeadlineRepository, StoryRepository
from factgrid.domain.research.search import WebSearchService

logger = logging.getLogger(__name__)

# Basic prompt when no web search results available
BASIC_RESEARCH_PROMPT = """Du är en objektiv nyhetsanalytiker. Analysera följande nyhetsrubrik och skapa en faktabaserad rapport med olika perspektiv.

RUBRIK: {headline}
BESKRIVNING: {description}

Din uppgift:
1. Identifiera de VERIFIERBARA FAKTA i nyheten
2. Hitta OLIKA PERSPEKTIV på händelsen (höger, vänster, experter, internationellt)
3. Separera fakta från åsikter tydligt

Svara i följande JSON-format:
{{
    "title": "Tydlig rubrik för storyn",
    "summary": "2-3 meningar som sammanfattar händelsen objektivt",
    "facts": [
        {{
            "content": "Ett verifierbart faktum",
            "source": "Källan för faktum",
            "confidence": 0.9
        }}
    ],
    "perspectives": [
        {{
            "perspective": "Conservative|Progressive|Expert|International|Neutral",
            "source_bias": "Right|Left|Center|International",
            "label": "Höger|Vänster|Experter|Internationellt|Neutral",
            "summary": "Sammanfattning av detta perspektivs syn",
            "key_arguments": ["Argument 1", "Argument 2"],
            "quotes": [
                {{
                    "content": "Ett relevant citat",
                    "speaker": "Talaren",
                    "role": "Roll/titel",
                    "affiliation": "Organisation"
                }}
            ],
            "sources_used": ["Källa 1", "Källa 2"]
        }}
    ],
    "search_queries": ["Sökfråga 1 för mer info", "Sökfråga 2"]
}}

Fokusera på att ge en BALANSERAD bild med minst 2-3 olika perspektiv.
Svara ENDAST med valid JSON, ingen annan text."""

# Multi-source prompt for comparing perspectives across biased sources
MULTI_SOURCE_PROMPT = """Du är en expert på nyhetsanalys med uppdrag att destillera sanningen från flera källor med känd bias. Analysera följande originalrubrik och utdrag från olika nyhetskällor för att skapa en balanserad och faktabaserad rapport.

**ORIGINALRUBRIK:** {headline}
**BESKRIVNING:** {description}

**KÄLLUTDRAG:**
{source_snippets}

**DITT UPPDRAG:**
1. **Jämför perspektiven:** Jämför hur varje källa ramar in händelsen. Notera skillnader i språk, vilka fakta som betonas och vilka som utelämnas.
2. **Extrahera gemensamma fakta:** Identifiera de konkreta, verifierbara fakta som ALLA källor är överens om. Dessa utgör kärnan i storyn och ska ha högsta confidence.
3. **Extrahera källspecifika perspektiv:** För varje källa, sammanfatta deras unika vinkel, nyckelargument och relevanta citat. Märk varje perspektiv med dess kända bias.
4. **Skapa en objektiv syntes:** Skriv en neutral rubrik och sammanfattning baserad på de gemensamma fakta.

**Svara ENDAST med valid JSON i följande format:**
{{
    "title": "En neutral, faktabaserad rubrik för händelsen",
    "summary": "En objektiv sammanfattning på 2-3 meningar, baserad på fakta som alla källor är överens om.",
    "facts": [
        {{
            "content": "Ett verifierbart faktum som återfinns i ALLA eller de flesta källor.",
            "source": "Syntetiserad från [lista källor]",
            "confidence": 0.95
        }}
    ],
    "perspectives": [
        {{
            "perspective": "Conservative|Progressive|Expert|International|Neutral",
            "source_bias": "Right|Left|Center|International",
            "label": "Perspektiv från [källa/bias]",
            "summary": "Sammanfattning av källans specifika vinkel och tolkning.",
            "key_arguments": ["Argument 1", "Argument 2"],
            "quotes": [
                {{
                    "content": "Ett citat som är representativt för källans rapportering",
                    "speaker": "Talaren i citatet",
                    "role": "Roll/titel",
                    "affiliation": "Organisation"
                }}
            ],
            "sources_used": ["Källa"]
        }}
    ],
    "search_queries": ["Sökfråga för att verifiera fakta", "Sökfråga för att förstå en parts perspektiv"]
}}"""


@dataclass
class ResearchResult:
    """Result of researching a headline."""
    story: ResearchedStory
    search_queries: List[str]
    success: bool
    error: Optional[str] = None


class ResearchService:
    """Service for AI-powered news research using Claude with multi-source analysis."""

    def __init__(
        self,
        headline_repo: Optional[HeadlineRepository] = None,
        story_repo: Optional[StoryRepository] = None,
        brave_api_key: Optional[str] = None,
    ):
        settings = get_settings()
        self.client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self.model = "claude-sonnet-4-20250514"  # Using Sonnet for cost-efficiency
        self.headline_repo = headline_repo or HeadlineRepository()
        self.story_repo = story_repo or StoryRepository()
        self.brave_api_key = brave_api_key or settings.brave_api_key or None
        self.web_search = WebSearchService() if self.brave_api_key else None
        logger.info("Web search enabled: %s", bool(self.brave_api_key))

    def _generate_story_id(self, headline: RawHeadline) -> str:
        """Generate a unique story ID from headline."""
        content = f"{headline.title}:{headline.published_at}"
        return hashlib.sha256(content.encode()).hexdigest()[:16]

    def _format_source_snippets(self, search_results: List[Dict[str, Any]]) -> str:
        """Format search results into readable source snippets."""
        snippets = []
        bias_labels = {
            "right": "Höger-bias",
            "left": "Vänster-bias",
            "center": "Center-bias",
            "international": "Internationell"
        }

        # Group by bias category
        by_bias: Dict[str, List[Dict]] = {}
        for result in search_results:
            bias = result.get("bias_category", "unknown")
            if bias not in by_bias:
                by_bias[bias] = []
            by_bias[bias].append(result)

        for bias, results in by_bias.items():
            label = bias_labels.get(bias, bias.title())
            for r in results[:2]:  # Max 2 per category
                domain = r.get("source_domain", "Unknown")
                snippet = r.get("snippet", "")[:300]
                snippets.append(f'* **{domain} ({label}):** "{snippet}"')

        return "\n".join(snippets) if snippets else "Inga externa källor hittades."

    def research_headline(self, headline: RawHeadline) -> ResearchResult:
        """Research a single headline using Claude with optional multi-source analysis."""
        logger.info("Researching headline: %s", headline.title[:50])

        try:
            # Try web search for multiple perspectives
            search_results = []
            if self.web_search and self.brave_api_key:
                logger.info("Searching for multiple source perspectives...")
                search_results = self.web_search.search_sources(
                    headline.title, self.brave_api_key
                )
                logger.info("Found %d source perspectives", len(search_results))

            # Build prompt based on whether we have search results
            if search_results:
                source_snippets = self._format_source_snippets(search_results)
                prompt = MULTI_SOURCE_PROMPT.format(
                    headline=headline.title,
                    description=headline.description or "",
                    source_snippets=source_snippets
                )
            else:
                prompt = BASIC_RESEARCH_PROMPT.format(
                    headline=headline.title,
                    description=headline.description or ""
                )

            # Call Claude
            message = self.client.messages.create(
                model=self.model,
                max_tokens=4000,
                messages=[
                    {"role": "user", "content": prompt}
                ]
            )

            # Parse response
            response_text = message.content[0].text

            # Try to extract JSON from response
            try:
                # Handle case where response might have markdown code blocks
                if "```json" in response_text:
                    json_start = response_text.index("```json") + 7
                    json_end = response_text.index("```", json_start)
                    response_text = response_text[json_start:json_end].strip()
                elif "```" in response_text:
                    json_start = response_text.index("```") + 3
                    json_end = response_text.index("```", json_start)
                    response_text = response_text[json_start:json_end].strip()

                result = json.loads(response_text)
            except json.JSONDecodeError as e:
                logger.error("Failed to parse JSON response: %s", e)
                return ResearchResult(
                    story=self._create_fallback_story(headline),
                    search_queries=[],
                    success=False,
                    error=f"JSON parse error: {str(e)}"
                )

            # Build story from result
            story = self._build_story_from_result(headline, result)

            return ResearchResult(
                story=story,
                search_queries=result.get("search_queries", []),
                success=True
            )

        except anthropic.APIError as e:
            logger.error("Anthropic API error: %s", e)
            return ResearchResult(
                story=self._create_fallback_story(headline),
                search_queries=[],
                success=False,
                error=str(e)
            )
        except Exception as e:
            logger.exception("Unexpected error researching headline")
            return ResearchResult(
                story=self._create_fallback_story(headline),
                search_queries=[],
                success=False,
                error=str(e)
            )

    def _build_story_from_result(
        self, headline: RawHeadline, result: Dict[str, Any]
    ) -> ResearchedStory:
        """Build a ResearchedStory from Claude's analysis."""
        story_id = self._generate_story_id(headline)

        # Parse facts
        facts = []
        for f in result.get("facts", []):
            facts.append(ResearchFact(
                content=f.get("content", ""),
                source=f.get("source", headline.source_name),
                confidence=f.get("confidence", 0.7),
            ))

        # Parse perspectives
        perspectives = []
        for p in result.get("perspectives", []):
            quotes = [
                ResearchQuote(
                    content=q.get("content", ""),
                    speaker=q.get("speaker", ""),
                    role=q.get("role", ""),
                    affiliation=q.get("affiliation", ""),
                )
                for q in p.get("quotes", [])
            ]
            perspectives.append(ResearchPerspective(
                perspective=p.get("perspective", "Neutral"),
                label=p.get("label", p.get("perspective", "Neutral")),
                summary=p.get("summary", ""),
                quotes=quotes,
                key_arguments=p.get("key_arguments", []),
                sources_used=p.get("sources_used", [headline.source_name]),
            ))

        return ResearchedStory(
            id=story_id,
            headline_ids=[headline.id],
            title=result.get("title", headline.title),
            summary=result.get("summary", headline.description or ""),
            facts=facts,
            perspectives=perspectives,
            image_url=headline.url_to_image,
            sources_searched=[headline.source_name],
            research_queries=result.get("search_queries", []),
        )

    def _create_fallback_story(self, headline: RawHeadline) -> ResearchedStory:
        """Create a minimal story when research fails."""
        story_id = self._generate_story_id(headline)
        return ResearchedStory(
            id=story_id,
            headline_ids=[headline.id],
            title=headline.title,
            summary=headline.description or "",
            facts=[],
            perspectives=[],
            image_url=headline.url_to_image,
            sources_searched=[headline.source_name],
        )

    def research_and_save(self, headline: RawHeadline) -> Optional[ResearchedStory]:
        """Research a headline and save the story to database."""
        result = self.research_headline(headline)

        if result.success:
            # Save story
            self.story_repo.save(result.story)
            # Mark headline as processed
            self.headline_repo.mark_processed(headline.id, result.story.id)
            logger.info("Saved story: %s", result.story.title[:50])
            return result.story
        else:
            logger.warning("Research failed for headline: %s - %s",
                         headline.title[:30], result.error)
            return None

    def process_unprocessed_headlines(self, limit: int = 5) -> List[ResearchedStory]:
        """Process unprocessed headlines and return created stories."""
        headlines = self.headline_repo.get_unprocessed(limit=limit)
        logger.info("Processing %d unprocessed headlines", len(headlines))

        stories = []
        for headline in headlines:
            story = self.research_and_save(headline)
            if story:
                stories.append(story)

        return stories

    def get_stories_for_api(self) -> Dict[str, Any]:
        """Get stories formatted for the API endpoint."""
        stories = self.story_repo.get_recent(limit=20)
        headlines_count = self.headline_repo.count()

        return {
            "stories": [s.to_api_dict() for s in stories],
            "articles_processed": headlines_count,
            "sources_used": list(set(
                source
                for s in stories
                for source in s.sources_searched
            ))[:10],
        }
