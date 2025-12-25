# Development Setup Scripts

Scripts for setting up development environment on Windows/macOS/Linux.

## Files

- `setup-dev.sh` - Setup script for macOS/Linux
- `setup-dev.bat` - Setup script for Windows
- `deploy.sh` - Production setup with systemd user mode (Linux only)

## Development Setup (Windows/macOS/Linux)

### macOS/Linux

```bash
chmod +x scripts/setup-dev.sh
./scripts/setup-dev.sh
```

### Windows

```cmd
scripts\setup-dev.bat
```

### What it does

1. ✅ Checks Docker and Docker Compose installation
2. ✅ Creates `.env` file from `.env.example`
3. ✅ Creates `recordings/` directory
4. ✅ Builds Docker images
5. ✅ Starts feed service

### After Setup

1. **Configure programs** in `.env`:
   ```bash
   PROGRAM1=07:40-08:00|program1|Program Name #1|https://example.com/stream1.m3u8
   PROGRAM2=08:00-08:20|program2|Program Name #2|https://example.com/stream2.m3u8
   ```

2. **Access feed**:
   ```
   http://localhost:8013/radio/feed.rss
   ```

3. **Test recording** (1 minute):
   ```bash
   docker compose run --rm recorder 1
   ```

4. **View logs**:
   ```bash
   docker compose logs -f feed
   ```

5. **Stop services**:
   ```bash
   docker compose down
   ```

## Production Setup (Linux Server)

For production deployment with automatic scheduling using systemd **USER mode**:

```bash
./scripts/deploy.sh
```

### What it does:
1. ✅ Enables **linger** for the current user (`loginctl enable-linger $USER`)
2. ✅ Creates application structure in `/srv/radio`
3. ✅ Installs systemd user services in `~/.config/systemd/user/`
4. ✅ Enables and starts the systemd timer

This allows the recording service to:
- Run without `root` privileges
- Start automatically on boot (without manual login)
- Persist after logout

### Monitoring (User Mode):
- Check timer status:  `systemctl --user status radio-record.timer`
- View logs:           `journalctl --user -u radio-record.service -f`
- Trigger manually:    `systemctl --user start radio-record.service`

## Manual Recording

### With auto-duration (from environment variables)

```bash
# Matches current time with configured programs
docker compose run --rm recorder
```

### With manual duration

```bash
# Record for 30 minutes
docker compose run --rm recorder 30
```

## Troubleshooting

### Docker not found

Install Docker Desktop:
- Windows: https://docs.docker.com/desktop/install/windows-install/
- macOS: https://docs.docker.com/desktop/install/mac-install/
- Linux: https://docs.docker.com/engine/install/

### Permission denied (Linux/macOS)

```bash
chmod +x scripts/setup-dev.sh
```

### Port 8013 already in use

Edit `.env` and change `PORT`:
```bash
PORT=8013
```

Then restart:
```bash
docker compose down
docker compose up -d feed
```
