require 'optparse'

class LogEntry
  attr_reader :content, :template
  
  def initialize(content)
    @content = content
    @template = normalize(content)
  end

  private
  
  def normalize(text)
    text.gsub(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/, '<IP>')
        .gsub(/0x[a-fA-F0-9]+/, '<HEX>')
        .gsub(/\d+/, '<NUM>')
        .downcase.strip
  end
end

class Cluster
  attr_reader :representative, :entries

  def initialize(first_entry)
    @representative = first_entry
    @entries = [first_entry]
  end

  def add(entry)
    @entries << entry
  end

  def size
    @entries.size
  end
end

class Deduplicator
  def initialize(threshold: 0.8)
    @threshold = threshold
    @clusters = []
  end
  
  def process(file_path)
    File.foreach(file_path) do |line|
      entry = LogEntry.new(line)
      match_found = false

    @clusters.each do |cluster|
      if similarity(entry.template, cluster.representative.template) >= @threshold
        cluster.add(entry)
        match_found = true
        break
      end
    end
    
    @clusters << Cluster.new(entry) unless match_found
    end
    @clusters
  end

  private

  def similarity(str1, str2)
    words1 = str1.split
    words2 = str2.split
    
    intersection = (words1 & words2).size
    union = (words1 | words2).size
    
    return 0.0 if union == 0 
    intersection.to_f / union
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

results.sort_by(&:size).reverse.each do |cluster|
  puts "[#{cluster.size} occurrences] #{cluster.representative.content.strip}"
end

