"""Telegram bot integration for Apex — polling-based, no webhook setup needed."""
import uuid
import asyncio
import threading
from typing import Optional

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    CallbackQueryHandler,
    filters,
)

from apex_server.config import get_settings
from apex_server.shared.database import SessionLocal
from apex_server.auth.models import User
from apex_server.projects.models import Project, Page, ProjectStatus
from apex_server.integrations.telegram_auth import verify_link_code, get_user_by_chat_id

settings = get_settings()


class TelegramBot:
    """Apex Telegram bot — lets users interact with projects from mobile."""

    def __init__(self):
        self.app: Optional[Application] = None
        self._running = False

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    async def start(self):
        """Build the Application and start polling in the background."""
        if not settings.telegram_bot_token:
            print("[TELEGRAM] No bot token configured, skipping", flush=True)
            return

        self.app = (
            Application.builder()
            .token(settings.telegram_bot_token)
            .build()
        )

        # Register handlers
        self.app.add_handler(CommandHandler("start", self.cmd_start))
        self.app.add_handler(CommandHandler("link", self.cmd_link))
        self.app.add_handler(CommandHandler("projects", self.cmd_projects))
        self.app.add_handler(CommandHandler("select", self.cmd_select))
        self.app.add_handler(CommandHandler("status", self.cmd_status))
        self.app.add_handler(CallbackQueryHandler(self.handle_callback))
        self.app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, self.handle_message))

        await self.app.initialize()
        await self.app.start()
        await self.app.updater.start_polling(drop_pending_updates=True)
        self._running = True
        print("[TELEGRAM] Bot started — polling for updates", flush=True)

    async def stop(self):
        """Gracefully stop the bot."""
        if self.app and self._running:
            await self.app.updater.stop()
            await self.app.stop()
            await self.app.shutdown()
            self._running = False
            print("[TELEGRAM] Bot stopped", flush=True)

    # ------------------------------------------------------------------
    # Command handlers
    # ------------------------------------------------------------------

    async def cmd_start(self, update: Update, context):
        """Handle /start — welcome message."""
        # Check if already linked
        user = get_user_by_chat_id(str(update.effective_chat.id))
        if user:
            await update.message.reply_text(
                f"Välkommen tillbaka, {user.name}!\n\n"
                "Kommandon:\n"
                "/projects — Lista projekt\n"
                "/select <nr> — Välj aktivt projekt\n"
                "/status — Visa status\n\n"
                "Eller skriv en brief för att starta ett nytt projekt."
            )
        else:
            await update.message.reply_text(
                "Hej! Jag är Apex-boten.\n\n"
                "För att koppla ditt konto:\n"
                "1. Öppna Apex-appen\n"
                "2. Gå till Inställningar → Telegram\n"
                "3. Skriv den 6-siffriga koden här\n\n"
                "Exempel: /link 482619"
            )

    async def cmd_link(self, update: Update, context):
        """Handle /link <code> — link Telegram chat to Apex user via 6-digit code."""
        if not context.args:
            await update.message.reply_text(
                "Ange din 6-siffriga kod från Apex-appen:\n"
                "/link 482619"
            )
            return

        code = context.args[0].strip()
        chat_id = str(update.effective_chat.id)
        user = verify_link_code(code, chat_id)

        if user:
            await update.message.reply_text(
                f"✅ Kopplat! Du är inloggad som {user.name} ({user.email}).\n\n"
                "Kommandon:\n"
                "/projects — Lista projekt\n"
                "/select <nr> — Välj aktivt projekt\n"
                "/status — Visa status\n\n"
                "Eller skriv en brief för att starta ett nytt projekt."
            )
        else:
            await update.message.reply_text(
                "❌ Ogiltig eller utgången kod.\n\n"
                "Generera en ny kod i Apex-appen (Inställningar → Telegram)."
            )

    async def cmd_projects(self, update: Update, context):
        """Handle /projects — list user's projects."""
        user = get_user_by_chat_id(str(update.effective_chat.id))
        if not user:
            await update.message.reply_text("Du är inte kopplad. Använd /link <kod> först.")
            return

        db = SessionLocal()
        try:
            projects = (
                db.query(Project)
                .filter(Project.user_id == user.id)
                .order_by(Project.created_at.desc())
                .limit(10)
                .all()
            )

            if not projects:
                await update.message.reply_text("Inga projekt ännu. Skriv en brief för att starta!")
                return

            lines = []
            for i, p in enumerate(projects, 1):
                status_emoji = {
                    "brief": "📝", "clarification": "❓", "moodboard": "🎨",
                    "layouts": "📐", "editing": "✏️", "done": "✅", "failed": "❌",
                }.get(p.status.value, "⏳")
                lines.append(f"{i}. {status_emoji} {p.brief[:60]}")

            await update.message.reply_text(
                "Dina projekt:\n\n" + "\n".join(lines) + "\n\n"
                "Välj med /select <nummer>"
            )

            # Store project list in user context for /select
            context.user_data["project_ids"] = [str(p.id) for p in projects]
        finally:
            db.close()

    async def cmd_select(self, update: Update, context):
        """Handle /select <number> — select active project."""
        if not context.args:
            await update.message.reply_text("Ange projektnummer: /select 1")
            return

        try:
            idx = int(context.args[0]) - 1
        except ValueError:
            await update.message.reply_text("Ange ett nummer: /select 1")
            return

        project_ids = context.user_data.get("project_ids", [])
        if idx < 0 or idx >= len(project_ids):
            await update.message.reply_text("Ogiltigt nummer. Kör /projects först.")
            return

        context.user_data["active_project"] = project_ids[idx]
        await update.message.reply_text(f"Projekt {idx + 1} valt. Kör /status för info.")

    async def cmd_status(self, update: Update, context):
        """Handle /status — show active project status."""
        user = get_user_by_chat_id(str(update.effective_chat.id))
        if not user:
            await update.message.reply_text("Du är inte kopplad. Använd /link <kod> först.")
            return

        project_id = context.user_data.get("active_project")
        if not project_id:
            await update.message.reply_text("Inget projekt valt. Kör /projects och /select <nummer>.")
            return

        db = SessionLocal()
        try:
            project = db.query(Project).filter(
                Project.id == uuid.UUID(project_id),
                Project.user_id == user.id,
            ).first()

            if not project:
                await update.message.reply_text("Projektet hittades inte.")
                return

            status_text = {
                ProjectStatus.BRIEF: "📝 Brief inskickad — analyserar...",
                ProjectStatus.CLARIFICATION: "❓ Väntar på dina svar",
                ProjectStatus.MOODBOARD: "🎨 Moodboard klar — välj favorit",
                ProjectStatus.LAYOUTS: "📐 Layouts klara — välj favorit",
                ProjectStatus.EDITING: "✏️ Redigeringsläge",
                ProjectStatus.DONE: "✅ Klar!",
                ProjectStatus.FAILED: "❌ Fel uppstod",
            }.get(project.status, str(project.status))

            msg = f"Projekt: {project.brief[:80]}\nStatus: {status_text}"

            if project.error_message:
                msg += f"\nFel: {project.error_message}"

            await update.message.reply_text(msg)
        finally:
            db.close()

    # ------------------------------------------------------------------
    # Free-text handler — create project or edit page
    # ------------------------------------------------------------------

    async def handle_message(self, update: Update, context):
        """Handle free text — create new project, edit active project, or link with code."""
        text = update.message.text.strip()
        chat_id = str(update.effective_chat.id)

        # Check if it's a 6-digit code (for linking)
        if text.isdigit() and len(text) == 6:
            user = verify_link_code(text, chat_id)
            if user:
                await update.message.reply_text(
                    f"✅ Kopplat! Du är inloggad som {user.name} ({user.email}).\n\n"
                    "Skriv en brief för att starta ett nytt projekt!"
                )
                return
            # If code didn't work, fall through to normal handling

        user = get_user_by_chat_id(chat_id)
        if not user:
            await update.message.reply_text(
                "Du är inte kopplad än.\n\n"
                "Hämta en 6-siffrig kod i Apex-appen och skriv den här,\n"
                "eller använd /link <kod>"
            )
            return

        active_project = context.user_data.get("active_project")

        if active_project:
            # Try to edit active project
            await self._handle_edit(update, context, user, active_project, text)
        else:
            # Create new project
            await self._handle_new_project(update, context, user, text)

    async def _handle_new_project(self, update: Update, context, user: User, brief: str):
        """Create a new project from a Telegram brief."""
        await update.message.reply_text("⚡ Startar projekt! Jag analyserar din brief...")

        db = SessionLocal()
        try:
            from pathlib import Path

            project_id = uuid.uuid4()
            project_dir = str(Path(settings.storage_path) / str(project_id))
            project = Project(
                id=project_id,
                brief=brief,
                project_dir=project_dir,
                user_id=user.id,
            )
            db.add(project)
            db.commit()

            try:
                Path(project_dir).mkdir(parents=True, exist_ok=True)
            except Exception:
                pass

            context.user_data["active_project"] = str(project_id)

            # Kick off Phase 1 in background thread (same pattern as routes.py)
            def phase1_bg(pid: uuid.UUID):
                from apex_server.projects.generator import Generator
                from apex_server.projects.websocket import notify_clarification_needed, notify_error
                from apex_server.projects.routes import notify_from_thread

                bg_db = SessionLocal()
                try:
                    proj = bg_db.query(Project).filter_by(id=pid).first()
                    if proj:
                        gen = Generator(proj, bg_db)
                        result = gen.search_and_clarify()
                        notify_from_thread(
                            notify_clarification_needed(str(pid), result.get("questions", []))
                        )
                except Exception as e:
                    import traceback
                    traceback.print_exc()
                    proj = bg_db.query(Project).filter_by(id=pid).first()
                    if proj:
                        proj.status = ProjectStatus.FAILED
                        proj.error_message = str(e)
                        bg_db.commit()
                        notify_from_thread(notify_error(str(pid), str(e)))
                finally:
                    bg_db.close()

            thread = threading.Thread(target=phase1_bg, args=(project_id,), daemon=True)
            thread.start()

        finally:
            db.close()

    async def _handle_edit(self, update: Update, context, user: User, project_id: str, instruction: str):
        """Edit the active project's first page."""
        await update.message.reply_text("✏️ Redigerar...")

        db = SessionLocal()
        try:
            project = db.query(Project).filter(
                Project.id == uuid.UUID(project_id),
                Project.user_id == user.id,
            ).first()
            if not project:
                await update.message.reply_text("Projektet hittades inte.")
                return

            page = db.query(Page).filter(Page.project_id == project.id).first()
            if not page:
                await update.message.reply_text("Inga sidor att redigera ännu.")
                return

            # Run agentic edit in background thread
            def edit_bg(pid: uuid.UUID, page_id: uuid.UUID, instr: str):
                from apex_server.projects.generator import Generator
                from apex_server.projects.websocket import notify_page_updated
                from apex_server.projects.routes import notify_from_thread

                bg_db = SessionLocal()
                try:
                    proj = bg_db.query(Project).filter_by(id=pid).first()
                    if not proj:
                        return
                    gen = Generator(proj, bg_db)
                    gen.agentic_edit(instr, str(page_id))
                    notify_from_thread(notify_page_updated(str(pid), str(page_id)))
                except Exception as e:
                    print(f"[TELEGRAM] Edit error: {e}", flush=True)
                finally:
                    bg_db.close()

            thread = threading.Thread(
                target=edit_bg,
                args=(project.id, page.id, instruction),
                daemon=True,
            )
            thread.start()

        finally:
            db.close()

    # ------------------------------------------------------------------
    # Callback (inline-keyboard) handler — clarification answers
    # ------------------------------------------------------------------

    async def handle_callback(self, update: Update, context):
        """Handle inline keyboard button clicks (clarification answers)."""
        query = update.callback_query
        await query.answer()

        data = query.data  # format: "clarify:<project_id>:<q_index>:<option>"
        if not data.startswith("clarify:"):
            return

        parts = data.split(":", 3)
        if len(parts) < 4:
            return

        _, project_id, q_index, option = parts

        # Collect answers
        answers = context.user_data.setdefault("clarify_answers", {})
        answers[q_index] = option
        await query.edit_message_text(f"✓ {option}")

        # Check if all questions answered
        expected = context.user_data.get("clarify_count", 0)
        if len(answers) >= expected and expected > 0:
            # All answered — submit clarification
            answer_text = ". ".join(f"Q{k}: {v}" for k, v in sorted(answers.items()))
            context.user_data.pop("clarify_answers", None)
            context.user_data.pop("clarify_count", None)

            await query.message.reply_text("⏳ Alla svar mottagna — startar research & design...")

            # Call clarify endpoint logic in background
            def clarify_bg(pid_str: str, answer: str):
                from apex_server.projects.generator import Generator
                from apex_server.projects.websocket import (
                    notify_moodboard_ready, notify_layouts_ready, notify_error,
                )
                from apex_server.projects.routes import notify_from_thread

                bg_db = SessionLocal()
                try:
                    project = bg_db.query(Project).filter_by(id=uuid.UUID(pid_str)).first()
                    if not project:
                        return

                    # Save answer
                    clarification = project.clarification or {}
                    clarification["answer"] = answer
                    project.clarification = clarification
                    bg_db.commit()

                    gen = Generator(project, bg_db)
                    research_data = gen.research_brand()
                    notify_from_thread(notify_moodboard_ready(pid_str, research_data))

                    layouts = gen.generate_layouts()
                    notify_from_thread(notify_layouts_ready(pid_str, layouts))
                except Exception as e:
                    import traceback
                    traceback.print_exc()
                    project = bg_db.query(Project).filter_by(id=uuid.UUID(pid_str)).first()
                    if project:
                        project.status = ProjectStatus.FAILED
                        project.error_message = str(e)
                        bg_db.commit()
                        notify_from_thread(notify_error(pid_str, str(e)))
                finally:
                    bg_db.close()

            thread = threading.Thread(
                target=clarify_bg,
                args=(project_id, answer_text),
                daemon=True,
            )
            thread.start()

    # ------------------------------------------------------------------
    # Notifications — called from websocket.py
    # ------------------------------------------------------------------

    async def notify_user(self, user_id, message: str, reply_markup=None):
        """Send a notification to a user's Telegram chat (if linked)."""
        if not self.app or not self._running:
            return

        from apex_server.integrations.telegram_auth import get_user_by_id

        user = get_user_by_id(user_id)
        if not user or not user.telegram_chat_id:
            return

        try:
            await self.app.bot.send_message(
                chat_id=int(user.telegram_chat_id),
                text=message,
                reply_markup=reply_markup,
                parse_mode="HTML",
            )
        except Exception as e:
            print(f"[TELEGRAM] Failed to notify {user_id}: {e}", flush=True)

    async def notify_clarification(self, project_id: str, questions: list):
        """Send clarification questions as inline keyboard buttons."""
        if not self.app or not self._running:
            return

        # Look up project owner
        db = SessionLocal()
        try:
            project = db.query(Project).filter_by(id=uuid.UUID(project_id)).first()
            if not project:
                return
            user = db.query(User).filter_by(id=project.user_id).first()
            if not user or not user.telegram_chat_id:
                return
            chat_id = int(user.telegram_chat_id)
        finally:
            db.close()

        # Send each question as a separate message with inline buttons
        for i, q in enumerate(questions):
            question_text = q.get("question", q) if isinstance(q, dict) else str(q)
            options = q.get("options", []) if isinstance(q, dict) else []

            if options:
                buttons = [
                    [InlineKeyboardButton(
                        opt,
                        callback_data=f"clarify:{project_id}:{i}:{opt}"[:64],
                    )]
                    for opt in options[:4]  # Max 4 options
                ]
                markup = InlineKeyboardMarkup(buttons)
            else:
                markup = None

            try:
                await self.app.bot.send_message(
                    chat_id=chat_id,
                    text=question_text,
                    reply_markup=markup,
                )
            except Exception as e:
                print(f"[TELEGRAM] Failed to send question: {e}", flush=True)

        # Store expected question count in a way that persists for callback handler
        # (We'll set it via the callback context when answers come in)
        # For now, we rely on the callback handler to count questions dynamically.

    async def notify_project_event(self, project_id: str, message: str, preview_url: str = None):
        """Send a project status update to the project owner."""
        if not self.app or not self._running:
            return

        db = SessionLocal()
        try:
            project = db.query(Project).filter_by(id=uuid.UUID(project_id)).first()
            if not project:
                return
            user = db.query(User).filter_by(id=project.user_id).first()
            if not user or not user.telegram_chat_id:
                return
            chat_id = int(user.telegram_chat_id)
        finally:
            db.close()

        markup = None
        if preview_url:
            markup = InlineKeyboardMarkup([
                [InlineKeyboardButton("Öppna preview →", url=preview_url)]
            ])

        try:
            await self.app.bot.send_message(
                chat_id=chat_id,
                text=message,
                reply_markup=markup,
                parse_mode="HTML",
            )
        except Exception as e:
            print(f"[TELEGRAM] Failed to notify project event: {e}", flush=True)


# Global singleton
telegram_bot = TelegramBot()
