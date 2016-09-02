require 'mechanize'
require 'dotenv'
Dotenv.load

class Downloader
  DOMAIN = 'www.rubytapas.com'.freeze
  LOGIN_PAGE_URL = "https://#{DOMAIN}/login/".freze
  EPISODE_LIST_URL = "https://#{DOMAIN}/episode-list/".freeze

  def initialize(agent)
    @agent    = agent
    @episodes = nil
  end

  def login(username, password)
    form = @agent.get(LOGIN_PAGE_URL).form('mepr_loginform')
    form.log = username
    form.pwd = password
    form.checkbox_with(name: 'rememberme').check
    @agent.submit(form, form.buttons.first)
    self
  end

  def download_episode(episode_number)
    raise('wrong download directory') if wrong_download_directory?
    episode_number ||= episodes.last[/episode-([[:digit:]]+)-/, 1]
    episode_url = episodes.select { |e| e =~ /episode-#{episode_number}-/ }
                          .first
    download_link = @agent.get(episode_url).search('a.mepr-aws-link').first
    raise("episode #{episode_number} not found") if download_link.nil?
    download_url = download_link.attribute('href').value
    filename = URI.parse(download_url).path[%r{^\/(.*)$}, 1]
    raise("file #{filename} already exists") if existing_file?(filename)
    @agent.download(download_url, "#{ENV['DOWNLOAD_DIRECTORY']}/#{filename}")
  end

  private

  def episodes
    @episodes ||= @agent.get(EPISODE_LIST_URL)
                        .search('li.su-post a')
                        .collect { |link| link.attribute('href').value }
  end

  def wrong_download_directory?
    !File.exist?("#{ENV['DOWNLOAD_DIRECTORY']}/.RUBYTAPAS_DOWNLOAD_DIRECTORY")
  end

  def existing_file?(filename)
    File.exist?("#{ENV['DOWNLOAD_DIRECTORY']}/#{filename}")
  end
end

agent = Mechanize.new
Downloader.new(agent)
          .login(ENV['RUBYTAPAS_USERNAME'], ENV['RUBYTAPAS_PASSWORD'])
          .download_episode ARGV.first
