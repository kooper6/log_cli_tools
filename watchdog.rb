require 'matrix'

class Watchdog
  def initialize(threshold: 10.0)
    @threshold = threshold
    @history_vectors = []
  end

  def summarize(text)
    features = Hash.new(0)
    
    clean_text = text.gsub(/\d+/, '0')

    clean_text.chars.each_cons(3) {|tri| features[tri.join] += 1}
    features
  end

  def to_vector(features, keys)
    Vector[*keys.map {|k| features[k] || 0}]
  end

  def analyze(logs)
    all_features = logs.map {|l| summarize(l)}
    all_keys = all_features.flat_map(&:keys).uniq

    vectors = all_features.map {|f| to_vector(f, all_keys)}
    
    centroid = vectors.inject(:+) / vectors.size.to_f

    logs.each_with_index do |log, i|
      dist = (vectors[i] - centroid).magnitude
      
      if dist > @threshold
        puts "anomaly log #{dist.round(2)}"
        puts "Log: #{log}"
        puts "-" * 20
      end 
    end 
  end 
end 

file_path = ARGV[0]

if file_path.nil? || !File.exist?(file_path)
  puts "No valid file"
  exit 
end

logs = File.readlines(file_path)

watchdog = Watchdog.new
watchdog.analyze(logs)

