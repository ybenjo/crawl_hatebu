require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'net/http'
require 'date'
require 'json/pure'
require 'logger'
require 'mongo'

UA = 'crawler. mail_address ybenjo.repose at gmail'
class Cralwer
  def initialize
    @hotentry_url = 'http://b.hatena.ne.jp/hotentry/'
    @api_url = 'http://b.hatena.ne.jp/entry/jsonlite/'
    @log = Logger.new("../logs/#{Time.new.strftime('%Y%m%d_%H%M')}.log")
    @wait = 5
  end

  def get_entry(url)
    info = { }
    info[:url] = url
    info[:ids] = [ ]
    target_url = @api_url + URI.escape(url)
    @log.info("Get #{url}.")

    host = URI(url).host
    info[:host] = host
    info[:time] = Time.now
    
    begin
      ret = JSON.parse(Net::HTTP.get(URI.parse(target_url), {'User-Agent' => UA}))
      info[:title] = ret['title']
      info[:count] = ret['count'].to_i
      info[:comments] = { }
      
      ret['bookmarks'].each do |elem|
        id = elem['user'].to_sym
        info[:comments][id] = { }
        info[:comments][id][:tags] = elem['tags']
        info[:comments][id][:comment] = elem['comment']
        info[:comments][id][:timestamp] = Time.parse(elem['timestamp'])
        info[:ids].push id
      end
    rescue => e
      @log.error('Failed in #{url}.')
      @log.error('#{e.message}')
    end
    sleep @wait
    info
  end
  
  def get_hotentry_list(date)
    urls = [ ]
    @log.info("Get #{date}'s hotentries.")
    begin
      doc = Nokogiri::HTML(open(@hotentry_url + date).read, 'User-Agent' => UA)
      (doc/'h3.hb-entry-link-container'/'a').each do |elem|
        url = elem.attribute('href').value
        urls.push url
      end

    rescue => e
      @log.error("Failed in #{date}.")
      @log.error(e.message)
    end
    sleep @wait
    urls
  end

  def crawl(from, to)
    from_date = Date.parse(from)
    to_date = Date.parse(to)
    0.upto((to_date - from_date).to_i) do |i|
      date = (from_date + i).strftime("%Y%m%d")
      urls = get_hotentry_list(date)
      urls.each do |url|
        info = get_entry(url)
        save(info)
      end
    end
  end

  def save(info)
    m = Mongo::MongoClient.new.db('hatebu')['hatebu']
    m.insert(info)
  end
end

if __FILE__ == $0
  c = Cralwer.new
  c.crawl(ARGV[0], ARGV[1])
  # p c.get_hotentry_list('20130101')
  # p c.get_entry('http://d.hatena.ne.jp/takeda25/20130914/1379166107')
end
