#==============================================================================
# Alpha Encounters Bootstrap
#==============================================================================

module AlphaEncounters
  ROOT = File.expand_path(File.dirname(__FILE__)) unless const_defined?(:ROOT, false)
  VERSION_FALLBACK = "0.0.0" unless const_defined?(:VERSION_FALLBACK, false)



  module Bootstrap
    class << self
      def boot
        return true if @booted
        load File.join(AlphaEncounters::ROOT, "LoadOrder.rb")
        AlphaEncounters::LoadOrder.files.each { |relative| load_file(relative) }
        @booted = true
        AlphaEncounters::Log.info("Alpha Encounters #{AlphaEncounters.version} loaded", :bootstrap) if defined?(AlphaEncounters::Log)
        true
      rescue StandardError => e
        if defined?(AlphaEncounters::Log)
          AlphaEncounters::Log.exception("Alpha Encounters bootstrap failed", e, channel: :bootstrap)
        else
          echoln("[AlphaEncounters] Bootstrap failed: #{e.class}: #{e.message}") rescue nil
        end
        raise
      end

      private

      def load_file(relative)
        path = File.expand_path(File.join(AlphaEncounters::ROOT, relative))
        raise "Load path escapes Alpha Encounters: #{relative}" unless path.start_with?(AlphaEncounters::ROOT)
        raise "Missing Alpha Encounters file: #{relative}" unless File.file?(path)
        load path
      end
    end
  end
end

AlphaEncounters::Bootstrap.boot
