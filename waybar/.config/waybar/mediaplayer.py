#!/usr/bin/env python3
import gi
gi.require_version("Playerctl", "2.0")
from gi.repository import Playerctl, GLib
from gi.repository.Playerctl import Player
import argparse
import logging
import sys
import signal
import json
import os
import html
from typing import List

logger = logging.getLogger(__name__)

def signal_handler(sig, frame):
    logger.info("Received signal to stop, exiting")
    sys.stdout.write("\n")
    sys.stdout.flush()
    sys.exit(0)


class PlayerManager:
    def __init__(self, selected_player=None, excluded_player=[], bar_count=12):
        self.manager = Playerctl.PlayerManager()
        self.loop = GLib.MainLoop()
        self.manager.connect(
            "name-appeared", lambda *args: self.on_player_appeared(*args))
        self.manager.connect(
            "player-vanished", lambda *args: self.on_player_vanished(*args))

        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)
        self.selected_player = selected_player
        self.excluded_player = excluded_player.split(',') if excluded_player else []
        self.bar_count = bar_count

        self.init_players()

    def init_players(self):
        for player in self.manager.props.player_names:
            if player.name in self.excluded_player:
                continue
            if self.selected_player is not None and self.selected_player != player.name:
                logger.debug(f"{player.name} is not the filtered player, skipping it")
                continue
            self.init_player(player)

    def run(self):
        logger.info("Starting main loop")
        self.loop.run()

    def init_player(self, player):
        logger.info(f"Initialize new player: {player.name}")
        player = Playerctl.Player.new_from_name(player)
        player.connect("playback-status",
                       self.on_playback_status_changed, None)
        player.connect("metadata", self.on_metadata_changed, None)
        self.manager.manage_player(player)
        self.on_metadata_changed(player, player.props.metadata)

    def get_players(self) -> List[Player]:
        return self.manager.props.players

    def write_output(self, text, player, tooltip=""):
        logger.debug(f"Writing output: {text}")

        output = {
            "text": text,
            "class": "custom-" + player.props.player_name,
            "alt": player.props.player_name,
            "tooltip": tooltip or text
        }

        sys.stdout.write(json.dumps(output) + "\n")
        sys.stdout.flush()

    def clear_output(self):
        sys.stdout.write("\n")
        sys.stdout.flush()

    def on_playback_status_changed(self, player, status, _=None):
        logger.debug(f"Playback status changed for player {player.props.player_name}: {status}")
        self.on_metadata_changed(player, player.props.metadata)

    def get_first_playing_player(self):
        players = self.get_players()
        logger.debug(f"Getting first playing player from {len(players)} players")
        if len(players) > 0:
            for player in players[::-1]:
                if player.props.status == "Playing":
                    return player
            return players[0]
        else:
            logger.debug("No players found")
            return None

    def show_most_important_player(self):
        logger.debug("Showing most important player")
        current_player = self.get_first_playing_player()
        if current_player is not None:
            self.on_metadata_changed(current_player, current_player.props.metadata)
        else:
            self.clear_output()

    def on_metadata_changed(self, player, metadata, manager=None):
        artist = player.get_artist()
        title = player.get_title()
        album = player.get_album()

        artist_str = ", ".join(artist) if isinstance(artist, list) else (artist or "")
        title_str = title or ""
        album_str = album or ""

        # Raw fallback if title is empty
        raw_title = title_str if title_str else (artist_str or player.props.player_name)

        # Monospace Center / Truncate mathematically to fixed bar count
        if len(raw_title) > self.bar_count:
            formatted_title = raw_title[:self.bar_count - 1] + "…"
        else:
            formatted_title = raw_title.center(self.bar_count)

        # Escape XML entities after centering so character width remains exact
        track_info = html.escape(formatted_title)

        # Build detailed Pango tooltip
        tooltip_lines = []
        if title_str:
            tooltip_lines.append(f"<b>Title:</b> {html.escape(title_str)}")
        if artist_str:
            tooltip_lines.append(f"<b>Artist:</b> {html.escape(artist_str)}")
        if album_str:
            tooltip_lines.append(f"<b>Album:</b> {html.escape(album_str)}")

        tooltip = "\n".join(tooltip_lines) if tooltip_lines else player.props.player_name

        if player.props.status == "Playing" or not self.get_first_playing_player():
            self.write_output(track_info, player, tooltip)

    def on_player_appeared(self, _, player):
        logger.info(f"Player has appeared: {player.name}")
        if player.name in self.excluded_player:
            logger.debug(
                "New player appeared, but it's in exclude player list, skipping")
            return
        if player is not None and (self.selected_player is None or player.name == self.selected_player):
            self.init_player(player)
        else:
            logger.debug(
                "New player appeared, but it's not the selected player, skipping")

    def on_player_vanished(self, _, player):
        logger.info(f"Player {player.props.player_name} has vanished")
        self.show_most_important_player()


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", action="count", default=0)
    parser.add_argument("-x", "--exclude", help="Comma-separated list of excluded player")
    parser.add_argument("--player")
    parser.add_argument("--enable-logging", action="store_true")
    parser.add_argument("--length", type=int, default=11, help="Number of Cava bars / character width to center within")
    return parser.parse_args()


def main():
    arguments = parse_arguments()

    if arguments.enable_logging:
        logfile = os.path.join(os.path.dirname(
            os.path.realpath(__file__)), "media-player.log")
        logging.basicConfig(filename=logfile, level=logging.DEBUG,
                            format="%(asctime)s %(name)s %(levelname)s:%(lineno)d %(message)s")

    logger.setLevel(max((3 - arguments.verbose) * 10, 0))

    logger.info("Creating player manager")
    if arguments.player:
        logger.info(f"Filtering for player: {arguments.player}")
    if arguments.exclude:
        logger.info(f"Exclude player {arguments.exclude}")

    player = PlayerManager(arguments.player, arguments.exclude, bar_count=arguments.length)
    player.run()


if __name__ == "__main__":
    main()
