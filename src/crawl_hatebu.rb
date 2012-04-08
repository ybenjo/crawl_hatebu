require "nokogiri"
require "open-uri"
require "cgi"
require "net/http"
require "date"
require "json"
require "logger"

class Cralwer
  def initialize
    @hotentry_url = "http://b.hatena.ne.jp/hotentry/"
    @api_url = "http://b.hatena.ne.jp/entry/jsonlite/"
    @info = { }
    @uniq_ids = [ ]
    @log = Logger.new("../logs/#{Time.new.strftime("%Y%m%d_%H%M")}.log")
    @wait = 5
  end

  def get_entry(url)
    @info[url] = { }
    target_url = @api_url + URI.escape(url)
    @log.info("Get #{url}.")
    
    begin
      ret = JSON.parse(Net::HTTP.get(URI.parse(target_url)))
      @info[url][:title] = ret["title"]
      @info[url][:count] = ret["count"].to_i
      
      ret["bookmarks"].each do |elem|
        id = elem["user"].to_sym
        @info[url][id] = { }
        @info[url][id][:tags] = elem["tags"]
        @info[url][id][:comment] = elem["comment"]
        @info[url][id][:timestamp] = elem["timestamp"]
        @uniq_ids.push id
      end
    rescue => e
      @log.error("Failed in #{url}.")
      @log.error("#{e.message}")
    end
    sleep @wait
  end
  
  def get_hot_entry(date)
    urls = [ ]
    @log.info("Get #{date}'s hotentries.")
    begin
      hotentries = Nokogiri::HTML(open(@hotentry_url + date).read)
      (hotentries/"ul.hotentry"/"blockquote").each do |elem|
        url = elem.attribute("cite").value
        urls.push url
      end
    rescue => e
      @log.error("Failed in #{date}.")
      @log.error("#{e.message}")
    end
    sleep @wait
    urls
  end

  def crawl(from, to)
    from_date = Date.parse(from)
    to_date = Date.parse(to)
    0.upto((to_date - from_date).to_i) do |i|
      date = (from_date + i).strftime("%Y%m%d")
      urls = get_hot_entry(date)
      urls.each do |url|
        get_entry(url)
      end
    end
  end
  
  def write
    open("../data/info.dump", "wb"){|f|
      Marshal.dump(@info, f)
    }

    open("../data/ids.txt", "w"){|f|
      @uniq_ids.each do |id|
        f.puts id
      end
    }
  end
end

if __FILE__ == $0
  c = Cralwer.new
  c.crawl(ARGV[0], ARGV[1])
  c.write
end
