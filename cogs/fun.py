"""Fun commands: 8ball, coinflip, dice, rps, choose, say, reverse, meme, joke."""

import random

import aiohttp
import discord
from discord import app_commands
from discord.ext import commands

from utils.embed_helpers import info_embed

EIGHT_BALL_RESPONSES = [
    "It is certain.",
    "It is decidedly so.",
    "Without a doubt.",
    "Yes, definitely.",
    "You may rely on it.",
    "As I see it, yes.",
    "Most likely.",
    "Outlook good.",
    "Yes.",
    "Signs point to yes.",
    "Reply hazy, try again.",
    "Ask again later.",
    "Better not tell you now.",
    "Cannot predict now.",
    "Concentrate and ask again.",
    "Don't count on it.",
    "My reply is no.",
    "My sources say no.",
    "Outlook not so good.",
    "Very doubtful.",
]


class RPSView(discord.ui.View):
    """Rock Paper Scissors interactive view."""

    def __init__(self, challenger: discord.User | discord.Member) -> None:
        super().__init__(timeout=60)
        self.challenger = challenger
        self.bot_choice = random.choice(["rock", "paper", "scissors"])

    def _determine_winner(self, user_choice: str) -> str:
        if user_choice == self.bot_choice:
            return "draw"
        wins = {"rock": "scissors", "paper": "rock", "scissors": "paper"}
        return "win" if wins[user_choice] == self.bot_choice else "lose"

    async def _handle_choice(self, interaction: discord.Interaction, choice: str) -> None:
        if interaction.user.id != self.challenger.id:
            await interaction.response.send_message("This isn't your game!", ephemeral=True)
            return

        result = self._determine_winner(choice)
        emoji_map = {"rock": "\U0001faa8", "paper": "\U0001f4c4", "scissors": "\u2702\ufe0f"}

        if result == "win":
            desc = f"You chose {emoji_map[choice]} and I chose {emoji_map[self.bot_choice]}. **You win!** \U0001f389"
        elif result == "lose":
            desc = f"You chose {emoji_map[choice]} and I chose {emoji_map[self.bot_choice]}. **You lose!** \U0001f614"
        else:
            desc = f"We both chose {emoji_map[choice]}. **It's a draw!** \U0001f91d"

        await interaction.response.edit_message(embed=info_embed("Rock Paper Scissors", desc), view=None)
        self.stop()

    @discord.ui.button(label="Rock", emoji="\U0001faa8", style=discord.ButtonStyle.primary)
    async def rock(self, interaction: discord.Interaction, button: discord.ui.Button["RPSView"]) -> None:
        await self._handle_choice(interaction, "rock")

    @discord.ui.button(label="Paper", emoji="\U0001f4dc", style=discord.ButtonStyle.primary)
    async def paper(self, interaction: discord.Interaction, button: discord.ui.Button["RPSView"]) -> None:
        await self._handle_choice(interaction, "paper")

    @discord.ui.button(label="Scissors", emoji="\u2702\ufe0f", style=discord.ButtonStyle.primary)
    async def scissors(self, interaction: discord.Interaction, button: discord.ui.Button["RPSView"]) -> None:
        await self._handle_choice(interaction, "scissors")


