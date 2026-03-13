"""Utility commands: ping, serverinfo, userinfo, avatar, banner, help, poll, embed, timer."""


import discord
from discord import app_commands
from discord.ext import commands

from utils.embed_helpers import info_embed


class HelpSelect(discord.ui.Select["HelpView"]):
    """Dropdown for selecting a help category."""

    def __init__(self, bot: commands.Bot) -> None:
        self.bot = bot
        options = [
            discord.SelectOption(label="Moderation", description="Kick, ban, mute, warn, purge...", emoji="\U0001f6e1\ufe0f"),
            discord.SelectOption(label="Utility", description="Ping, serverinfo, userinfo, avatar...", emoji="\U0001f527"),
            discord.SelectOption(label="Fun", description="8ball, coinflip, dice, rps, joke...", emoji="\U0001f3b2"),
            discord.SelectOption(label="Admin", description="Prefix, welcome, autorole, logs...", emoji="\u2699\ufe0f"),
            discord.SelectOption(label="Economy", description="Balance, daily, work, shop, pay...", emoji="\U0001f4b0"),
            discord.SelectOption(label="Leveling", description="Rank, leaderboard, XP...", emoji="\U0001f4c8"),
            discord.SelectOption(label="Music", description="Play, skip, stop, queue, volume...", emoji="\U0001f3b5"),
        ]
        super().__init__(placeholder="Choose a category...", options=options)

    async def callback(self, interaction: discord.Interaction) -> None:
        category = self.values[0]
        cog = self.bot.get_cog(category)
        if cog is None:
            await interaction.response.send_message("Category not found.", ephemeral=True)
            return

        commands_list = cog.get_app_commands()
        description = "\n".join(f"`/{cmd.name}` — {cmd.description}" for cmd in commands_list)
        embed = discord.Embed(
            title=f"{category} Commands",
            description=description or "No commands available.",
            color=discord.Color.blurple(),
        )
        await interaction.response.send_message(embed=embed, ephemeral=True)


class HelpView(discord.ui.View):
    """View containing the help dropdown."""

    def __init__(self, bot: commands.Bot) -> None:
        super().__init__(timeout=120)
        self.add_item(HelpSelect(bot))


