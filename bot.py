"""
Discord Bot - A comprehensive bot with moderation, fun, utility, economy, leveling, and music commands.
"""

import asyncio
import logging
import os
import sys

import discord
from discord.ext import commands
from dotenv import load_dotenv

from utils.database import init_db

load_dotenv()

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("bot.log", encoding="utf-8"),
    ],
)
log = logging.getLogger("bot")

TOKEN = os.getenv("DISCORD_TOKEN")
PREFIX = os.getenv("BOT_PREFIX", "!")

COGS = [
    "cogs.moderation",
    "cogs.utility",
    "cogs.fun",
    "cogs.admin",
    "cogs.economy",
    "cogs.leveling",
    "cogs.music",
]


class Bot(commands.Bot):
    """Custom bot class with cog loading and database initialization."""

    def __init__(self) -> None:
        intents = discord.Intents.all()
        super().__init__(
            command_prefix=PREFIX,
            intents=intents,
            help_command=None,
            activity=discord.Activity(
                type=discord.ActivityType.watching, name="/help"
            ),
        )

    async def setup_hook(self) -> None:
        """Load cogs and sync slash commands."""
        log.info("Initializing database...")
        await init_db()

        for cog in COGS:
            try:
                await self.load_extension(cog)
                log.info("Loaded cog: %s", cog)
            except Exception:
                log.exception("Failed to load cog: %s", cog)

        log.info("Syncing slash commands...")
        await self.tree.sync()
        log.info("Slash commands synced.")

    async def on_ready(self) -> None:
        """Called when the bot is ready."""
        assert self.user is not None
        log.info("Logged in as %s (ID: %s)", self.user, self.user.id)
        log.info("Connected to %d guilds", len(self.guilds))
        log.info("Bot is ready!")


async def main() -> None:
    """Entry point."""
    if not TOKEN:
        log.error("DISCORD_TOKEN not found. Set it in .env or environment variables.")
        sys.exit(1)

    bot = Bot()
    async with bot:
        await bot.start(TOKEN)


if __name__ == "__main__":
    asyncio.run(main())