class Fun(commands.Cog):
    """Fun commands for entertainment."""

    def __init__(self, bot: commands.Bot) -> None:
        self.bot = bot

    # ──────────────────────────── 8ball ───────────────────────────

    @app_commands.command(name="8ball", description="Ask the magic 8-ball a question")
    @app_commands.describe(question="Your question")
    async def eight_ball(self, interaction: discord.Interaction, question: str) -> None:
        response = random.choice(EIGHT_BALL_RESPONSES)
        embed = discord.Embed(
            title="\U0001f3b1 Magic 8-Ball",
            color=discord.Color.purple(),
        )
        embed.add_field(name="Question", value=question, inline=False)
        embed.add_field(name="Answer", value=response, inline=False)
        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── Coinflip ────────────────────────

    @app_commands.command(name="coinflip", description="Flip a coin")
    async def coinflip(self, interaction: discord.Interaction) -> None:
        result = random.choice(["Heads", "Tails"])
        emoji = "\U0001fa99" if result == "Heads" else "\U0001fa99"
        await interaction.response.send_message(
            embed=info_embed("Coin Flip", f"{emoji} The coin landed on **{result}**!")
        )

    # ──────────────────────────── Dice ────────────────────────────

    @app_commands.command(name="dice", description="Roll dice")
    @app_commands.describe(sides="Number of sides (default 6)", count="Number of dice to roll (default 1)")
    async def dice(
        self,
        interaction: discord.Interaction,
        sides: app_commands.Range[int, 2, 100] = 6,
        count: app_commands.Range[int, 1, 25] = 1,
    ) -> None:
        rolls = [random.randint(1, sides) for _ in range(count)]
        results = ", ".join(str(r) for r in rolls)
        total = sum(rolls)
        await interaction.response.send_message(
            embed=info_embed(
                "\U0001f3b2 Dice Roll",
                f"Rolling **{count}d{sides}**\nResults: {results}\nTotal: **{total}**",
            )
        )

    # ──────────────────────────── RPS ─────────────────────────────

    @app_commands.command(name="rps", description="Play Rock Paper Scissors")
    async def rps(self, interaction: discord.Interaction) -> None:
        view = RPSView(interaction.user)
        await interaction.response.send_message(
            embed=info_embed("Rock Paper Scissors", "Choose your weapon!"),
            view=view,
        )

    # ──────────────────────────── Choose ──────────────────────────

    @app_commands.command(name="choose", description="Let the bot choose between options")
    @app_commands.describe(choices="Comma-separated options to choose from")
    async def choose(self, interaction: discord.Interaction, choices: str) -> None:
        options = [c.strip() for c in choices.split(",") if c.strip()]
        if len(options) < 2:
            await interaction.response.send_message("Please provide at least 2 comma-separated options.", ephemeral=True)
            return
        chosen = random.choice(options)
        await interaction.response.send_message(
            embed=info_embed("\U0001f914 I Choose...", f"**{chosen}**")
        )

    # ──────────────────────────── Say ─────────────────────────────

    @app_commands.command(name="say", description="Make the bot say something")
    @app_commands.describe(message="What the bot should say")
    async def say(self, interaction: discord.Interaction, message: str) -> None:
        await interaction.response.send_message(message)

    # ──────────────────────────── Reverse ─────────────────────────

    @app_commands.command(name="reverse", description="Reverse a text string")
    @app_commands.describe(text="The text to reverse")
    async def reverse(self, interaction: discord.Interaction, text: str) -> None:
        await interaction.response.send_message(
            embed=info_embed("\U0001f500 Reversed", text[::-1])
        )

    # ──────────────────────────── Meme ────────────────────────────

    @app_commands.command(name="meme", description="Get a random meme from Reddit")
    async def meme(self, interaction: discord.Interaction) -> None:
        await interaction.response.defer()
        async with aiohttp.ClientSession() as session:
            async with session.get("https://meme-api.com/gimme") as resp:
                if resp.status != 200:
                    await interaction.followup.send("Couldn't fetch a meme right now. Try again later!")
                    return
                data = await resp.json()

        embed = discord.Embed(
            title=data.get("title", "Meme"),
            color=discord.Color.random(),
            url=data.get("postLink", ""),
        )
        embed.set_image(url=data.get("url", ""))
        embed.set_footer(text=f"\U0001f44d {data.get('ups', 0)} | r/{data.get('subreddit', 'memes')}")
        await interaction.followup.send(embed=embed)

    # ──────────────────────────── Joke ────────────────────────────

    @app_commands.command(name="joke", description="Get a random joke")
    async def joke(self, interaction: discord.Interaction) -> None:
        await interaction.response.defer()
        async with aiohttp.ClientSession() as session:
            async with session.get(
                "https://v2.jokeapi.dev/joke/Any?blacklistFlags=nsfw,religious,political,racist,sexist,explicit&type=twopart"
            ) as resp:
                if resp.status != 200:
                    await interaction.followup.send("Couldn't fetch a joke right now. Try again later!")
                    return
                data = await resp.json()

        if data.get("type") == "twopart":
            embed = discord.Embed(
                title="\U0001f602 Joke",
                description=f"{data['setup']}\n\n||{data['delivery']}||",
                color=discord.Color.random(),
            )
        else:
            embed = discord.Embed(
                title="\U0001f602 Joke",
                description=data.get("joke", "No joke found."),
                color=discord.Color.random(),
            )
        await interaction.followup.send(embed=embed)


async def setup(bot: commands.Bot) -> None:
    await bot.add_cog(Fun(bot))
