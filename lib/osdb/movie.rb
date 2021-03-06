module OSDb
  class Movie
    
    attr_reader :path

    class << self
      def get_movie_list

        if dir = OSDb.options[:dir]
          path   = Dir.glob(File.join(dir, '**', "*.{#{OSDb.options[:movie_exts]}}"))
          movies = path.map { |path| new(path) }
        else
          movies = ARGV.map{ |path| OSDb::Movie.new(path) }
        end
        movies.reject!(&:has_sub?) unless OSDb.options[:force]
        
        if movies.empty?
          OSDb.log "All movies in #{dir} already have subtitles."
          exit 1
        end
        
        movies
      end
    end
    
    def initialize(path)
      @path = path
    end

    def has_sub?
      exist = false
      %w(.srt .sub .smi).each{ |ext| exist ||= File.exist?(path.gsub(File.extname(path), ext)) }
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
      begin
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
      rescue Errno::EPERM
        OSDb.log("* could not read #{path}")
      rescue RuntimeError
        OSDb.log("* could not read #{path}")
      end
    end
    
  end
end