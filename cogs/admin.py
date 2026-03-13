"""Admin commands: setprefix, setwelcome, setautorole, setlogchannel, settings."""

import discord
from discord import app_commands
from discord.ext import commands

from utils.checks import is_admin
from utils.database import get_db
from utils.embed_helpers import error_embed, info_embed, success_embed


class Admin(commands.Cog):
    """Admin commands for server configuration."""

    def __init__(self, bot: commands.Bot) -> None:
        self.bot = bot

    async def _ensure_guild(self, guild_id: int) -> None:
        """Ensure a guild entry exists in settings."""
        db = await get_db()
        try:
            await db.execute(
                "INSERT OR IGNORE INTO guild_settings (guild_id) VALUES (?)",
                (guild_id,),
            )
            await db.commit()
        finally:
            await db.close()

    # ──────────────────────────── Set Prefix ──────────────────────

    @app_commands.command(name="setprefix", description="Set the bot prefix for this server")
    @app_commands.describe(prefix="The new prefix")
    @app_commands.default_permissions(administrator=True)
    @is_admin()
    async def setprefix(self, interaction: discord.Interaction, prefix: str) -> None:
        assert interaction.guild is not None

        if len(prefix) > 5:
            await interaction.response.send_message(
                embed=error_embed("Error", "Prefix must be 5 characters or fewer."),
                ephemeral=True,
            )
            return

        await self._ensure_guild(interaction.guild.id)
        db = await get_db()
        try:
            await db.execute(
                "UPDATE guild_settings SET prefix = ? WHERE guild_id = ?",
                (prefix, interaction.guild.id),
            )
            await db.commit()
        finally:
            await db.close()

        await interaction.response.send_message(
            embed=success_embed("Prefix Updated", f"Server prefix set to `{prefix}`")
        )

    # ──────────────────────────── Set Welcome ─────────────────────

    @app_commands.command(name="setwelcome", description="Set the welcome channel and message")
    @app_commands.describe(
        channel="The channel for welcome messages",
        message="Welcome message ({user} = mention, {server} = server name, {count} = member count)",
    )
    @app_commands.default_permissions(administrator=True)
    @is_admin()
    async def setwelcome(
        self,
        interaction: discord.Interaction,
        channel: discord.TextChannel,
        message: str = "Welcome {user} to **{server}**! You are member #{count}.",
    ) -> None:
        assert interaction.guild is not None

        await self._ensure_guild(interaction.guild.id)
        db = await get_db()
        try:
            await db.execute(
                "UPDATE guild_settings SET welcome_channel_id = ?, welcome_message = ? WHERE guild_id = ?",
                (channel.id, message, interaction.guild.id),
            )
            await db.commit()
        finally:
            await db.close()

        preview = message.format(user=interaction.user.mention, server=interaction.guild.name, count=interaction.guild.member_count)
        await interaction.response.send_message(
            embed=success_embed(
                "Welcome Message Set",
                f"Channel: {channel.mention}\n\n**Preview:**\n{preview}",
            )
        )

    # ──────────────────────────── Set Autorole ────────────────────

    @app_commands.command(name="setautorole", description="Set a role to be automatically assigned to new members")
    @app_commands.describe(role="The role to assign (set to @everyone to disable)")
    @app_commands.default_permissions(administrator=True)
    @is_admin()
    async def setautorole(
        self,
        interaction: discord.Interaction,
        role: discord.Role,
    ) -> None:
        assert interaction.guild is not None

        await self._ensure_guild(interaction.guild.id)
        db = await get_db()
        try:
            role_id = None if role.id == interaction.guild.id else role.id
            await db.execute(
                "UPDATE guild_settings SET autorole_id = ? WHERE guild_id = ?",
                (role_id, interaction.guild.id),
            )
            await db.commit()
        finally:
            await db.close()

        if role_id:
            await interaction.response.send_message(
                embed=success_embed("Autorole Set", f"New members will receive {role.mention}")
            )
        else:
            await interaction.response.send_message(
                embed=success_embed("Autorole Disabled", "Autorole has been disabled.")
            )

    # ──────────────────────────── Set Log Channel ─────────────────

    @app_commands.command(name="setlogchannel", description="Set the log channel for mod actions")
    @app_commands.describe(channel="The channel for logging (leave empty to disable)")
    @app_commands.default_permissions(administrator=True)
    @is_admin()
    async def setlogchannel(
        self,
        interaction: discord.Interaction,
        channel: discord.TextChannel | None = None,
    ) -> None:
        assert interaction.guild is not None

        await self._ensure_guild(interaction.guild.id)
        db = await get_db()
        try:
            await db.execute(
                "UPDATE guild_settings SET log_channel_id = ? WHERE guild_id = ?",
                (channel.id if channel else None, interaction.guild.id),
            )
            await db.commit()
        finally:
            await db.close()

        if channel:
            await interaction.response.send_message(
                embed=success_embed("Log Channel Set", f"Mod actions will be logged in {channel.mention}")
            )
        else:
            await interaction.response.send_message(
                embed=success_embed("Log Channel Disabled", "Mod action logging has been disabled.")
            )

    # ──────────────────────────── Settings ────────────────────────

    @app_commands.command(name="settings", description="View current server settings")
    @app_commands.default_permissions(administrator=True)
    @is_admin()
    async def settings(self, interaction: discord.Interaction) -> None:
        assert interaction.guild is not None

        await self._ensure_guild(interaction.guild.id)
        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT * FROM guild_settings WHERE guild_id = ?",
                (interaction.guild.id,),
            )
            row = await cursor.fetchone()
        finally:
            await db.close()

        if not row:
            await interaction.response.send_message(
                embed=info_embed("Settings", "No settings configured yet."),
                ephemeral=True,
            )
            return

        prefix = row[1] or "!"
        welcome_ch = f"<#{row[2]}>" if row[2] else "Not set"
        welcome_msg = row[3] or "Not set"
        autorole = f"<@&{row[4]}>" if row[4] else "Not set"
        log_ch = f"<#{row[5]}>" if row[5] else "Not set"

        embed = discord.Embed(title="Server Settings", color=discord.Color.blurple())
        embed.add_field(name="Prefix", value=f"`{prefix}`", inline=True)
        embed.add_field(name="Welcome Channel", value=welcome_ch, inline=True)
        embed.add_field(name="Autorole", value=autorole, inline=True)
        embed.add_field(name="Log Channel", value=log_ch, inline=True)
        embed.add_field(name="Welcome Message", value=f"```{welcome_msg}```", inline=False)

        await interaction.response.send_message(embed=embed, ephemeral=True)

    # ──────────────────────────── Events ──────────────────────────

    @commands.Cog.listener()
    async def on_member_join(self, member: discord.Member) -> None:
        """Handle welcome message and autorole on member join."""
        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT welcome_channel_id, welcome_message, autorole_id FROM guild_settings WHERE guild_id = ?",
                (member.guild.id,),
            )
            row = await cursor.fetchone()
        finally:
            await db.close()

        if not row:
            return

        # Welcome message
        if row[0] and row[1]:
            channel = member.guild.get_channel(row[0])
            if channel and isinstance(channel, discord.TextChannel):
                message = row[1].format(
                    user=member.mention,
                    server=member.guild.name,
                    count=member.guild.member_count,
                )
                embed = discord.Embed(
                    title="Welcome!",
                    description=message,
                    color=discord.Color.green(),
                )
                if member.avatar:
                    embed.set_thumbnail(url=member.avatar.url)
                await channel.send(embed=embed)

        # Autorole
        if row[2]:
            role = member.guild.get_role(row[2])
            if role:
                try:
                    await member.add_roles(role, reason="Autorole")
                except discord.Forbidden:
                    pass


async def setup(bot: commands.Bot) -> None:
    await bot.add_cog(Admin(bot))
