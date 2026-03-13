# Discord Bot

A comprehensive Discord bot built with **discord.py** featuring 50+ slash commands across 7 categories.

## Features

### Moderation
| Command | Description |
|---------|-------------|
| `/kick` | Kick a member from the server |
| `/ban` | Ban a member from the server |
| `/unban` | Unban a user by ID |
| `/mute` | Timeout (mute) a member |
| `/unmute` | Remove timeout from a member |
| `/warn` | Warn a member |
| `/warnings` | View a member's warnings |
| `/clearwarn` | Clear a specific warning |
| `/purge` | Delete multiple messages (1-100) |
| `/slowmode` | Set channel slowmode |
| `/lock` | Lock the current channel |
| `/unlock` | Unlock the current channel |

### Utility
| Command | Description |
|---------|-------------|
| `/ping` | Check bot latency |
| `/serverinfo` | Display server information |
| `/userinfo` | Display user information |
| `/avatar` | Show a user's avatar |
| `/banner` | Show a user's banner |
| `/help` | Interactive help with dropdown categories |
| `/poll` | Create a poll with up to 4 options |
| `/embed` | Create a custom embed message |
| `/timer` | Set a reminder timer |

### Fun
| Command | Description |
|---------|-------------|
| `/8ball` | Ask the magic 8-ball |
| `/coinflip` | Flip a coin |
| `/dice` | Roll dice (customizable sides and count) |
| `/rps` | Rock Paper Scissors with buttons |
| `/choose` | Random choice from options |
| `/say` | Make the bot say something |
| `/reverse` | Reverse text |
| `/meme` | Random meme from Reddit |
| `/joke` | Random joke |

### Admin
| Command | Description |
|---------|-------------|
| `/setprefix` | Set the bot prefix |
| `/setwelcome` | Set welcome channel and message |
| `/setautorole` | Set auto-assigned role for new members |
| `/setlogchannel` | Set moderation log channel |
| `/settings` | View current server settings |

### Economy
| Command | Description |
|---------|-------------|
| `/balance` | Check wallet and bank balance |
| `/daily` | Claim daily reward (24h cooldown) |
| `/work` | Work to earn money (1h cooldown) |
| `/pay` | Send money to another user |
| `/deposit` | Deposit money into bank |
| `/withdraw` | Withdraw money from bank |
| `/shop` | View the server shop |
| `/buy` | Buy an item from the shop |
| `/inventory` | View your inventory |
| `/additem` | Add shop item (Admin) |
| `/removeitem` | Remove shop item (Admin) |
| `/leaderboard-eco` | View richest members |

### Leveling
| Command | Description |
|---------|-------------|
| `/rank` | View level, XP, and progress bar |
| `/leaderboard-xp` | View XP leaderboard |
| `/setlevel` | Set a user's level (Admin) |
| `/setxp` | Set a user's XP (Admin) |
| `/resetlevel` | Reset a user's level (Admin) |

### Music (requires Lavalink)
| Command | Description |
|---------|-------------|
| `/play` | Play a song (YouTube, Spotify, etc.) |
| `/skip` | Skip the current song |
| `/stop` | Stop playback and disconnect |
| `/pause` | Pause playback |
| `/resume` | Resume playback |
| `/queue` | View the music queue |
| `/nowplaying` | Show current track with progress bar |
| `/volume` | Set volume (0-150) |
| `/shuffle` | Shuffle the queue |
| `/loop` | Toggle loop for the current track |

## Setup

### Prerequisites
- Python 3.10+
- A Discord bot token from the [Discord Developer Portal](https://discord.com/developers/applications)
- (Optional) A Lavalink server for music commands

### Installation

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd discord-bot
   ```

2. **Create a virtual environment**
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # Linux/macOS
   # or .venv\Scripts\activate  # Windows
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env and add your bot token
   ```

5. **Run the bot**
   ```bash
   python bot.py
   ```

### Bot Permissions

When inviting the bot, use this permission integer: `8` (Administrator) or select these individual permissions:
- Manage Channels
- Manage Roles
- Kick Members
- Ban Members
- Moderate Members
- Manage Messages
- Send Messages
- Embed Links
- Attach Files
- Read Message History
- Add Reactions
- Connect (Voice)
- Speak (Voice)

### Lavalink Setup (for Music)

1. Download Lavalink from [GitHub](https://github.com/lavalink-devs/Lavalink)
2. Run with `java -jar Lavalink.jar`
3. Configure the connection in `.env`

## Tech Stack

- **discord.py** 2.3 — Discord API wrapper
- **wavelink** 3.2 — Lavalink client for music
- **aiosqlite** — Async SQLite for persistent data
- **aiohttp** — HTTP client for APIs (memes, jokes)
- **Pillow** — Image processing

## Project Structure

```
discord-bot/
├── bot.py              # Main entry point
├── requirements.txt    # Python dependencies
├── .env.example        # Environment variable template
├── cogs/
│   ├── moderation.py   # Moderation commands
│   ├── utility.py      # Utility commands
│   ├── fun.py          # Fun commands
│   ├── admin.py        # Admin/config commands
│   ├── economy.py      # Economy system
│   ├── leveling.py     # XP leveling system
│   └── music.py        # Music player
├── utils/
│   ├── database.py     # SQLite database helpers
│   ├── embed_helpers.py# Embed builder utilities
│   └── checks.py       # Permission checks
└── data/               # Runtime data (auto-created)
```

## License

MIT
