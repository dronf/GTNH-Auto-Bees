# Auto Bees Discord bot

Buttons and slash commands for the controller. A webhook is one-way and an OpenComputers computer cannot
receive Discord interactions, so this bot runs on a machine of yours and passes clicks through.

```
Discord  <-- gateway -->  relay/bot.py  <-- plain HTTP -->  OpenComputers controller
```

It keeps one **main card** in your channel with buttons: Status, Queue, Cells, Library, Find, Plan, Needs,
Breed, Cancel, Rescan library. Find, Plan, Needs, Breed and Cancel open a small form. `/bee <line>` accepts
anything the controller understands, for example `/bee breed 4137 keep 16`. The card is redrawn every 30 s
from the status the controller pushes and shows the icon of the species being bred.

## 1. Create the bot in Discord

1. Open the [developer portal](https://discord.com/developers/applications) and select your application
   (or **New Application**).
2. **Bot** tab: click **Add Bot** if there is none, then **Reset Token** and copy the token. Keep it secret.
3. **OAuth2** tab: copy the **Client ID**. Open this URL with your id filled in and pick your server:

   ```
   https://discord.com/oauth2/authorize?client_id=YOUR_CLIENT_ID&scope=bot%20applications.commands&permissions=84992
   ```

   The permission number is View Channel + Send Messages + Embed Links + Read Message History.
4. In Discord, right-click the channel the bot should live in and **Copy Channel ID** (enable Developer Mode
   under Settings > Advanced if the entry is missing).

## 2. Run it on your host

On the host, install Python 3.10 or newer with virtual environment support. Copy `relay/.env.example`
to `relay/.env` and set `DISCORD_TOKEN` and `DISCORD_CHANNEL`. Run the launcher from the `relay`
directory:

- Windows PowerShell: `.\run.bat`
- Linux: `sh run.sh`

The script creates a virtual environment, installs the packages in `requirements.txt`, and starts the
bot. The launcher restarts the bot after it exits. On first start it posts the main card and registers `/bee` on your server. Open the host's firewall
for the relay port (8080 by default) from the Minecraft server's address.

To check the HTTP side without a Discord connection, run `.venv\Scripts\python test_relay.py`
on Windows or `.venv/bin/python test_relay.py` on Linux after installing the dependencies.

## 3. Point the controller at it

Connect an Internet Card to the controller and run `settings host http://<host-ip>:8080`, using the
address the Minecraft server can reach. If you changed `RELAY_PORT`, use that port in the URL. Keep
`host.relay = true` in `config.lua` and use a positive `host.pushInterval` for status updates.

The controller polls `/commands`, sends responses to `/result`, and pushes status to `/status`. Leave
the controller's bot token empty when the relay handles commands. You can still configure a webhook
on the controller for event cards.

Optional: set `RELAY_SECRET` in `.env` and the same value as `host.secret` in `config.lua` to reject requests
from anyone else.

## Protocol

| Call | Direction | Body |
|---|---|---|
| `GET /commands` | controller polls | `{"commands":[{"id":"...","line":"find naqua","user":"name"}]}` |
| `POST /result` | controller answers | Discord message JSON plus `"id"` |
| `POST /status` | controller pushes | status snapshot |
| `GET /` | health | counters |
