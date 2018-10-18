#!/usr/bin/env ruby

require 'yaml'

require './lib/github_fetcher.rb'
require './lib/message_builder.rb'
require './lib/par8o_message_builder.rb'
require './lib/slack_poster.rb'

# Entry point for the Seal!
class Seal

  attr_reader :mode

  def initialize(team, mode=nil)
    @team = team
    @mode = mode
  end

  def bark
    teams.each { |team| bark_at(team) }
  end

  private

  attr_accessor :mood

  def teams
    if @team.nil? && org_config
      org_config.keys
    else
      [@team]
    end
  end

  def message_builder_class
    case ENV["SEAL_MESSAGE_BUILDER"]
    when "par8o"
      Par8oMessageBuilder
    else
      MessageBuilder
    end
  end

  def bark_at(team)
    message_builder = message_builder_class.new(team_params(team), @mode)
    message = message_builder.build
    channel = ENV["SLACK_CHANNEL"] ? ENV["SLACK_CHANNEL"] : team_config(team)['channel']
    slack = SlackPoster.new(ENV['SLACK_WEBHOOK'], channel, message_builder.poster_mood)
    slack.send_request(message)
  end

  def org_config
    @org_config ||= YAML.load_file(configuration_filename) if File.exist?(configuration_filename)
  end

  def configuration_filename
    @configuration_filename ||= "./config/#{ENV['SEAL_ORGANISATION']}.yml"
  end

  def team_params(team)
    config = team_config(team)
    if config
      members = config['members']
      use_labels = config['use_labels']
      exclude_labels = config['exclude_labels']
      include_labels = config['include_labels']
      exclude_titles = config['exclude_titles']
      exclude_repos = config['exclude_repos']
      include_repos = config['include_repos']
      fetch_approval_status = value_or_default(config['fetch_approval_status'], true)
      fetch_comment_counts = value_or_default(config['fetch_comment_counts'], true)
      fetch_thumbs_up = value_or_default(config['fetch_thumbs_up'], true)
      @quotes = config['quotes']
    else
      members = split_by_comma(ENV['GITHUB_MEMBERS']) || []
      use_labels = ENV['GITHUB_USE_LABELS']
      exclude_labels = split_by_comma(ENV['GITHUB_EXCLUDE_LABELS'])
      include_labels = split_by_comma(ENV['GITHUB_INCLUDE_LABELS'])
      exclude_titles = split_by_comma(ENV['GITHUB_EXCLUDE_TITLES'])
      exclude_repos = split_by_comma(ENV['GITHUB_EXCLUDE_REPOS'])
      include_repos = split_by_comma(ENV['GITHUB_INCLUDE_REPOS'])
      fetch_approval_status = booleanize(ENV['GITHUB_FETCH_APPROVAL_STATUS'], true)
      fetch_comment_counts = booleanize(ENV['GITHUB_FETCH_COMMENT_COUNTS'], true)
      fetch_thumbs_up = booleanize(ENV['GITHUB_FETCH_THUMBS_UP'], true)
      @quotes = split_by_comma(ENV['SEAL_QUOTES'])
    end

    if @mode == nil
      options = {
        team_members_accounts: members,
        use_labels: use_labels,
        exclude_labels: exclude_labels,
        include_labels: include_labels,
        exclude_titles: exclude_titles,
        exclude_repos: exclude_repos,
        include_repos: include_repos,
        fetch_approval_status: fetch_approval_status,
        fetch_comment_counts: fetch_comment_counts,
        fetch_thumbs_up: fetch_thumbs_up
      }

      fetch_from_github(options)
    else
      @quotes
    end
  end

  def fetch_from_github(options)
    git = GithubFetcher.new(options)
    git.list_pull_requests
  end

  def team_config(team)
    org_config[team] if org_config
  end

  def split_by_comma(string)
    string.split(',') if string
  end

  def booleanize(string, default)
    return default unless string

    case string.downcase
    when "true"
      true
    when "false"
      false
    else
      default
    end
  end

  def value_or_default(value, default)
    value ? value : default
  end
end
