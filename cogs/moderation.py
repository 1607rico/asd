"""Moderation commands: kick, ban, unban, mute, unmute, warn, warnings, purge."""

import discord
from discord import app_commands
from discord.ext import commands

from utils.checks import is_moderator
from utils.database import get_db
from utils.embed_helpers import error_embed, success_embed


class Moderation(commands.Cog):
    """Moderation commands for managing server members."""

    def __init__(self, bot: commands.Bot) -> None:
        self.bot = bot

    # ──────────────────────────── Kick ────────────────────────────

    @app_commands.command(name="kick", description="Kick a member from the server")
    @app_commands.describe(member="The member to kick", reason="Reason for kicking")
    @app_commands.default_permissions(kick_members=True)
    @is_moderator()
    async def kick(
        self,
        interaction: discord.Interaction,
        member: discord.Member,
        reason: str = "No reason provided",
    ) -> None:
        assert interaction.guild is not None

        if member.top_role >= interaction.user.top_role:  # type: ignore[union-attr]
            await interaction.response.send_message(
                embed=error_embed("Error", "You cannot kick someone with an equal or higher role."),
                ephemeral=True,
            )
            return

        try:
            await member.send(
                embed=error_embed(
                    "Kicked",
                    f"You have been kicked from **{interaction.guild.name}**.\nReason: {reason}",
                )
            )
        except discord.Forbidden:
            pass

        await interaction.guild.kick(member, reason=reason)
        await interaction.response.send_message(
            embed=success_embed("Member Kicked", f"**{member}** has been kicked.\nReason: {reason}")
        )

    # ──────────────────────────── Ban ─────────────────────────────

    @app_commands.command(name="ban", description="Ban a member from the server")
    @app_commands.describe(member="The member to ban", reason="Reason for banning")
    @app_commands.default_permissions(ban_members=True)
    @is_moderator()
    async def ban(
        self,
        interaction: discord.Interaction,
        member: discord.Member,
        reason: str = "No reason provided",
    ) -> None:
        assert interaction.guild is not None

        if member.top_role >= interaction.user.top_role:  # type: ignore[union-attr]
            await interaction.response.send_message(
                embed=error_embed("Error", "You cannot ban someone with an equal or higher role."),
                ephemeral=True,
            )
            return

        try:
            await member.send(
                embed=error_embed(
                    "Banned",
                    f"You have been banned from **{interaction.guild.name}**.\nReason: {reason}",
                )
            )
        except discord.Forbidden:
            pass

        await interaction.guild.ban(member, reason=reason)
        await interaction.response.send_message(
            embed=success_embed("Member Banned", f"**{member}** has been banned.\nReason: {reason}")
        )

    # ──────────────────────────── Unban ───────────────────────────

    @app_commands.command(name="unban", description="Unban a user from the server")
    @app_commands.describe(user_id="The user ID to unban", reason="Reason for unbanning")
    @app_commands.default_permissions(ban_members=True)
    @is_moderator()
    async def unban(
        self,
        interaction: discord.Interaction,
        user_id: str,
        reason: str = "No reason provided",
    ) -> None:
        assert interaction.guild is not None

        try:
            user = await self.bot.fetch_user(int(user_id))
            await interaction.guild.unban(user, reason=reason)
            await interaction.response.send_message(
                embed=success_embed("User Unbanned", f"**{user}** has been unbanned.\nReason: {reason}")
            )
        except (ValueError, discord.NotFound):
            await interaction.response.send_message(
                embed=error_embed("Error", "User not found. Please provide a valid user ID."),
                ephemeral=True,
            )

    # ──────────────────────────── Mute (Timeout) ──────────────────

    @app_commands.command(name="mute", description="Timeout a member (mute)")
    @app_commands.describe(
        member="The member to mute",
        duration="Duration in minutes",
        reason="Reason for muting",
    )
    @app_commands.default_permissions(moderate_members=True)
    @is_moderator()
    async def mute(
        self,
        interaction: discord.Interaction,
        member: discord.Member,
        duration: int = 10,
        reason: str = "No reason provided",
    ) -> None:
        import datetime

        if member.top_role >= interaction.user.top_role:  # type: ignore[union-attr]
            await interaction.response.send_message(
                embed=error_embed("Error", "You cannot mute someone with an equal or higher role."),
                ephemeral=True,
            )
            return

        delta = datetime.timedelta(minutes=duration)
        await member.timeout(delta, reason=reason)
        await interaction.response.send_message(
            embed=success_embed(
                "Member Muted",
                f"**{member}** has been muted for **{duration} minutes**.\nReason: {reason}",
            )
        )

    # ──────────────────────────── Unmute ──────────────────────────

    @app_commands.command(name="unmute", description="Remove timeout from a member (unmute)")
    @app_commands.describe(member="The member to unmute")
    @app_commands.default_permissions(moderate_members=True)
    @is_moderator()
    async def unmute(
        self,
        interaction: discord.Interaction,
        member: discord.Member,
    ) -> None:
        await member.timeout(None)
        await interaction.response.send_message(
            embed=success_embed("Member Unmuted", f"**{member}** has been unmuted.")
        )

    # ──────────────────────────── Warn ────────────────────────────

    @app_commands.command(name="warn", description="Warn a member")
    @app_commands.describe(member="The member to warn", reason="Reason for warning")
    @app_commands.default_permissions(manage_messages=True)
    @is_moderator()
    async def warn(
        self,
        interaction: discord.Interaction,
        member: discord.Member,
        reason: str = "No reason provided",
    ) -> None:
        assert interaction.guild is not None

        db = await get_db()
        try:
            await db.execute(
                "INSERT INTO warnings (guild_id, user_id, moderator_id, reason) VALUES (?, ?, ?, ?)",
                (interaction.guild.id, member.id, interaction.user.id, reason),
            )
            await db.commit()

            cursor = await db.execute(
                "SELECT COUNT(*) FROM warnings WHERE guild_id = ? AND user_id = ?",
                (interaction.guild.id, member.id),
            )
            row = await cursor.fetchone()
            count = row[0] if row else 0
        finally:
            await db.close()

        await interaction.response.send_message(
            embed=success_embed(
                "Member Warned",
                f"**{member}** has been warned.\nReason: {reason}\nTotal warnings: **{count}**",
            )
        )

        try:
            await member.send(
                embed=error_embed(
                    "Warning",
                    f"You have been warned in **{interaction.guild.name}**.\nReason: {reason}\nTotal warnings: **{count}**",
                )
            )
        except discord.Forbidden:
            pass

    # ──────────────────────────── Warnings ────────────────────────

    @app_commands.command(name="warnings", description="View warnings for a member")
    @app_commands.describe(member="The member to check")
    @is_moderator()
    async def warnings(
        self,
        interaction: discord.Interaction,
        member: discord.Member,
    ) -> None:
        assert interaction.guild is not None

        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT id, moderator_id, reason, created_at FROM warnings WHERE guild_id = ? AND user_id = ? ORDER BY created_at DESC LIMIT 10",
                (interaction.guild.id, member.id),
            )
            rows = await cursor.fetchall()
        finally:
            await db.close()

        if not rows:
            await interaction.response.send_message(
                embed=success_embed("No Warnings", f"**{member}** has no warnings."),
                ephemeral=True,
            )
            return

        description = ""
        for row in rows:
            description += f"**#{row[0]}** | By <@{row[1]}> | {row[3]}\n> {row[2]}\n\n"

        embed = discord.Embed(
            title=f"Warnings for {member}",
            description=description,
            color=discord.Color.orange(),
        )
        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── Clear Warning ───────────────────

    @app_commands.command(name="clearwarn", description="Clear a specific warning by ID")
    @app_commands.describe(warning_id="The warning ID to remove")
    @app_commands.default_permissions(manage_messages=True)
    @is_moderator()
    async def clearwarn(
        self,
        interaction: discord.Interaction,
        warning_id: int,
    ) -> None:
        assert interaction.guild is not None

        db = await get_db()
        try:
            cursor = await db.execute(
                "DELETE FROM warnings WHERE id = ? AND guild_id = ?",
                (warning_id, interaction.guild.id),
            )
            await db.commit()
            deleted = cursor.rowcount
        finally:
            await db.close()

        if deleted:
            await interaction.response.send_message(
                embed=success_embed("Warning Cleared", f"Warning **#{warning_id}** has been removed.")
            )
        else:
            await interaction.response.send_message(
                embed=error_embed("Error", "Warning not found."),
                ephemeral=True,
            )

    # ──────────────────────────── Purge ───────────────────────────

    @app_commands.command(name="purge", description="Delete multiple messages at once")
    @app_commands.describe(amount="Number of messages to delete (1-100)")
    @app_commands.default_permissions(manage_messages=True)
    @is_moderator()
    async def purge(
        self,
        interaction: discord.Interaction,
        amount: app_commands.Range[int, 1, 100] = 10,
    ) -> None:
        assert isinstance(interaction.channel, discord.TextChannel)

        await interaction.response.defer(ephemeral=True)
        deleted = await interaction.channel.purge(limit=amount)
        await interaction.followup.send(
            embed=success_embed("Messages Purged", f"Deleted **{len(deleted)}** messages."),
            ephemeral=True,
        )

    # ──────────────────────────── Slowmode ────────────────────────

    @app_commands.command(name="slowmode", description="Set slowmode for the channel")
    @app_commands.describe(seconds="Slowmode delay in seconds (0 to disable)")
    @app_commands.default_permissions(manage_channels=True)
    @is_moderator()
    async def slowmode(
        self,
        interaction: discord.Interaction,
        seconds: app_commands.Range[int, 0, 21600] = 0,
    ) -> None:
        assert isinstance(interaction.channel, discord.TextChannel)

        await interaction.channel.edit(slowmode_delay=seconds)
        if seconds == 0:
            await interaction.response.send_message(
                embed=success_embed("Slowmode Disabled", "Slowmode has been disabled for this channel.")
            )
        else:
            await interaction.response.send_message(
                embed=success_embed("Slowmode Set", f"Slowmode set to **{seconds} seconds**.")
            )

    # ──────────────────────────── Lock / Unlock ───────────────────

    @app_commands.command(name="lock", description="Lock the current channel")
    @app_commands.default_permissions(manage_channels=True)
    @is_moderator()
    async def lock(self, interaction: discord.Interaction) -> None:
        assert interaction.guild is not None
        assert isinstance(interaction.channel, discord.TextChannel)

        overwrite = interaction.channel.overwrites_for(interaction.guild.default_role)
        overwrite.send_messages = False
        await interaction.channel.set_permissions(interaction.guild.default_role, overwrite=overwrite)
        await interaction.response.send_message(
            embed=success_embed("Channel Locked", "This channel has been locked.")
        )

    @app_commands.command(name="unlock", description="Unlock the current channel")
    @app_commands.default_permissions(manage_channels=True)
    @is_moderator()
    async def unlock(self, interaction: discord.Interaction) -> None:
        assert interaction.guild is not None
        assert isinstance(interaction.channel, discord.TextChannel)

        overwrite = interaction.channel.overwrites_for(interaction.guild.default_role)
        overwrite.send_messages = None
        await interaction.channel.set_permissions(interaction.guild.default_role, overwrite=overwrite)
        await interaction.response.send_message(
            embed=success_embed("Channel Unlocked", "This channel has been unlocked.")
        )


async def setup(bot: commands.Bot) -> None:
    await bot.add_cog(Moderation(bot))
