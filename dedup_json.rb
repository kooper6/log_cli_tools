require 'optparse'
require 'json'
require 'set'

module LogMasker
  PATTERNS = {
    timestamp: /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z?/,
    guid:      /[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}/,
    ip:        /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/,
    hex:       /0x[a-fA-F0-9]+|[a-fA-F0-9]{8,}/,
    number:    /\d+/
  }.freeze

  def mask(text)
    return "" if text.nil?
    res = text.dup
    PATTERNS.each {|label, reg| res.gsub!(reg, "<#{label.upcase}>") }
    res.downcase.strip
  end
end


class LogEntry
  include LogMasker
  attr_reader :message, :template, :words_set
  
  def initialize(line)
    data = JSON.parse(line) rescue {'message' => line}
    @message = data['message'] || line
    @template = mask(@message)
    
    @words_set = @template.split.to_set
  end
end

class Cluster
  attr_reader :representative, :count

  def initialize(entry)
    @representative = entry
    @count = 1
  end

  def add!
    @count += 1
  end

  def similarity_with(other_entry)
    intersection = (@representative.words_set & other_entry.words_set).size
    union = (@representative.words_set | other_entry.words_set).size
    return 0.0 if union.zero?
    intersection.to_f / union
  end
end

class Deduplicator
  def initialize(threshold: 0.8)
    @threshold = threshold
    @clusters = []
  end
  
  def process(file_path)
    File.foreach(file_path) do |line|
      next if line.strip.empty?
      entry = LogEntry.new(line)

      match = @clusters.find {|c| c.similarity_with(entry) >= @threshold}
      
      if match
        match.add!
      else
        @clusters << Cluster.new(entry)
      end
    end
    @clusters
  end
end


# --- CLI interface ---

options = { threshold: 0.7 }
OptionParser.new do |opts|
  opts.banner = "Usage: ruby dedup.rb [file] [options]"
  opts.on("-t", "--threshold FLOAT", Float, "Similarity threshold (default 0.7)") do |t|
    options[:threshold] = t 
  end
end.parse!

file_path = ARGV[0]

if file_path.nil? || !File.exist?(file_path)
  puts "No valid file"
  exit 
end

engine = Deduplicator.new(threshold: options[:threshold])
results = engine.process(file_path)

puts "\n deduplication result "

results.sort_by(&:count).reverse.each do |cluster|
 puts "%-8d | %s" % [
    cluster.count, 
    cluster.representative.template
  ] 
  #puts "[#{cluster.size} occurrences] #{cluster.representative.content.strip}"
end

