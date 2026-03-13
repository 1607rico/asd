"""Music commands: play, skip, stop, pause, resume, queue, nowplaying, volume, shuffle, loop.

Uses wavelink for Lavalink-based audio playback.
"""

import os

import discord
import wavelink
from discord import app_commands
from discord.ext import commands

from utils.embed_helpers import error_embed, info_embed, success_embed


class Music(commands.Cog):
    """Music player powered by Lavalink via wavelink."""

    def __init__(self, bot: commands.Bot) -> None:
        self.bot = bot

    async def cog_load(self) -> None:
        """Connect to Lavalink on cog load."""
        host = os.getenv("LAVALINK_HOST", "localhost")
        port = int(os.getenv("LAVALINK_PORT", "2333"))
        password = os.getenv("LAVALINK_PASSWORD", "youshallnotpass")

        node = wavelink.Node(uri=f"http://{host}:{port}", password=password)
        try:
            await wavelink.Pool.connect(nodes=[node], client=self.bot)
        except Exception:
            pass  # Lavalink may not be running; commands will handle gracefully

    @staticmethod
    def _get_player(interaction: discord.Interaction) -> wavelink.Player | None:
        """Get the wavelink player for the guild."""
        if interaction.guild is None:
            return None
        return interaction.guild.voice_client  # type: ignore[return-value]

    @staticmethod
    async def _ensure_voice(interaction: discord.Interaction) -> wavelink.Player | None:
        """Ensure the user is in a voice channel and return a connected player."""
        if not isinstance(interaction.user, discord.Member) or interaction.user.voice is None:
            await interaction.response.send_message(
                embed=error_embed("Error", "You must be in a voice channel."),
                ephemeral=True,
            )
            return None

        channel = interaction.user.voice.channel
        if channel is None:
            await interaction.response.send_message(
                embed=error_embed("Error", "Could not find your voice channel."),
                ephemeral=True,
            )
            return None

        assert interaction.guild is not None
        player: wavelink.Player | None = interaction.guild.voice_client  # type: ignore[assignment]

        if player is None:
            try:
                player = await channel.connect(cls=wavelink.Player)  # type: ignore[assignment]
                player.autoplay = wavelink.AutoPlayMode.partial
            except Exception:
                await interaction.response.send_message(
                    embed=error_embed("Error", "Could not connect to voice channel. Is Lavalink running?"),
                    ephemeral=True,
                )
                return None
        return player

    # ──────────────────────────── Play ────────────────────────────

    @app_commands.command(name="play", description="Play a song from YouTube or other sources")
    @app_commands.describe(query="Song name or URL")
    async def play(self, interaction: discord.Interaction, query: str) -> None:
        player = await self._ensure_voice(interaction)
        if player is None:
            return

        await interaction.response.defer()

        try:
            tracks = await wavelink.Playable.search(query)
        except Exception:
            await interaction.followup.send(
                embed=error_embed("Error", "Could not search for tracks. Is Lavalink running?")
            )
            return

        if not tracks:
            await interaction.followup.send(
                embed=error_embed("Not Found", "No tracks found for your query.")
            )
            return

        if isinstance(tracks, wavelink.Playlist):
            for track in tracks.tracks:
                track.extras = {"requester": interaction.user.id}
                player.queue.put(track)
            await interaction.followup.send(
                embed=success_embed("Playlist Added", f"Added **{len(tracks.tracks)}** tracks from **{tracks.name}**.")
            )
            if not player.playing:
                next_track = player.queue.get()
                await player.play(next_track)
        else:
            track = tracks[0]
            track.extras = {"requester": interaction.user.id}

            if player.playing:
                player.queue.put(track)
                await interaction.followup.send(
                    embed=info_embed("Queued", f"**{track.title}** by {track.author} added to queue.")
                )
            else:
                await player.play(track)
                await interaction.followup.send(
                    embed=success_embed("Now Playing", f"**{track.title}** by {track.author}")
                )

    # ──────────────────────────── Skip ────────────────────────────

    @app_commands.command(name="skip", description="Skip the current song")
    async def skip(self, interaction: discord.Interaction) -> None:
        player = self._get_player(interaction)
        if not player or not player.playing:
            await interaction.response.send_message(
                embed=error_embed("Error", "Nothing is playing."), ephemeral=True
            )
            return

        await player.skip()
        await interaction.response.send_message(
            embed=success_embed("Skipped", "Skipped the current track.")
        )

    # ──────────────────────────── Stop ────────────────────────────

    @app_commands.command(name="stop", description="Stop playback and disconnect")
    async def stop(self, interaction: discord.Interaction) -> None:
        player = self._get_player(interaction)
        if not player:
            await interaction.response.send_message(
                embed=error_embed("Error", "Not connected to a voice channel."),
                ephemeral=True,
            )
            return

        player.queue.clear()
        await player.disconnect()
        await interaction.response.send_message(
            embed=success_embed("Stopped", "Playback stopped and disconnected.")
        )

    # ──────────────────────────── Pause ───────────────────────────

    @app_commands.command(name="pause", description="Pause the current song")
    async def pause(self, interaction: discord.Interaction) -> None:
        player = self._get_player(interaction)
        if not player or not player.playing:
            await interaction.response.send_message(
                embed=error_embed("Error", "Nothing is playing."), ephemeral=True
            )
            return

        await player.pause(True)
        await interaction.response.send_message(
            embed=info_embed("Paused", "Playback paused. Use `/resume` to continue.")
        )

    # ──────────────────────────── Resume ──────────────────────────

    @app_commands.command(name="resume", description="Resume paused playback")
    async def resume(self, interaction: discord.Interaction) -> None:
        player = self._get_player(interaction)
        if not player:
            await interaction.response.send_message(
                embed=error_embed("Error", "Nothing to resume."), ephemeral=True
            )
            return

        await player.pause(False)
        await interaction.response.send_message(
            embed=success_embed("Resumed", "Playback resumed.")
        )

    # ──────────────────────────── Queue ───────────────────────────

    @app_commands.command(name="queue", description="View the current music queue")
    async def queue(self, interaction: discord.Interaction) -> None:
        player = self._get_player(interaction)
        if not player:
            await interaction.response.send_message(
                embed=error_embed("Error", "Not connected to a voice channel."),
                ephemeral=True,
            )
            return

        if player.queue.is_empty and not player.playing:
            await interaction.response.send_message(
                embed=info_embed("Queue", "The queue is empty."),
                ephemeral=True,
            )
            return

        embed = discord.Embed(title="\U0001f3b6 Music Queue", color=discord.Color.purple())

        if player.current:
            embed.add_field(
                name="Now Playing",
                value=f"**{player.current.title}** by {player.current.author}",
                inline=False,
            )

        if not player.queue.is_empty:
            queue_list = ""
            for i, track in enumerate(player.queue[:10]):
                queue_list += f"`{i + 1}.` **{track.title}** by {track.author}\n"
            if len(player.queue) > 10:
                queue_list += f"\n... and {len(player.queue) - 10} more"
            embed.add_field(name="Up Next", value=queue_list, inline=False)

        embed.set_footer(text=f"{len(player.queue)} tracks in queue")
        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── Now Playing ─────────────────────

    @app_commands.command(name="nowplaying", description="Show the currently playing track")
    async def nowplaying(self, interaction: discord.Interaction) -> None:
        player = self._get_player(interaction)
        if not player or not player.current:
            await interaction.response.send_message(
                embed=error_embed("Error", "Nothing is playing."), ephemeral=True
            )
            return

        track = player.current
        position = player.position // 1000
        length = track.length // 1000

        pos_min, pos_sec = divmod(position, 60)
        len_min, len_sec = divmod(length, 60)

        progress = int((position / length) * 20) if length > 0 else 0
        bar = "\u25ac" * progress + "\U0001f518" + "\u25ac" * (20 - progress)

        embed = discord.Embed(
            title="\U0001f3b5 Now Playing",
            description=f"**{track.title}**\nby {track.author}",
            color=discord.Color.purple(),
        )
        embed.add_field(
            name="Progress",
            value=f"`{pos_min}:{pos_sec:02d}` {bar} `{len_min}:{len_sec:02d}`",
            inline=False,
        )

        if hasattr(track, "artwork") and track.artwork:
            embed.set_thumbnail(url=track.artwork)

        await interaction.response.send_message(embed=embed)

    # ──────────────────────────── Volume ──────────────────────────

    @app_commands.command(name="volume", description="Set the player volume")
    @app_commands.describe(level="Volume level (0-150)")
    async def volume(
        self,
        interaction: discord.Interaction,
        level: app_commands.Range[int, 0, 150],
    ) -> None:
        player = self._get_player(interaction)
        if not player:
            await interaction.response.send_message(
                embed=error_embed("Error", "Not connected to a voice channel."),
                ephemeral=True,
            )
            return

        await player.set_volume(level)
        emoji = "\U0001f507" if level == 0 else "\U0001f509" if level < 50 else "\U0001f50a"
        await interaction.response.send_message(
            embed=success_embed("Volume", f"{emoji} Volume set to **{level}%**")
        )

    # ──────────────────────────── Shuffle ─────────────────────────

    @app_commands.command(name="shuffle", description="Shuffle the queue")
    async def shuffle(self, interaction: discord.Interaction) -> None:
        player = self._get_player(interaction)
        if not player or player.queue.is_empty:
            await interaction.response.send_message(
                embed=error_embed("Error", "The queue is empty."), ephemeral=True
            )
            return

        player.queue.shuffle()
        await interaction.response.send_message(
            embed=success_embed("Shuffled", f"Shuffled **{len(player.queue)}** tracks.")
        )

    # ──────────────────────────── Loop ────────────────────────────

    @app_commands.command(name="loop", description="Toggle loop mode for the current track")
    async def loop(self, interaction: discord.Interaction) -> None:
        player = self._get_player(interaction)
        if not player or not player.playing:
            await interaction.response.send_message(
                embed=error_embed("Error", "Nothing is playing."), ephemeral=True
            )
            return

        if player.queue.mode == wavelink.QueueMode.loop:
            player.queue.mode = wavelink.QueueMode.normal
            await interaction.response.send_message(
                embed=success_embed("Loop Disabled", "No longer looping the current track.")
            )
        else:
            player.queue.mode = wavelink.QueueMode.loop
            await interaction.response.send_message(
                embed=success_embed("Loop Enabled", "\U0001f501 Now looping the current track.")
            )

    # ──────────────────────────── Track End Event ─────────────────

    @commands.Cog.listener()
    async def on_wavelink_track_end(self, payload: wavelink.TrackEndEventPayload) -> None:
        player = payload.player
        if player is None:
            return

        if not player.queue.is_empty:
            next_track = player.queue.get()
            await player.play(next_track)
        elif player.autoplay == wavelink.AutoPlayMode.disabled:
            await player.disconnect()


async def setup(bot: commands.Bot) -> None:
    await bot.add_cog(Music(bot))
