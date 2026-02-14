# Radio Recorder Scripts

Scripts for setting up and managing the Radio Recording system using Python virtual environment and systemd.

## Files

- `setup-env.sh` - Installs Python dependencies and sets up virtual environment
- `install-systemd.sh` - Installs systemd user services and timers
- `deploy.sh` - Main deployment script (calls setup-env.sh)
- `run.sh` - Manual recording execution script
- `check-recording.sh` - Lightweight check if recording is needed (used by systemd)
- `touch.sh` - Tool to fix file modification times for feed consistency

## Quick Start (Linux)

For production deployment with automatic scheduling:

```bash
# 1. Setup environment (dependencies, .venv, .env)
./scripts/setup-env.sh

# 2. Configure programs in .env
nano .env

# 3. Install systemd services
./scripts/install-systemd.sh
```

## Management Commands

### Manual Recording

You can run a recording manually or test the auto-matching logic:

```bash
# Auto-match current time with configured programs
./scripts/run.sh

# Record for 30 minutes explicitly
./scripts/run.sh 30
```

### Service Management (Systemd USER mode)

- **Check status**:
  ```bash
  systemctl --user status radio-record.timer
  systemctl --user status radio-feed.service
  ```

- **View logs**:
  ```bash
  journalctl --user -u radio-record.service -f
  journalctl --user -u radio-feed.service -f
  ```

- **Restart services**:
  ```bash
  systemctl --user restart radio-record.timer radio-feed.service
  ```

## Troubleshooting

### Virtual Environment Issues
If dependencies are missing, try re-running:
```bash
./scripts/setup-env.sh
```

### Systemd Permissions
Ensure lingering is enabled to keep services running after logout:
```bash
loginctl enable-linger $USER
```
*(Note: `install-systemd.sh` performs this automatically)*

### Port Conflicts
If port 8013 is already in use, edit `.env` and change `PORT`, then restart the feed service:
```bash
systemctl --user restart radio-feed.service
```
