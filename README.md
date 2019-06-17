# aadu-the-bot
Aadu The Bot is rewrite of 4nd3r/tiny-matrix-bot in Ruby. It's based on old IRC bot that runs analyzes input with regex and when match, runs the script.

It extends SimpleBot to run shell scripts. SimpleBot is simply bot, that listens to configured channels and just writes them to standard output.

# Aadu The Bot Installation
- cp config.yml.example config.yml
- # edit config.yml
- bundle install # Install dependencies
- bundle exec bin/aadu.rb
