# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Meta Tic-Tac-Toe (MTTT) Rails application - an advanced version of tic-tac-toe where players compete across 9 boards simultaneously. The game requires players to play in specific boards based on where the previous player placed their mark.

## Common Development Commands

```bash
# Initial setup
bin/setup

# Start development server (Rails + Tailwind CSS watcher)
bin/dev

# Run all tests
bin/rails test

# Run system tests only
bin/rails test:system

# Run a specific test file
bin/rails test test/models/game_test.rb

# Run security analysis
bundle exec brakeman

# Run linter
bundle exec rubocop

# Database commands
bin/rails db:migrate
bin/rails db:rollback
bin/rails db:seed

# Rails console
bin/rails console
```

## Architecture Overview

### Game Domain Model

The game consists of four main models with clear relationships:
- **Game**: Represents an entire MTTT game session, tracks current player and winner
- **Board**: 9 boards per game (labeled A-I), each can be won independently
- **Panel**: 9 panels per board (positions 1-9), where players place their marks
- **Move**: Records each player's move with board, panel, and player info

### Frontend Architecture

- **Stimulus Controller** (`mttt_controller.js`): Handles all client-side game logic
- **AJAX-based moves**: POST to `/games/:id/move` with board and panel parameters
- **Turbo Frames**: Used for updating game state without full page reloads
- **Tailwind CSS**: All styling uses utility classes

### Key Implementation Details

1. **Move Validation**: The next valid board is determined by the panel position of the last move (e.g., playing in panel 5 means the next player must play in board E)
2. **Win Detection**: Implemented at both panel level (3 in a row) and board level (winning the most boards)
3. **Game Modes**: Three modes planned - local (implemented), PC (partial), network (infrastructure ready via ActionCable)
4. **Japanese Support**: Comments and some UI elements are in Japanese, indicating the target audience