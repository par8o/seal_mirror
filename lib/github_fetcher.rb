require 'octokit'

class GithubFetcher
  ORGANISATION ||= ENV['SEAL_ORGANISATION']
  # TODO: remove media type when review support comes out of preview
  Octokit.default_media_type = 'application/vnd.github.black-cat-preview+json'

  attr_accessor :people

  def initialize(options)
    @github = Octokit::Client.new(:access_token => ENV['GITHUB_TOKEN'])
    @github.api_endpoint = ENV['GITHUB_API_ENDPOINT'] if ENV['GITHUB_API_ENDPOINT']
    @github.user.login
    @github.auto_paginate = true
    @options = options
    @people = options[:team_members_accounts]
    @exclude_labels = normalize_labels(options[:exclude_labels])
    @include_labels = normalize_labels(options[:include_labels])
    @exclude_titles = normalize_labels(options[:exclude_titles])
    @labels = {}
    @exclude_repos = options[:exclude_repos]
    @include_repos = options[:include_repos]
  end

  def list_pull_requests
    pull_requests_from_github.each_with_object({}) do |pull_request, pull_requests|
      repo_name = pull_request.html_url.split("/")[4]
      next if hidden?(pull_request, repo_name)
      pull_requests[pull_request.title] = present_pull_request(pull_request, repo_name)
    end
  end

  private

  attr_reader :options, :use_labels, :exclude_labels, :include_labels, :exclude_titles, :exclude_repos, :include_repos

  def present_pull_request(pull_request, repo_name)
    pr = {}
    pr['title'] = pull_request.title
    pr['link'] = pull_request.html_url
    pr['author'] = pull_request.user.login
    pr['repo'] = repo_name
    pr['comments_count'] = count_comments(pull_request, repo_name) if fetch_comment_counts?
    pr['thumbs_up'] = count_thumbs_up(pull_request, repo_name) if fetch_thumbs_up?
    pr['approved'] = approved?(pull_request, repo_name) if fetch_approval_status?
    pr['updated'] = Date.parse(pull_request.updated_at.to_s)
    pr['labels'] = labels(pull_request, repo_name)
    pr
  end

  # https://developer.github.com/v3/search/#search-issues
  # returns up to 100 results per page.
  def pull_requests_from_github
    @github.search_issues("is:pr state:open user:#{ORGANISATION}").items
  end

  def person_subscribed?(pull_request)
    people.empty? || people.include?("#{pull_request.user.login}")
  end

  def count_comments(pull_request, repo)
    pr = @github.pull_request("#{ORGANISATION}/#{repo}", pull_request.number)
    (pr.review_comments + pr.comments).to_s
  end

  def count_thumbs_up(pull_request, repo)
    response = @github.issue_comments("#{ORGANISATION}/#{repo}", pull_request.number)
    comments_string = response.map {|comment| comment.body}.join
    thumbs_up = comments_string.scan(/:\+1:/).count.to_s
  end

  def approved?(pull_request, repo)
    reviews = @github.get("repos/#{ORGANISATION}/#{repo}/pulls/#{pull_request.number}/reviews")
    reviews.any? { |review| review.state == 'APPROVED' }
  end

  def labels(pull_request, repo)
    return [] unless options[:use_labels]
    key = "#{ORGANISATION}/#{repo}/#{pull_request.number}".to_sym
    @labels[key] ||= @github.labels_for_issue("#{ORGANISATION}/#{repo}", pull_request.number)
  end

  def hidden?(pull_request, repo)
    excluded_repo?(repo) ||
      excluded_label?(pull_request, repo) ||
      excluded_title?(pull_request.title) ||
      !person_subscribed?(pull_request) ||
      (include_labels && !explicitly_included_label?(pull_request, repo)) ||
      (include_repos && !explicitly_included_repo?(repo))
  end

  def excluded_label?(pull_request, repo)
    return false unless exclude_labels
    lowercase_label_names = labels(pull_request, repo).map { |l| l['name'].downcase }
    exclude_labels.any? { |e| lowercase_label_names.include?(e) }
  end

  def explicitly_included_label?(pull_request, repo)
    return false unless include_labels
    lowercase_label_names = labels(pull_request, repo).map { |l| l['name'].downcase }
    include_labels.any? { |e| lowercase_label_names.include?(e) }
  end

  def excluded_title?(title)
    exclude_titles && exclude_titles.any? { |t| title.downcase.include?(t) }
  end

  def excluded_repo?(repo)
    return false unless exclude_repos
    exclude_repos.include?(repo)
  end

  def explicitly_included_repo?(repo)
    return false unless include_repos
    include_repos.include?(repo)
  end

  def normalize_labels(labels)
    labels.map(&:downcase).uniq if labels
  end

  def fetch_comment_counts?
    options[:fetch_comment_counts]
  end

  def fetch_approval_status?
    options[:fetch_approval_status]
  end

  def fetch_thumbs_up?
    options[:fetch_thumbs_up]
  end
end
