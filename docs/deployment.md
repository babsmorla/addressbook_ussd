# USSD Template — Deployment Guide

---

## Production Checklist

- [ ] `RACK_ENV=production` set in environment
- [ ] `API_BASE_URL` set to the live backend URL
- [ ] Redis running and reachable (`redis-cli ping`)
- [ ] `Gemfile.lock` committed — pins exact gem versions to prevent drift between environments
- [ ] `log/` directory exists and is writable by the app user
- [ ] Process manager configured (see below)

---

## Puma (via `config.ru`)

The app runs on Puma by default. Start in production:

```bash
RACK_ENV=production bundle exec rackup -p 9000
```

For a persistent process, use **systemd** or **PM2**:

```bash
# PM2 example
pm2 start "bundle exec rackup -p 9000" --name ussd-app
pm2 save
```

---

## Hot Restart Without Downtime

Puma watches `tmp/restart.txt`. Touch it to trigger a graceful restart without killing the process:

```bash
touch tmp/restart.txt
```

Use this after deploying new code instead of killing and restarting the process.

---

## Log Rotation

`config/logger.rb` uses daily log rotation (`'daily'` mode). Old log files appear as `application.log.YYYYMMDD`. Logs are written to `log/application.log`. Make sure `log/` is writable and has sufficient disk space on production servers.

To tail live logs:

```bash
tail -f log/application.log
```

---

## Redis Persistence

By default Redis stores data in memory only — a restart loses all active sessions. For production, either:

- Accept this (sessions are 5-minute TTL anyway — users just re-dial), or
- Enable Redis RDB/AOF persistence in `redis.conf` if you need session survival across Redis restarts.

---

*See [architecture.md](architecture.md) for the full system design reference.*
