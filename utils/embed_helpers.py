"""Helper functions for creating consistent embeds."""

import discord
from datetime import datetime, timezone


def success_embed(title: str, description: str) -> discord.Embed:
    """Create a green success embed."""
    embed = discord.Embed(
        title=f"\u2705 {title}",
        description=description,
        color=discord.Color.green(),
        timestamp=datetime.now(timezone.utc),
    )
    return embed


def error_embed(title: str, description: str) -> discord.Embed:
    """Create a red error embed."""
    embed = discord.Embed(
        title=f"\u274c {title}",
        description=description,
        color=discord.Color.red(),
        timestamp=datetime.now(timezone.utc),
    )
    return embed


def info_embed(title: str, description: str) -> discord.Embed:
    """Create a blue info embed."""
    embed = discord.Embed(
        title=f"\u2139\ufe0f {title}",
        description=description,
        color=discord.Color.blue(),
        timestamp=datetime.now(timezone.utc),
    )
    return embed


def warning_embed(title: str, description: str) -> discord.Embed:
    """Create a yellow warning embed."""
    embed = discord.Embed(
        title=f"\u26a0\ufe0f {title}",
        description=description,
        color=discord.Color.yellow(),
        timestamp=datetime.now(timezone.utc),
    )
    return embed
