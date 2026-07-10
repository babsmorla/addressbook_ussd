# Handoff Document

## Project
- App: Sinatra-based USSD template project
- Workspace: /home/babsmorla/ussd_template_anm
- Runtime: Ruby with Bundler
- Local web server: Rack/Puma on port 4567

## Current Status
- The app is set up to run locally.
- A browser-style UI route exists and is served through the Sinatra app.
- Resume-session handling has been adjusted so selecting “start fresh” clears the cached resume state.
- Basic regression coverage exists for the resume-session behavior.

## Key Files
- app.rb — main Sinatra app and request handling
- controller/dial/manager.rb — entrypoint for USSD request routing
- controller/page/resume_session.rb — resume/start-fresh screen logic
- models/cache.rb — Redis-backed session and resume cache handling
- views/ui.erb — browser UI template
- spec/app_spec.rb — regression tests

## How to Run
1. cd /home/babsmorla/ussd_template_anm
2. bundle install
3. sudo service redis-server start
4. bundle exec rackup -p 4567
5. Open http://127.0.0.1:4567/

## Important Notes
- Redis must be running for session/cache behavior.
- The app uses the existing USSD flow and the browser UI is a front-end wrapper around it.
- If the resume screen appears unexpectedly, verify the Redis resume pointer and cached session state.

## Known Focus Areas
- Continue validating the UI flow end-to-end.
- Add more regression tests for cancel/exit/restart behavior.
- Improve the browser UI styling and interaction if needed.

## Suggested Next Step
- Verify the full flow manually: dial short code → resume prompt → choose start fresh → dial again → confirm old resume prompt no longer appears.
