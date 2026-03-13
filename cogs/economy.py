"""Economy commands: balance, daily, work, pay, deposit, withdraw, shop, buy, inventory, additem, removeitem, leaderboard."""

import random
from datetime import datetime, timedelta, timezone

import discord
from discord import app_commands
from discord.ext import commands

from utils.checks import is_admin
from utils.database import get_db
from utils.embed_helpers import error_embed, info_embed, success_embed

WORK_JOBS = [
    ("Software Developer", 150, 500),
    ("Chef", 100, 350),
    ("Doctor", 200, 600),
    ("Teacher", 80, 300),
    ("Artist", 50, 400),
    ("Mechanic", 120, 380),
    ("Pilot", 250, 700),
    ("Farmer", 60, 250),
    ("Streamer", 30, 800),
    ("Astronaut", 500, 1000),
]


class Economy(commands.Cog):
    """Economy system with currency, daily rewards, work, shop, and more."""

    def __init__(self, bot: commands.Bot) -> None:
        self.bot = bot

    async def _get_or_create_account(self, user_id: int, guild_id: int) -> tuple[int, int]:
        """Get or create an economy account. Returns (balance, bank)."""
        db = await get_db()
        try:
            await db.execute(
                "INSERT OR IGNORE INTO economy (user_id, guild_id) VALUES (?, ?)",
                (user_id, guild_id),
            )
            await db.commit()
            cursor = await db.execute(
                "SELECT balance, bank FROM economy WHERE user_id = ? AND guild_id = ?",
                (user_id, guild_id),
            )
            row = await cursor.fetchone()
            return (row[0], row[1]) if row else (0, 0)
        finally:
            await db.close()

    # ──────────────────────────── Balance ─────────────────────────

    @app_commands.command(name="balance", description="Check your or another user's balance")
    @app_commands.describe(member="The user to check (defaults to yourself)")
    async def balance(
        self,
        interaction: discord.Interaction,
        member: discord.Member | None = None,
    ) -> None:
        assert interaction.guild is not None
        target = member or interaction.user
        balance, bank = await self._get_or_create_account(target.id, interaction.guild.id)

        embed = discord.Embed(
            title=f"\U0001f4b0 {target.display_name}'s Balance",
            color=discord.Color.gold(),
        )
        embed.set_thumbnail(url=target.display_avatar.url)
        embed.add_field(name="\U0001f4b5 Wallet", value=f"${balance:,}", inline=True)
        embed.add_field(name="\U0001f3e6 Bank", value=f"${bank:,}", inline=True)
        embed.add_field(name="\U0001f4b8 Net Worth", value=f"${balance + bank:,}", inline=True)
        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── Daily ───────────────────────────

    @app_commands.command(name="daily", description="Claim your daily reward")
    async def daily(self, interaction: discord.Interaction) -> None:
        assert interaction.guild is not None
        await self._get_or_create_account(interaction.user.id, interaction.guild.id)

        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT last_daily FROM economy WHERE user_id = ? AND guild_id = ?",
                (interaction.user.id, interaction.guild.id),
            )
            row = await cursor.fetchone()
            now = datetime.now(timezone.utc)

            if row and row[0]:
                last_daily = datetime.fromisoformat(row[0]).replace(tzinfo=timezone.utc)
                if now - last_daily < timedelta(hours=24):
                    remaining = last_daily + timedelta(hours=24) - now
                    hours, remainder = divmod(int(remaining.total_seconds()), 3600)
                    minutes = remainder // 60
                    await interaction.response.send_message(
                        embed=error_embed(
                            "Daily Already Claimed",
                            f"You can claim again in **{hours}h {minutes}m**.",
                        ),
                        ephemeral=True,
                    )
                    return

            amount = random.randint(100, 500)
            await db.execute(
                "UPDATE economy SET balance = balance + ?, last_daily = ? WHERE user_id = ? AND guild_id = ?",
                (amount, now.isoformat(), interaction.user.id, interaction.guild.id),
            )
            await db.commit()
        finally:
            await db.close()

        await interaction.response.send_message(
            embed=success_embed("Daily Reward", f"You received **${amount:,}**! Come back tomorrow.")
        )

    # ──────────────────────────── Work ────────────────────────────

    @app_commands.command(name="work", description="Work to earn money")
    async def work(self, interaction: discord.Interaction) -> None:
        assert interaction.guild is not None
        await self._get_or_create_account(interaction.user.id, interaction.guild.id)

        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT last_work FROM economy WHERE user_id = ? AND guild_id = ?",
                (interaction.user.id, interaction.guild.id),
            )
            row = await cursor.fetchone()
            now = datetime.now(timezone.utc)

            if row and row[0]:
                last_work = datetime.fromisoformat(row[0]).replace(tzinfo=timezone.utc)
                if now - last_work < timedelta(hours=1):
                    remaining = last_work + timedelta(hours=1) - now
                    minutes = int(remaining.total_seconds()) // 60
                    await interaction.response.send_message(
                        embed=error_embed(
                            "Too Tired",
                            f"You need to rest! Come back in **{minutes} minutes**.",
                        ),
                        ephemeral=True,
                    )
                    return

            job, min_pay, max_pay = random.choice(WORK_JOBS)
            amount = random.randint(min_pay, max_pay)

            await db.execute(
                "UPDATE economy SET balance = balance + ?, last_work = ? WHERE user_id = ? AND guild_id = ?",
                (amount, now.isoformat(), interaction.user.id, interaction.guild.id),
            )
            await db.commit()
        finally:
            await db.close()

        await interaction.response.send_message(
            embed=success_embed("Work Complete", f"You worked as a **{job}** and earned **${amount:,}**!")
        )

    # ──────────────────────────── Pay ─────────────────────────────

    @app_commands.command(name="pay", description="Send money to another user")
    @app_commands.describe(member="Who to pay", amount="Amount to send")
    async def pay(
        self,
        interaction: discord.Interaction,
        member: discord.Member,
        amount: app_commands.Range[int, 1],
    ) -> None:
        assert interaction.guild is not None

        if member.id == interaction.user.id:
            await interaction.response.send_message(
                embed=error_embed("Error", "You can't pay yourself!"), ephemeral=True
            )
            return

        balance, _ = await self._get_or_create_account(interaction.user.id, interaction.guild.id)
        await self._get_or_create_account(member.id, interaction.guild.id)

        if balance < amount:
            await interaction.response.send_message(
                embed=error_embed("Insufficient Funds", f"You only have **${balance:,}** in your wallet."),
                ephemeral=True,
            )
            return

        db = await get_db()
        try:
            await db.execute(
                "UPDATE economy SET balance = balance - ? WHERE user_id = ? AND guild_id = ?",
                (amount, interaction.user.id, interaction.guild.id),
            )
            await db.execute(
                "UPDATE economy SET balance = balance + ? WHERE user_id = ? AND guild_id = ?",
                (amount, member.id, interaction.guild.id),
            )
            await db.commit()
        finally:
            await db.close()

        await interaction.response.send_message(
            embed=success_embed("Payment Sent", f"**{interaction.user}** paid **${amount:,}** to **{member}**.")
        )

    # ──────────────────────────── Deposit ─────────────────────────

    @app_commands.command(name="deposit", description="Deposit money into your bank")
    @app_commands.describe(amount="Amount to deposit (use 0 for all)")
    async def deposit(
        self,
        interaction: discord.Interaction,
        amount: int,
    ) -> None:
        assert interaction.guild is not None
        balance, _ = await self._get_or_create_account(interaction.user.id, interaction.guild.id)

        if amount == 0:
            amount = balance

        if amount < 1:
            await interaction.response.send_message(
                embed=error_embed("Error", "Amount must be at least $1."), ephemeral=True
            )
            return

        if balance < amount:
            await interaction.response.send_message(
                embed=error_embed("Insufficient Funds", f"You only have **${balance:,}** in your wallet."),
                ephemeral=True,
            )
            return

        db = await get_db()
        try:
            await db.execute(
                "UPDATE economy SET balance = balance - ?, bank = bank + ? WHERE user_id = ? AND guild_id = ?",
                (amount, amount, interaction.user.id, interaction.guild.id),
            )
            await db.commit()
        finally:
            await db.close()

        await interaction.response.send_message(
            embed=success_embed("Deposited", f"Deposited **${amount:,}** into your bank.")
        )

    # ──────────────────────────── Withdraw ────────────────────────

    @app_commands.command(name="withdraw", description="Withdraw money from your bank")
    @app_commands.describe(amount="Amount to withdraw (use 0 for all)")
    async def withdraw(
        self,
        interaction: discord.Interaction,
        amount: int,
    ) -> None:
        assert interaction.guild is not None
        _, bank = await self._get_or_create_account(interaction.user.id, interaction.guild.id)

        if amount == 0:
            amount = bank

        if amount < 1:
            await interaction.response.send_message(
                embed=error_embed("Error", "Amount must be at least $1."), ephemeral=True
            )
            return

        if bank < amount:
            await interaction.response.send_message(
                embed=error_embed("Insufficient Funds", f"You only have **${bank:,}** in your bank."),
                ephemeral=True,
            )
            return

        db = await get_db()
        try:
            await db.execute(
                "UPDATE economy SET balance = balance + ?, bank = bank - ? WHERE user_id = ? AND guild_id = ?",
                (amount, amount, interaction.user.id, interaction.guild.id),
            )
            await db.commit()
        finally:
            await db.close()

        await interaction.response.send_message(
            embed=success_embed("Withdrawn", f"Withdrew **${amount:,}** from your bank.")
        )

    # ──────────────────────────── Shop ────────────────────────────

    @app_commands.command(name="shop", description="View the server shop")
    async def shop(self, interaction: discord.Interaction) -> None:
        assert interaction.guild is not None

        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT id, name, description, price, role_id FROM shop_items WHERE guild_id = ? ORDER BY price",
                (interaction.guild.id,),
            )
            items = await cursor.fetchall()
        finally:
            await db.close()

        if not items:
            await interaction.response.send_message(
                embed=info_embed("Shop", "The shop is empty! An admin can add items with `/additem`."),
                ephemeral=True,
            )
            return

        embed = discord.Embed(title="\U0001f6d2 Server Shop", color=discord.Color.gold())
        for item in items:
            role_text = f" | Grants <@&{item[4]}>" if item[4] else ""
            embed.add_field(
                name=f"#{item[0]} — {item[1]} (${item[3]:,})",
                value=f"{item[2] or 'No description'}{role_text}",
                inline=False,
            )
        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── Buy ─────────────────────────────

    @app_commands.command(name="buy", description="Buy an item from the shop")
    @app_commands.describe(item_id="The item ID to buy")
    async def buy(
        self,
        interaction: discord.Interaction,
        item_id: int,
    ) -> None:
        assert interaction.guild is not None
        balance, _ = await self._get_or_create_account(interaction.user.id, interaction.guild.id)

        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT name, price, role_id FROM shop_items WHERE id = ? AND guild_id = ?",
                (item_id, interaction.guild.id),
            )
            item = await cursor.fetchone()

            if not item:
                await interaction.response.send_message(
                    embed=error_embed("Error", "Item not found."), ephemeral=True
                )
                return

            name, price, role_id = item[0], item[1], item[2]

            if balance < price:
                await interaction.response.send_message(
                    embed=error_embed("Insufficient Funds", f"You need **${price:,}** but only have **${balance:,}**."),
                    ephemeral=True,
                )
                return

            await db.execute(
                "UPDATE economy SET balance = balance - ? WHERE user_id = ? AND guild_id = ?",
                (price, interaction.user.id, interaction.guild.id),
            )
            await db.execute(
                "INSERT INTO inventory (user_id, guild_id, item_id) VALUES (?, ?, ?)",
                (interaction.user.id, interaction.guild.id, item_id),
            )
            await db.commit()
        finally:
            await db.close()

        # Grant role if applicable
        if role_id:
            role = interaction.guild.get_role(role_id)
            if role and isinstance(interaction.user, discord.Member):
                try:
                    await interaction.user.add_roles(role, reason=f"Purchased {name}")
                except discord.Forbidden:
                    pass

        await interaction.response.send_message(
            embed=success_embed("Purchase Complete", f"You bought **{name}** for **${price:,}**!")
        )

    # ──────────────────────────── Inventory ───────────────────────

    @app_commands.command(name="inventory", description="View your inventory")
    async def inventory(self, interaction: discord.Interaction) -> None:
        assert interaction.guild is not None

        db = await get_db()
        try:
            cursor = await db.execute(
                """
                SELECT s.name, COUNT(i.id) as qty
                FROM inventory i
                JOIN shop_items s ON i.item_id = s.id
                WHERE i.user_id = ? AND i.guild_id = ?
                GROUP BY s.name
                """,
                (interaction.user.id, interaction.guild.id),
            )
            items = await cursor.fetchall()
        finally:
            await db.close()

        if not items:
            await interaction.response.send_message(
                embed=info_embed("Inventory", "Your inventory is empty!"),
                ephemeral=True,
            )
            return

        description = "\n".join(f"**{item[0]}** x{item[1]}" for item in items)
        embed = discord.Embed(
            title=f"\U0001f392 {interaction.user.display_name}'s Inventory",
            description=description,
            color=discord.Color.gold(),
        )
        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── Add Item (Admin) ────────────────

    @app_commands.command(name="additem", description="Add an item to the server shop (Admin)")
    @app_commands.describe(
        name="Item name",
        price="Item price",
        description="Item description",
        role="Role to grant on purchase (optional)",
    )
    @app_commands.default_permissions(administrator=True)
    @is_admin()
    async def additem(
        self,
        interaction: discord.Interaction,
        name: str,
        price: app_commands.Range[int, 1],
        description: str = "",
        role: discord.Role | None = None,
    ) -> None:
        assert interaction.guild is not None

        db = await get_db()
        try:
            await db.execute(
                "INSERT INTO shop_items (guild_id, name, description, price, role_id) VALUES (?, ?, ?, ?, ?)",
                (interaction.guild.id, name, description, price, role.id if role else None),
            )
            await db.commit()
        finally:
            await db.close()

        await interaction.response.send_message(
            embed=success_embed("Item Added", f"**{name}** added to the shop for **${price:,}**.")
        )

    # ──────────────────────────── Remove Item (Admin) ─────────────

    @app_commands.command(name="removeitem", description="Remove an item from the shop (Admin)")
    @app_commands.describe(item_id="The item ID to remove")
    @app_commands.default_permissions(administrator=True)
    @is_admin()
    async def removeitem(
        self,
        interaction: discord.Interaction,
        item_id: int,
    ) -> None:
        assert interaction.guild is not None

        db = await get_db()
        try:
            cursor = await db.execute(
                "DELETE FROM shop_items WHERE id = ? AND guild_id = ?",
                (item_id, interaction.guild.id),
            )
            await db.commit()
            deleted = cursor.rowcount
        finally:
            await db.close()

        if deleted:
            await interaction.response.send_message(
                embed=success_embed("Item Removed", f"Item **#{item_id}** removed from the shop.")
            )
        else:
            await interaction.response.send_message(
                embed=error_embed("Error", "Item not found."), ephemeral=True
            )

    # ──────────────────────────── Economy Leaderboard ─────────────

    @app_commands.command(name="leaderboard-eco", description="View the richest members")
    async def leaderboard_eco(self, interaction: discord.Interaction) -> None:
        assert interaction.guild is not None

        db = await get_db()
        try:
            cursor = await db.execute(
                "SELECT user_id, balance + bank as net FROM economy WHERE guild_id = ? ORDER BY net DESC LIMIT 10",
                (interaction.guild.id,),
            )
            rows = await cursor.fetchall()
        finally:
            await db.close()

        if not rows:
            await interaction.response.send_message(
                embed=info_embed("Leaderboard", "No economy data yet!"),
                ephemeral=True,
            )
            return

        medals = ["\U0001f947", "\U0001f948", "\U0001f949"]
        description = ""
        for i, row in enumerate(rows):
            prefix = medals[i] if i < 3 else f"**#{i + 1}**"
            description += f"{prefix} <@{row[0]}> — **${row[1]:,}**\n"

        embed = discord.Embed(
            title="\U0001f4b0 Economy Leaderboard",
            description=description,
            color=discord.Color.gold(),
        )
        await interaction.response.send_message(embed=embed)


async def setup(bot: commands.Bot) -> None:
    await bot.add_cog(Economy(bot))
