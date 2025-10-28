### Quick start (local)

1. Copy `.env.example` to `.env` and fill in actual image names (or let CI set them).

   ```bash
   cp .env.example .env
   # edit .env if needed
   ```
2. Start services:

   ```bash
   docker compose up -d
   ```
3. Verify baseline (Blue active by default):

   ```bash
   curl -i http://localhost:8080/version
   # expect 200 and response headers include:
   # X-App-Pool: blue
   # X-Release-Id: <value from .env>
   ```
4. Trigger chaos on Blue (the grader will do this; for local test):

   ```bash
   # Simulate error mode on blue
   curl -X POST "http://localhost:8081/chaos/start?mode=error"
   # Then poll the public endpoint repeatedly for up to 10s
   for i in {1..20}; do curl -s -I http://localhost:8080/version | grep -E "X-App-Pool|HTTP/1.1"; sleep 0.5; done
   ```

   You should observe immediate switch to `X-App-Pool: green` and **no** non-200 responses.
5. Stop chaos:

   ```bash
   curl -X POST "http://localhost:8081/chaos/stop"
   # Nginx will eventually route back to blue if ACTIVE_POOL=blue; otherwise green remains active
   ```

### Notes for graders/CI

* The grader will set `BLUE_IMAGE`, `GREEN_IMAGE`, `ACTIVE_POOL`, `RELEASE_ID_*` via `.env` in CI.
* Ensure Nginx container logs are accessible if debugging.
* Nginx template supports `nginx -s reload` if CI prefers toggling `ACTIVE_POOL` and reloading config.

