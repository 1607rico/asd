"""Leveling commands: rank, leaderboard-xp, setlevel, setxp, resetlevel + XP tracking."""

import random

import discord
from discord import app_commands
from discord.ext import commands

from utils.checks import is_admin
from utils.database import get_db
from utils.embed_helpers import info_embed, success_embed


def xp_for_level(level: int) -> int:
    """Calculate the total XP required to reach a given level."""
    return int(100 * (level ** 1.5))


def level_from_xp(xp: int) -> int:
    """Calculate the level from total XP."""
    level = 0
    while xp_for_level(level + 1) <= xp:
        level += 1
    return level


class Leveling(commands.Cog):
    """XP leveling system with per-message XP gain."""

    def __init__(self, bot: commands.Bot) -> None:
        self.bot = bot
        self._cooldowns: dict[tuple[int, int], float] = {}

    # ──────────────────────────── XP Listener ─────────────────────

    @commands.Cog.listener()
    async def on_message(self, message: discord.Message) -> None:
        if message.author.bot or message.guild is None:
            return

        import time

        key = (message.author.id, message.guild.id)
        now = time.time()

        # 60-second cooldown per user per guild
        if key in self._cooldowns and now - self._cooldowns[key] < 60:
            return
        self._cooldowns[key] = now

        xp_gain = random.randint(15, 40)

        db = await get_db()
        try:
            await db.execute(
                "INSERT OR IGNORE INTO leveling (user_id, guild_id) VALUES (?, ?)",
                (message.author.id, message.guild.id),
            )
            await db.execute(
                "UPDATE leveling SET xp = xp + ?, messages = messages + 1 WHERE user_id = ? AND guild_id = ?",
                (xp_gain, message.author.id, message.guild.id),
            )
            await db.commit()

            cursor = await db.execute(
                "SELECT xp, level FROM leveling WHERE user_id = ? AND guild_id = ?",
                (message.author.id, message.guild.id),
            )
            row = await cursor.fetchone()
        finally:
            await db.close()

        if not row:
            return

        current_xp, current_level = row[0], row[1]
        new_level = level_from_xp(current_xp)

        if new_level > current_level:
            db = await get_db()
            try:
                await db.execute(
                    "UPDATE leveling SET level = ? WHERE user_id = ? AND guild_id = ?",
                    (new_level, message.author.id, message.guild.id),
                )
                await db.commit()
            finally:
                await db.close()

            try:
                await message.channel.send(
                    embed=success_embed(
                        "Level Up!",
                        f"\U0001f389 {message.author.mention} reached **Level {new_level}**!",
                    )
                )
            except discord.Forbidden:
                pass

    # ──────────────────────────── Rank ────────────────────────────

    @app_commands.command(name="rank", description="View your or another user's level and XP")
    @app_commands.describe(member="The user to check (defaults to yourself)")
    async def rank(
        self,
        interaction: discord.Interaction,
        member: discord.Member | None = None,
    ) -> None:
        assert interaction.guild is not None
        target = member or interaction.user

        db = await get_db()
        try:
            await db.execute(
                "INSERT OR IGNORE INTO leveling (user_id, guild_id) VALUES (?, ?)",
                (target.id, interaction.guild.id),
            )
            await db.commit()

            cursor = await db.execute(
                "SELECT xp, level, messages FROM leveling WHERE user_id = ? AND guild_id = ?",
                (target.id, interaction.guild.id),
            )
            row = await cursor.fetchone()

            # Get rank position
            cursor = await db.execute(
                "SELECT COUNT(*) FROM leveling WHERE guild_id = ? AND xp > (SELECT xp FROM leveling WHERE user_id = ? AND guild_id = ?)",
                (interaction.guild.id, target.id, interaction.guild.id),
            )
            rank_row = await cursor.fetchone()
            rank_pos = (rank_row[0] if rank_row else 0) + 1
        finally:
            await db.close()

        if not row:
            xp, level, messages = 0, 0, 0
        else:
            xp, level, messages = row[0], row[1], row[2]

        next_level_xp = xp_for_level(level + 1)
        current_level_xp = xp_for_level(level)
        progress_xp = xp - current_level_xp
        needed_xp = next_level_xp - current_level_xp
        progress_pct = (progress_xp / needed_xp * 100) if needed_xp > 0 else 0

        # Progress bar
        filled = int(progress_pct / 10)
        bar = "\u2588" * filled + "\u2591" * (10 - filled)

        embed = discord.Embed(
            title=f"\U0001f4c8 {target.display_name}'s Rank",
            color=target.color if isinstance(target, discord.Member) else discord.Color.blurple(),
        )
        embed.set_thumbnail(url=target.display_avatar.url)
        embed.add_field(name="Rank", value=f"#{rank_pos}", inline=True)
        embed.add_field(name="Level", value=str(level), inline=True)
        embed.add_field(name="Total XP", value=f"{xp:,}", inline=True)
        embed.add_field(name="Messages", value=f"{messages:,}", inline=True)
        embed.add_field(
            name=f"Progress [{progress_pct:.0f}%]",
            value=f"`{bar}` {progress_xp:,}/{needed_xp:,} XP",
            inline=False,
        )

        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── Leaderboard XP ──────────────────

    @app_commands.command(name="leaderboard-xp", description="View the XP leaderboard")
    async def leaderboard_xp(self, interaction: discord.Interaction) -> None:
        assert interaction.guild is not None

        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT user_id, level, xp FROM leveling WHERE guild_id = ? ORDER BY xp DESC LIMIT 10",
                (interaction.guild.id,),
            )
            rows = await cursor.fetchall()
        finally:
            await db.close()

        if not rows:
            await interaction.response.send_message(
                embed=info_embed("Leaderboard", "No leveling data yet!"),
                ephemeral=True,
            )
            return

        medals = ["\U0001f947", "\U0001f948", "\U0001f949"]
        description = ""
        for i, row in enumerate(rows):
            prefix = medals[i] if i < 3 else f"**#{i + 1}**"
            description += f"{prefix} <@{row[0]}> — Level **{row[1]}** ({row[2]:,} XP)\n"

        embed = discord.Embed(
            title="\U0001f4c8 XP Leaderboard",
            description=description,
            color=discord.Color.purple(),
        )
        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── Set Level (Admin) ───────────────

    @app_commands.command(name="setlevel", description="Set a user's level (Admin)")
    @app_commands.describe(member="The user", level="The level to set")
    @app_commands.default_permissions(administrator=True)
    @is_admin()
    async def setlevel(
        self,
        interaction: discord.Interaction,
        member: discord.Member,
        level: app_commands.Range[int, 0, 1000],
    ) -> None:
        assert interaction.guild is not None

        new_xp = xp_for_level(level)
        db = await get_db()
        try:
            await db.execute(
                "INSERT OR IGNORE INTO leveling (user_id, guild_id) VALUES (?, ?)",
                (member.id, interaction.guild.id),
            )
            await db.execute(
                "UPDATE leveling SET level = ?, xp = ? WHERE user_id = ? AND guild_id = ?",
                (level, new_xp, member.id, interaction.guild.id),
            )
            await db.commit()
        finally:
            await db.close()

        await interaction.response.send_message(
            embed=success_embed("Level Set", f"**{member}**'s level set to **{level}**.")
        )

    # ──────────────────────────── Set XP (Admin) ──────────────────

    @app_commands.command(name="setxp", description="Set a user's XP (Admin)")
    @app_commands.describe(member="The user", xp="The XP amount to set")
    @app_commands.default_permissions(administrator=True)
    @is_admin()
    async def setxp(
        self,
        interaction: discord.Interaction,
        member: discord.Member,
        xp: app_commands.Range[int, 0],
    ) -> None:
        assert interaction.guild is not None

        new_level = level_from_xp(xp)
        db = await get_db()
        try:
            await db.execute(
                "INSERT OR IGNORE INTO leveling (user_id, guild_id) VALUES (?, ?)",
                (member.id, interaction.guild.id),
            )
            await db.execute(
                "UPDATE leveling SET xp = ?, level = ? WHERE user_id = ? AND guild_id = ?",
                (xp, new_level, member.id, interaction.guild.id),
            )
            await db.commit()
        finally:
            await db.close()

        await interaction.response.send_message(
            embed=success_embed("XP Set", f"**{member}**'s XP set to **{xp:,}** (Level {new_level}).")
        )

    # ──────────────────────────── Reset Level (Admin) ─────────────

    @app_commands.command(name="resetlevel", description="Reset a user's level and XP (Admin)")
    @app_commands.describe(member="The user to reset")
    @app_commands.default_permissions(administrator=True)
    @is_admin()
    async def resetlevel(
        self,
        interaction: discord.Interaction,
        member: discord.Member,
    ) -> None:
        assert interaction.guild is not None

        db = await get_db()
        try:
            await db.execute(
                "DELETE FROM leveling WHERE user_id = ? AND guild_id = ?",
                (member.id, interaction.guild.id),
            )
            await db.commit()
        finally:
            await db.close()

        await interaction.response.send_message(
            embed=success_embed("Level Reset", f"**{member}**'s level and XP have been reset.")
        )


async def setup(bot: commands.Bot) -> None:
    await bot.add_cog(Leveling(bot))
