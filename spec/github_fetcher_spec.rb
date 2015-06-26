require 'spec_helper'
require './lib/github_fetcher'
require 'rubygems'

  describe 'github_fetcher' do

    let(:team_members_accounts) {["binaryberry", "jamiecobbett", "boffbowsh", "alicebartlett", "benilovj", "fofr", "russellthorn", "edds"]}
    let(:team_repos) {["whitehall"]}
    let(:github_fetcher) { GithubFetcher.new(team_members_accounts, team_repos) }

    context "list_pull_requests" do
      it "should display open pull requests open on the team's repos by a team member" do
        expect(github_fetcher.list_pull_requests).to eq({"Tidy up document-page stylesheet"=>{"title"=>"Tidy up document-page stylesheet", "link"=>"https://github.com/alphagov/whitehall/pull/2244", "author"=>"edds", "repo"=>"whitehall"}, "Switch to using govuk_admin_template and Bootstrap 3"=>{"title"=>"Switch to using govuk_admin_template and Bootstrap 3", "link"=>"https://github.com/alphagov/whitehall/pull/2241", "author"=>"fofr", "repo"=>"whitehall"}, "Use gds-ruby-styleguide to provide Rubocop"=>{"title"=>"Use gds-ruby-styleguide to provide Rubocop", "link"=>"https://github.com/alphagov/whitehall/pull/2228", "author"=>"boffbowsh", "repo"=>"whitehall"}})
      end
    end

  end

