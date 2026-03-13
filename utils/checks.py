"""Custom permission checks for commands."""

import discord
from discord import app_commands


def is_admin():
    """Check if the user has administrator permissions."""

    def predicate(interaction: discord.Interaction) -> bool:
        if not interaction.guild:
            return False
        member = interaction.guild.get_member(interaction.user.id)
        if member is None:
            return False
        return member.guild_permissions.administrator

    return app_commands.check(predicate)


def is_moderator():
    """Check if the user has moderation permissions."""

    def predicate(interaction: discord.Interaction) -> bool:
        if not interaction.guild:
            return False
        member = interaction.guild.get_member(interaction.user.id)
        if member is None:
            return False
        perms = member.guild_permissions
        return (
            perms.administrator
            or perms.manage_guild
            or perms.kick_members
            or perms.ban_members
            or perms.manage_messages
        )

    return app_commands.check(predicate)
