module OSDb
  class Movie
    
    attr_reader :path

    class << self
      def get_movie_list
        if dir = OSDb.options[:dir]
          movies = Dir.glob(File.join(dir, '**', '*.{avi,mpg,m4v,mkv,mov}')).map { |path| new(path) }
        else
          movies = ARGV.map{ |path| OSDb::Movie.new(path) }
        end
        movies.reject(&:has_sub?) unless OSDb.options[:force]
      end

      def fetch(server)
        movies = get_movie_list
        
        if movies.empty?
          OSDb.log "No file(s) provided"
          OSDb.log OSDb.help
          exit 1
        end
        
        movies.each do |movie|
          begin
            OSDb.log "* search subs for: #{movie.path}"
            subs = server.search_subtitles(:moviehash => movie.hash, :moviebytesize => movie.size, :sublanguageid => OSDb.options[:languages].join(','))
            if subs.any?
              sub = select_sub(subs)
              sub_path = movie.sub_path(sub.format)
              OSDb::Sub.download!(sub.url, sub_path)
            else
              OSDb.log "* no sub found"
            end
            OSDb.log
          end
        end
      end

      private
        def select_sub(subs)
          return subs.first if subs.length == 1
          movies = group_by_movie_name(subs)
          return movies.values.first.max if movies.length == 1
          selected_movie_subs = ask_user_to_identify_movie(movies)
          selected_movie_subs.max
        end
    end
    
    def initialize(path)
      @path = path
    end

    def has_sub?
      exist = false
      %w(.srt .sub).each{ |ext| exist ||= File.exist?(path.gsub(File.extname(path), ext)) }
      exist
    end

    def sub_path(format)
      path.gsub(File.extname(path), ".#{format}")
    end
    
    def hash
      @hash ||= self.class.compute_hash(path)
    end
    
    def size
      @size ||= File.size(path)
    end
    
    CHUNK_SIZE = 64 * 1024 # in bytes
    
    # from http://trac.opensubtitles.org/projects/opensubtitles/wiki/HashSourceCodes
    def self.compute_hash(path)
      filesize = File.size(path)
      hash = filesize
      
      # Read 64 kbytes, divide up into 64 bits and add each
      # to hash. Do for beginning and end of file.
      File.open(path, 'rb') do |f|    
        # Q = unsigned long long = 64 bit
        f.read(CHUNK_SIZE).unpack("Q*").each do |n|
          hash = hash + n & 0xffffffffffffffff # to remain as 64 bit number
        end
        
        f.seek([0, filesize - CHUNK_SIZE].max, IO::SEEK_SET)
        
        # And again for the end of the file
        f.read(CHUNK_SIZE).unpack("Q*").each do |n|
          hash = hash + n & 0xffffffffffffffff
        end
      end
      
      sprintf("%016x", hash)
    end
    
  end
end