class Utility(commands.Cog):
    """Utility commands for general information."""

    def __init__(self, bot: commands.Bot) -> None:
        self.bot = bot

    # ──────────────────────────── Ping ────────────────────────────

    @app_commands.command(name="ping", description="Check the bot's latency")
    async def ping(self, interaction: discord.Interaction) -> None:
        latency = round(self.bot.latency * 1000)
        await interaction.response.send_message(
            embed=info_embed("Pong!", f"Latency: **{latency}ms**")
        )

    # ──────────────────────────── Server Info ─────────────────────

    @app_commands.command(name="serverinfo", description="Display information about the server")
    async def serverinfo(self, interaction: discord.Interaction) -> None:
        guild = interaction.guild
        if guild is None:
            await interaction.response.send_message("This command can only be used in a server.", ephemeral=True)
            return

        embed = discord.Embed(title=guild.name, color=discord.Color.blurple())
        if guild.icon:
            embed.set_thumbnail(url=guild.icon.url)

        text_channels = len(guild.text_channels)
        voice_channels = len(guild.voice_channels)
        categories = len(guild.categories)
        roles = len(guild.roles) - 1  # Exclude @everyone
        emojis = len(guild.emojis)

        embed.add_field(name="Owner", value=str(guild.owner), inline=True)
        embed.add_field(name="Members", value=str(guild.member_count), inline=True)
        embed.add_field(name="Roles", value=str(roles), inline=True)
        embed.add_field(name="Text Channels", value=str(text_channels), inline=True)
        embed.add_field(name="Voice Channels", value=str(voice_channels), inline=True)
        embed.add_field(name="Categories", value=str(categories), inline=True)
        embed.add_field(name="Emojis", value=str(emojis), inline=True)
        embed.add_field(name="Boost Level", value=str(guild.premium_tier), inline=True)
        embed.add_field(name="Boosts", value=str(guild.premium_subscription_count), inline=True)
        embed.add_field(
            name="Created",
            value=discord.utils.format_dt(guild.created_at, style="R"),
            inline=True,
        )
        embed.set_footer(text=f"ID: {guild.id}")

        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── User Info ───────────────────────

    @app_commands.command(name="userinfo", description="Display information about a user")
    @app_commands.describe(member="The user to look up (defaults to yourself)")
    async def userinfo(
        self,
        interaction: discord.Interaction,
        member: discord.Member | None = None,
    ) -> None:
        target = member or interaction.user
        assert interaction.guild is not None
        guild_member = interaction.guild.get_member(target.id)

        embed = discord.Embed(title=str(target), color=target.color if guild_member else discord.Color.blurple())
        embed.set_thumbnail(url=target.display_avatar.url)

        embed.add_field(name="ID", value=str(target.id), inline=True)
        embed.add_field(
            name="Account Created",
            value=discord.utils.format_dt(target.created_at, style="R"),
            inline=True,
        )

        if guild_member:
            joined = guild_member.joined_at
            if joined:
                embed.add_field(
                    name="Joined Server",
                    value=discord.utils.format_dt(joined, style="R"),
                    inline=True,
                )
            roles = [r.mention for r in guild_member.roles[1:]]  # skip @everyone
            if roles:
                embed.add_field(name=f"Roles [{len(roles)}]", value=" ".join(roles[:20]), inline=False)

        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── Avatar ──────────────────────────

    @app_commands.command(name="avatar", description="Display a user's avatar")
    @app_commands.describe(member="The user whose avatar to show")
    async def avatar(
        self,
        interaction: discord.Interaction,
        member: discord.Member | None = None,
    ) -> None:
        target = member or interaction.user
        embed = discord.Embed(title=f"{target}'s Avatar", color=discord.Color.blurple())
        embed.set_image(url=target.display_avatar.with_size(1024).url)
        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── Banner ──────────────────────────

    @app_commands.command(name="banner", description="Display a user's banner")
    @app_commands.describe(member="The user whose banner to show")
    async def banner(
        self,
        interaction: discord.Interaction,
        member: discord.Member | None = None,
    ) -> None:
        target = member or interaction.user
        user = await self.bot.fetch_user(target.id)
        if user.banner is None:
            await interaction.response.send_message(
                embed=info_embed("No Banner", f"**{target}** does not have a banner."),
                ephemeral=True,
            )
            return

        embed = discord.Embed(title=f"{target}'s Banner", color=discord.Color.blurple())
        embed.set_image(url=user.banner.with_size(1024).url)
        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── Help ────────────────────────────

    @app_commands.command(name="help", description="Show all bot commands organized by category")
    async def help(self, interaction: discord.Interaction) -> None:
        embed = discord.Embed(
            title="Bot Help",
            description="Select a category below to see its commands.",
            color=discord.Color.blurple(),
        )

        categories = {
            "\U0001f6e1\ufe0f Moderation": "kick, ban, unban, mute, unmute, warn, warnings, clearwarn, purge, slowmode, lock, unlock",
            "\U0001f527 Utility": "ping, serverinfo, userinfo, avatar, banner, help, poll, embed, timer",
            "\U0001f3b2 Fun": "8ball, coinflip, dice, rps, choose, say, reverse, meme, joke",
            "\u2699\ufe0f Admin": "setprefix, setwelcome, setautorole, setlogchannel, settings",
            "\U0001f4b0 Economy": "balance, daily, work, pay, deposit, withdraw, shop, buy, inventory, additem, removeitem, leaderboard-eco",
            "\U0001f4c8 Leveling": "rank, leaderboard-xp, setlevel, setxp, resetlevel",
            "\U0001f3b5 Music": "play, skip, stop, pause, resume, queue, nowplaying, volume, shuffle, loop",
        }

        for name, cmds in categories.items():
            embed.add_field(name=name, value=f"```{cmds}```", inline=False)

        view = HelpView(self.bot)
        await interaction.response.send_message(embed=embed, view=view)

    # ──────────────────────────── Poll ────────────────────────────

    @app_commands.command(name="poll", description="Create a simple poll")
    @app_commands.describe(
        question="The poll question",
        option1="First option",
        option2="Second option",
        option3="Third option (optional)",
        option4="Fourth option (optional)",
    )
    async def poll(
        self,
        interaction: discord.Interaction,
        question: str,
        option1: str,
        option2: str,
        option3: str | None = None,
        option4: str | None = None,
    ) -> None:
        number_emojis = ["\u0031\ufe0f\u20e3", "\u0032\ufe0f\u20e3", "\u0033\ufe0f\u20e3", "\u0034\ufe0f\u20e3"]
        options = [opt for opt in [option1, option2, option3, option4] if opt is not None]
        description = "\n".join(f"{number_emojis[i]} {opt}" for i, opt in enumerate(options))

        embed = discord.Embed(
            title=f"\U0001f4ca {question}",
            description=description,
            color=discord.Color.gold(),
        )
        embed.set_footer(text=f"Poll by {interaction.user}")

        await interaction.response.send_message(embed=embed)
        message = await interaction.original_response()
        for i in range(len(options)):
            await message.add_reaction(number_emojis[i])

    # ──────────────────────────── Embed ──────────────────────────

    @app_commands.command(name="embed", description="Create a custom embed message")
    @app_commands.describe(title="Embed title", description="Embed description", color="Hex color (e.g. #ff0000)")
    async def embed_cmd(
        self,
        interaction: discord.Interaction,
        title: str,
        description: str,
        color: str = "#5865F2",
    ) -> None:
        try:
            colour = discord.Color.from_str(color)
        except ValueError:
            colour = discord.Color.blurple()

        embed = discord.Embed(title=title, description=description, color=colour)
        embed.set_footer(text=f"Created by {interaction.user}")
        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── Timer ───────────────────────────

    @app_commands.command(name="timer", description="Set a timer that pings you when done")
    @app_commands.describe(minutes="Number of minutes", message="Reminder message")
    async def timer(
        self,
        interaction: discord.Interaction,
        minutes: app_commands.Range[int, 1, 1440],
        message: str = "Timer is up!",
    ) -> None:
        import asyncio

        await interaction.response.send_message(
            embed=info_embed("Timer Set", f"I'll remind you in **{minutes} minute(s)**."),
        )

        await asyncio.sleep(minutes * 60)
        await interaction.followup.send(
            content=interaction.user.mention,
            embed=info_embed("Timer Done", message),
        )


async def setup(bot: commands.Bot) -> None:
    await bot.add_cog(Utility(bot))
